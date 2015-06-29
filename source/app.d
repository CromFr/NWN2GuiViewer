import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.string;
import core.thread;
import std.datetime : StopWatch;

import gtk.Main;

import gio.File;
import gio.FileMonitor;

import nwnxml;
import resource;
import node;
import logger;
import window;


int main(string[] args)
{
	Main.init(args);//init GTK

    //Handle command-line args
    string file, respath;
    bool checkOnly;
	getopt(args,
		    "f|file",  &file,
		    "c|check", &checkOnly,
		    "p|respath",  &respath);

	new NWNLogger;

	//Use last arg as file path
	if(file=="")
		file = args[$-1];

	if(respath !is null){
		Resource.path ~= respath.split(pathSeparator);
	}
	Resource.path ~= "res";

	foreach(p ; Resource.path){
		if(!p.exists)warning("Path \"",p,"\" does not exist");
	}

	if(checkOnly){
		new NwnXml(DirEntry(file));
		return 0;
	}

	auto window = new Window();

	BuildFromXmlFile(file);

	Window.Display();
	Main.run();
	return 0;
}

void BuildFromXmlFile(in string file){
	if(!exists(file)){
		critical("File "~file~" does not exist");
		return;
	}
	if(!isFile(file)){
		critical("File "~file~" is not a file");
		return;
	}

	StopWatch sw;

	//=================================================== Parse XML
	NwnXml xml;
	sw.start();
	try{
		xml = new NwnXml(DirEntry(file));
	}
	catch(Exception e){
		critical("Parse XML error @",e.toString);
		return;
	}
	sw.stop();
	info("Parsed xml in ",sw.peek().to!("msecs",float)," ms");
	

	//=================================================== Create object tree
	sw.reset();
	sw.start();
	try{
		BuildWidgets(xml.root, null);
	}
	catch(Exception e){
		critical("GUI load error @",e.toString);
		return;
	}
	sw.stop();
	info("Loaded scene in ",sw.peek().to!("msecs",float)," ms");

	//=================================================== File monitoring
	static FileMonitor mon;
	if(mon !is null)mon.destroy;

	mon = gio.File.File.parseName(absolutePath(file))
		.monitorFile(FileMonitorFlags.NONE, null);
	mon.addOnChanged((oldFile, newFile, e, mon){
		if(e == FileMonitorEvent.CHANGES_DONE_HINT)
		if(UIScene.Get !is null){
			Window.RemoveScene();
			Window.ClearLog();

			if(newFile !is null)
				BuildFromXmlFile(newFile.getPath);
			else
				BuildFromXmlFile(oldFile.getPath);
		}
	});

	Window.Display();
}

void BuildWidgets(NwnXmlNode* xmlNode, Node parent, string sDecal=""){
	
	if(xmlNode.tag == "ROOT"){
		foreach(node ; xmlNode.children){
			if(node.tag == "UIScene"){
				try{
					parent = new UIScene(node);
				}
				catch(Exception e){
					NWNLogger.xmlException(xmlNode, e.msg);
					throw e;
				}
			}
		}
		if(parent is null){
			throw new BuildException(null, "UIScene not found in the root of the document");
		}

		foreach_reverse(e ; xmlNode.children){
			if(e.tag != "UIScene")
				BuildWidgets(e, parent,sDecal~"  ");
		}
	}
	else{
		try{
			switch(xmlNode.tag){
				case "UIPane": 
					parent = new UIPane(parent, xmlNode);
					break;
				case "UIFrame": 
					parent = new UIFrame(parent, xmlNode);
					break;
				case "UIIcon":
					parent = new UIIcon(parent, xmlNode);
					break;
				case "UIButton":
					parent = new UIButton(parent, xmlNode);
					break;
				case "UIText":
					parent = new UIText(parent, xmlNode);
					break;

				default:
					NWNLogger.xmlWarning(xmlNode, " is not handled by the program. Treated as a UIPane");
					parent = new UIPane(parent, xmlNode);
					break;

			}

			foreach_reverse(e ; xmlNode.children){
				BuildWidgets(e, parent,sDecal~"  ");
			}
		}
		catch(Exception e){
			NWNLogger.xmlException(xmlNode, e.msg);
			throw e;
		}
	}


}