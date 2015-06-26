module nwnxml;

//import std.stdio;
import std.uni;
import std.file;

class NwnXml {
	this(in DirEntry file){
		this(cast(string)std.file.read(file));
	}
	this(in string data) {

		enum ReadType{
			NOTHING,
			TAGNAME,
			TAGSTART,
			TAGEND,
			ATTRLIST,
			ATTRNAME,
			ATTRVALUE,

			COMMENT,
			HEADER,
		}

		root = new NwnXmlNode(null, "ROOT", -1, -1);

		NwnXmlNode* currentParent = root;
		NwnXmlNode* currentNode = null;
		auto readType = ReadType.NOTHING;
		
		string bufTagName, bufAttrName, bufAttrValue, bufComment;
		dchar bufAttrDelimiter;
		bool bufIsClosingTag, bufIsSelfClosed;

		size_t charLine=1, charCol=1;

		foreach(dchar c ; data){

			if(c == '\n'){
				charLine++;
				charCol=1;
			}
			else
				charCol++;

			switch_char:
			//writeln("\t\t\t",c,": ",readType);

			final switch(readType){
				case ReadType.NOTHING:{

					if(c == '<'){
						readType = ReadType.TAGSTART;
					}

				}break;
				case ReadType.TAGSTART:{
					bufTagName = "";
					bufIsSelfClosed = false;

					if(c=='/'){
						bufIsClosingTag = true;
						readType = ReadType.TAGNAME;
					}
					else{
						bufIsClosingTag = false;
						readType = ReadType.TAGNAME;
						goto switch_char;
					}

				}break;
				case ReadType.TAGNAME:{

					if(isWhite(c) || c=='/' || c=='>'){
						if(bufIsClosingTag){
							if(currentParent.tag == bufTagName){
								currentNode = currentParent;
								readType = ReadType.TAGEND;
								goto switch_char;
							}
							else{
								throw new ParseException(charLine, charCol, "Unclosed tag: "~currentParent.tag);
							}
						}
						else{
							//writeln("New tag: ",bufTagName);
							currentNode = new NwnXmlNode(currentParent, bufTagName, charLine, charCol);

							bufTagName = "";

							readType = ReadType.ATTRLIST;
							goto switch_char;
						}
					}
					else{
						bufTagName ~= c;

						if(bufTagName == "!--"){
							bufComment = "";
							readType = ReadType.COMMENT;
						}
						if(bufTagName == "?xml"){
							readType = ReadType.HEADER;
						}
					}
				}break;
				case ReadType.TAGEND:{
					if(c=='/'){
						bufIsSelfClosed = true;
					}
					else if(c=='>'){
						readType = ReadType.NOTHING;
						
						if(bufIsSelfClosed || bufIsClosingTag){
							//writeln("end of tag ",currentNode.tag);
							currentParent = currentNode.parent;
							//Does not contain any children
						}
						else{
							//May contain children
							currentParent = currentNode;
						}
						currentNode = null;
					}
				}break;
				case ReadType.ATTRLIST:{
					if(c=='/' || c=='>'){
						readType = ReadType.TAGEND;
						goto switch_char;
					}
					else if(!isWhite(c)){//interesting char
						bufAttrName = "";
						bufAttrDelimiter = '\0';
						bufAttrValue = "";

						readType = ReadType.ATTRNAME;
						goto switch_char;
					}

				}break;
				case ReadType.ATTRNAME:{
					if(isWhite(c)){
						throw new ParseException(charLine, charCol, "Got a space in a attribute name before the =");
					}
					else if(c=='='){
						readType = ReadType.ATTRVALUE;
					}
					else{
						bufAttrName ~= c;
					}
				}break;
				case ReadType.ATTRVALUE:{
					if(bufAttrDelimiter == '\0'){
						if(c==' ' || c=='\t'){
							continue;
						}
						else{
							if(c=='\'' || c=='"'){
								bufAttrDelimiter = c;
							}
							else{
								bufAttrDelimiter = 's';//space
								goto switch_char;//this char must not be ignored
							}
						}
					}
					else{
						if((bufAttrDelimiter!='s' && c==bufAttrDelimiter) || (bufAttrDelimiter=='s' && (isWhite(c)||c=='>'||c=='/'))){
							currentNode.attr[bufAttrName] = bufAttrValue;
							//writeln("   ",bufAttrName,"=",bufAttrValue," (",bufAttrDelimiter,")");

							if(c=='>'||c=='/'){
								readType = ReadType.TAGEND;
								goto switch_char;
							}
							else{
								readType = ReadType.ATTRLIST;
							}
						}
						else{
							bufAttrValue ~= c;
						}
					}
				}break;


				case ReadType.COMMENT:{
					if(bufComment.length>=3)
						bufComment = bufComment[1..$];
					bufComment~=c;
					if(bufComment == "-->"){
						readType = ReadType.NOTHING;
					}
				}break;
				case ReadType.HEADER:{
					if(c == '>'){
						readType = ReadType.NOTHING;
					}
				}break;

			}
		}

		if(readType != ReadType.NOTHING){
			import std.conv: to;
			throw new ParseException(charLine, charCol, "Reached end of file while searching for "~readType.to!string);
		}
		if(currentParent != root){
			throw new ParseException(charLine, charCol, "Unclosed tag "~currentParent.tag);
		}




	}


