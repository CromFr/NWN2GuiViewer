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
	BuildWidgets(xml.root, null);
	sw.stop();
	writeln("Loaded scene in ",sw.peek().to!("msecs",float)," ms");


	//=================================================== Create window
	UIScene.Get.window.showAll();
	Main.run();
	return 0;
}

void BuildWidgets(NwnXml.Node* elmt, Node parent, string sDecal=""){
	writeln(sDecal~elmt.tag);//, (("name" in elmt.tag.attr)? ":"~elmt.tag.attr["name"] : ""));

	if(elmt.tag == "ROOT"){
		foreach(e ; elmt.children){
			if(e.tag == "UIScene")
				parent = new UIScene(e.attr);
		}
		if(parent is null){
			throw new Exception("UIScene not found in the root of the document");
		}

		foreach_reverse(e ; elmt.children){
			if(e.tag != "UIScene")
				BuildWidgets(e, parent,sDecal~"  ");
		}
	}
	else{
		switch(elmt.tag){
			case "UIPane": 
				parent = new UIPane(parent, elmt.attr);
				break;
			case "UIFrame": 
				parent = new UIFrame(parent, elmt.attr);
				break;
			case "UIIcon":
				parent = new UIIcon(parent, elmt.attr);
				break;

			default: 
				parent = new UIPane(parent, elmt.attr);
				break;

		}

		foreach_reverse(e ; elmt.children){
			BuildWidgets(e, parent,sDecal~"  ");
		}
	}


}