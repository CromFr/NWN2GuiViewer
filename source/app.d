import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.string;
import core.thread;
import std.datetime : StopWatch;

import gtk.Main;
import gtk.MainWindow;
import gtkc.gdktypes;
import gio.File;
import gio.FileMonitor;

import nwnxml;
import resource;
import node;

MainWindow window;
FileMonitor mon;

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


	window = new MainWindow("");
	window.setIconFromFile("res/icon.ico");

	auto res = BuildFromXmlFile(file);
	if(!res)return 1;

	Main.run();
	return 0;
}

bool BuildFromXmlFile(in string file){
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
		return false;
	}
	sw.stop();
	writeln("Checked xml in ",sw.peek().to!("msecs",float)," ms");
	

	//=================================================== Create object tree
	sw.reset();
	sw.start();
	BuildWidgets(xml.root, null);
	sw.stop();
	writeln("Loaded scene in ",sw.peek().to!("msecs",float)," ms");

	if(mon !is null)mon.destroy;

	mon = gio.File.File.parseName(absolutePath(file))
		.monitorFile(FileMonitorFlags.NONE, null);
	mon.addOnChanged((oldFile, newFile, e, mon){
		if(e == FileMonitorEvent.CHANGES_DONE_HINT)
		if(UIScene.Get !is null){
			window.removeAll();
			UIScene.Get.destroy;

			if(newFile !is null)
				BuildFromXmlFile(newFile.getPath);
			else
				BuildFromXmlFile(oldFile.getPath);
		}
	});

	window.showAll();
	return true;
}

void BuildWidgets(NwnXml.Node* elmt, Node parent, string sDecal=""){
	
	if(elmt.tag == "ROOT"){
		foreach(e ; elmt.children){
			if(e.tag == "UIScene")
				parent = new UIScene(window, e.attr);
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