	NwnXmlNode* FindFirstByName(NwnXmlNode* from, in string name){
		if("name" in from.attr && from.attr["name"]==name)
			return from;
		foreach(child ; from.children){
			auto ret = FindFirstByName(child, name);
			if(ret !is null)return ret;
		}
		return null;
	}

	NwnXmlNode* root;
	
}

struct NwnXmlNode{
	string tag;
	string[string] attr;

	NwnXmlNode* parent;
	NwnXmlNode*[] children;

	size_t line, column;

	this(NwnXmlNode* _parent, in string _tag, in size_t _line, in size_t _column){
		tag = _tag;
		parent = _parent;
		line = _line;
		column = _column;
		if(parent !is null)
			_parent.children ~= &this;
	}
}

class ParseException : Exception {
	@safe pure nothrow this(in size_t line, in size_t col, in string msg,
			string excFile =__FILE__,
			size_t excLine = __LINE__,
			Throwable excNext = null) {
		import std.conv : to;
		super(line.to!string ~ ":" ~ col.to!string ~ "| " ~msg, excFile, excLine, excNext);
	}
}


unittest{
	import std.exception;

	//Structure
	assertNotThrown!(ParseException)(new NwnXml("<a><!----></a><!----><b/>"));
	assertNotThrown!(ParseException)(new NwnXml("<a><!-- 123456789 --></a><!----------><b/><!-- <aa> </sqidg> --><c></c>"));
	assertNotThrown!(ParseException)(new NwnXml("<a><b\n></b></a>"));
	assertNotThrown!(ParseException)(new NwnXml("<a><b/><c></c></a>"));
	assertThrown!(ParseException)(new NwnXml("<bug"));
	assertThrown!(ParseException)(new NwnXml("<buuug>"));
	assertThrown!(ParseException)(new NwnXml("<a><bug></a>"));
	assertThrown!(ParseException)(new NwnXml("<a></ab>"));
	assertThrown!(ParseException)(new NwnXml("<a></b>"));

	//Attributes
	assertNotThrown!(ParseException)({
		auto xml = new NwnXml(q"[<a x="yolo" y='yolo2' z=abcde/>]");
		assert(xml.root.children[0].attr["x"] == "yolo");
		assert(xml.root.children[0].attr["y"] == "yolo2");
		assert(xml.root.children[0].attr["z"] == "abcde");
	}());
	assertNotThrown!(ParseException)({
		auto xml = new NwnXml(q"[<a x="yolo('a')" y='yolo2()' z=yolo("qwerty")/>]");
		assert(xml.root.children[0].attr["x"] == "yolo('a')");
		assert(xml.root.children[0].attr["y"] == "yolo2()");
		assert(xml.root.children[0].attr["z"] == "yolo(\"qwerty\")");
	}());
	assertNotThrown!(ParseException)({
		auto xml = new NwnXml(q"[<a x= yolo></a>]");
		assert(xml.root.children[0].attr["x"] == "yolo");
	}());
	assertThrown!(ParseException)(new NwnXml(q"[<a bug =123></a>]"));
	assertThrown!(ParseException)(new NwnXml(q"[<a bug=12 34></a>]"));

	//Structure
	assertNotThrown!(ParseException)({
		auto xml = new NwnXml("<a><b x=5></b><c y=6/></a><d></d>");
		assert(xml.root.children[0].tag == "a");
		assert(xml.root.children[0].children[0].tag == "b");
		assert(xml.root.children[0].children[0].attr["x"] == "5");
		assert(xml.root.children[0].children[1].tag == "c");
		assert(xml.root.children[0].children[1].attr["y"] == "6");
		assert(xml.root.children[1].tag == "d");
	}());
}