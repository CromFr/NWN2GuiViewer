import std.stdio;
import std.getopt;
import std.file;
import std.xml;
import std.string;
import core.thread;
import std.datetime : StopWatch;

import gtk.Main : Main;
import gtk.MainWindow : MainWindow;
import gtk.Widget;
import gtkc.gdktypes;

import resource;
import node;

UIScene scene;
MainWindow win;

void main(string[] args)
{

    //Handle command-line args
    string file;
    bool bCheck=false;
	getopt(args,
		    "f|file",  &file,
		    "c|fullcheck", &bCheck);

	Main.init(args);//init GTK

	//Use last arg as file path
	if(file=="" && args.length==2)
		file = args[$-1];

	Resource.path ~= DirEntry("/run/media/Windows/Program Files (x86)/Neverwinter Nights 2/UI/default/images");


	if(!exists(file))throw new Exception("File "~file~" does not exist");
	if(!isFile(file))throw new Exception("File "~file~" is not a file");

	string[] xmllines = (cast(string)std.file.read(file)).splitLines(KeepTerminator.yes);
	string xmlcontent = (xmllines[0]~"<xml>"~xmllines[1..$]~"</xml>").join;

	StopWatch sw;
	if(bCheck){
		sw.start();
		try check(xmlcontent);
		catch(CheckException e){
			writeln("Ill-formed XML:\n",e.toString);
			return;
		}
		sw.stop();
		writeln("Checked xml in ",sw.peek().to!("msecs",float)," ms");
	}

	

	//=================================================== Create object tree
	sw.reset();
	sw.start();
	auto doc = new Document(xmlcontent);
	Parse(doc, null);

	sw.stop();
	writeln("Loaded scene in ",sw.peek().to!("msecs",float)," ms");


	//=================================================== Create window
	win = new MainWindow(scene.name);
	win.setIconFromFile("res/icon.ico");

	//Forbid resize
	win.setDefaultSize(scene.size.x, scene.size.y);
	auto geom = GdkGeometry(scene.size.x, scene.size.y, scene.size.x, scene.size.y);
	win.setGeometryHints(null, geom, GdkWindowHints.HINT_MIN_SIZE|GdkWindowHints.HINT_MAX_SIZE); 

	win.show();


	Main.run();
}

void Parse(in Element elmt, Node parent, string sDecal=""){
	writeln(sDecal~elmt.tag.name);//, (("name" in elmt.tag.attr)? ":"~elmt.tag.attr["name"] : ""));

	if(parent is null)
		parent = scene;

	string[string] attrList = to!(string[string])(elmt.tag.attr);
	switch(elmt.tag.name){
		case "UIScene": 
			scene = new UIScene(attrList); 
			break;
		case "UIPane": 
			parent = new UIPane(parent, attrList);
			break;
		case "UIFrame": 
			parent = new UIFrame(parent, attrList);
			break;

		default: 
			parent = new UIPane(parent, attrList);
			break;

	}

	foreach(e ; elmt.elements){
		Parse(e, null,sDecal~"  ");
	}

}