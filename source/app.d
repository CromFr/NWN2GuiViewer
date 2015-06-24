import std.stdio;
import std.getopt;
import std.file;
import std.string;
import core.thread;
import std.datetime : StopWatch;

import gtk.Main;
import gtkc.gdktypes;

import nwnxml;
import resource;
import node;

int main(string[] args)
{
	Main.init(args);//init GTK

    //Handle command-line args
    string file;
	getopt(args,
		    "f|file",  &file);


	//Use last arg as file path
	if(file=="" && args.length==2)
		file = args[$-1];

	Resource.path ~= DirEntry("/home/crom/GitProjects/NWNGuiViewer/res");


	if(!exists(file))throw new Exception("File "~file~" does not exist");
	if(!isFile(file))throw new Exception("File "~file~" is not a file");

	StopWatch sw;
	NwnXml xml;
	sw.start();
	try{
		xml = new NwnXml(cast(string)std.file.read(file));
	}
	catch(NwnXml.ParseException e){
		writeln("Ill-formed XML:\n",e.toString);
		return 1;
	}
	sw.stop();
	writeln("Checked xml in ",sw.peek().to!("msecs",float)," ms");
	

	//=================================================== Create object tree
	sw.reset();
	sw.start();
	Parse(xml.root, null);
	sw.stop();
	writeln("Loaded scene in ",sw.peek().to!("msecs",float)," ms");


	//=================================================== Create window
	UIScene.Get.window.showAll();
	Main.run();
	return 0;
}

void Parse(NwnXml.Node* elmt, Node parent, string sDecal=""){
	writeln(sDecal~elmt.tag);//, (("name" in elmt.tag.attr)? ":"~elmt.tag.attr["name"] : ""));

	if(parent is null)
		parent = UIScene.Get;

	switch(elmt.tag){
		case "ROOT":
			break;
		case "UIScene": 
			parent = new UIScene(elmt.attr); 
			break;
		case "UIPane": 
			parent = new UIPane(parent, elmt.attr);
			break;
		case "UIFrame": 
			parent = new UIFrame(parent, elmt.attr);
			break;

		default: 
			parent = new UIPane(parent, elmt.attr);
			break;

	}

	foreach(e ; elmt.children){
		Parse(e, parent,sDecal~"  ");
	}

}