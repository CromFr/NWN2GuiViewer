import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.string;
import core.thread;
import std.datetime : StopWatch, SysTime;

import gtk.Main;
import gdk.Threads;

import nwnxml;
import resource;
import node;
import logger;
import window;

string openedFile;
SysTime openedFileDate;

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
	Resource.CachePath();

	foreach(p ; Resource.path){
		if(!p.exists)warning("Path \"",p,"\" does not exist");
	}

	openedFile = file;
	openedFileDate = SysTime(0);

	if(checkOnly){
		new NwnXml(DirEntry(openedFile));
		return 0;
	}

	auto window = new Window();


	extern(C) int wrap(string fun)(void* ret){
		mixin(fun~"();");
		return cast(ubyte)ret!=0;
	}

	threadsAddTimeout(0, &(wrap!"ReloadFile"), cast(void*)0);
	threadsAddTimeout(200, &(wrap!"ReloadFileIfNeeded"), cast(void*)1);
	Main.run();
	return 0;
}

void ReloadFileIfNeeded(){
	if(openedFile.timeLastModified > openedFileDate){
		//File changed
		ReloadFile();
	}
}

void ReloadFile(){
	openedFileDate = openedFile.timeLastModified;

	Window.ClearLog();

	Window.SetScene(BuildFromXmlFile(openedFile));
}

UIScene BuildFromXmlFile(in string file){
	if(!exists(file)){
		critical("File "~file~" does not exist");
		return null;
	}
	if(!isFile(file)){
		critical("File "~file~" is not a file");
		return null;
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
		return null;
	}
	sw.stop();
	info("Parsed xml in ",sw.peek().to!("msecs",float)," ms");
	

	//=================================================== Create object tree
	sw.reset();
	sw.start();
	UIScene scene;
	try scene = BuildWidgets(xml.root, null);
	catch(Exception e){
		critical("GUI load error @",e.toString);
		return null;
	}
	sw.stop();
	info("Loaded scene in ",sw.peek().to!("msecs",float)," ms");

	return scene;
}

UIScene BuildWidgets(NwnXmlNode* xmlNode, Node parent){
	
	if(xmlNode.tag == "ROOT"){
		UIScene scene;

		foreach(node ; xmlNode.children){
			if(node.tag == "UIScene"){
				try{
					scene = new UIScene(node);
				}
				catch(Exception e){
					NWNLogger.xmlException(xmlNode, e.msg);
					throw e;
				}
			}
		}
		if(scene is null){
			throw new BuildException(null, "UIScene not found in the root of the document");
		}

		foreach_reverse(e ; xmlNode.children){
			if(e.tag != "UIScene")
				BuildWidgets(e, scene);
		}
		return scene;
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
					NWNLogger.xmlWarning(xmlNode, xmlNode.tag~" is not handled by the program. Treated as a UIPane");
					parent = new UIPane(parent, xmlNode);
					break;

			}

			foreach_reverse(e ; xmlNode.children){
				BuildWidgets(e, parent);
			}
		}
		catch(Exception e){
			NWNLogger.xmlException(xmlNode, e.msg);
			throw e;
		}
	}
	return null;
}