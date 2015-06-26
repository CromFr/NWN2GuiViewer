import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.string;
import core.thread;
import std.datetime : StopWatch;
import std.experimental.logger;

import gtk.Main;
import gtk.MainWindow;
import gtk.VBox;
import gtk.MenuBar;
import gtk.TextView;
import gtk.ScrolledWindow;
import gio.File;
import gio.FileMonitor;

import nwnxml;
import resource;
import node;

MainWindow window;
VBox vbox;
FileMonitor mon;
TextView console;

class NWNLogger : Logger
{
    this() @safe
    {
        super(LogLevel.all);
    }

    override void writeLogMsg(ref LogEntry log) @trusted
    {
        writeln("\x1b[2m",log.timestamp.toString[12..20],": \x1b[m",log.msg);

        if(window!is null && console!is null){
	        string msg = log.msg;
	    	switch(log.logLevel){
	    		with(LogLevel){
	    			case info:    msg=`Info: `~msg; break;
	    			case warning: msg=`WARNING: `~msg; break;
	    			case critical:msg=`=> ERROR: `~msg; break;
	    			default: assert(0);
	    		}
	    	}
			console.appendText("\n"~msg);
        }
    }
}

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

	sharedLog = new NWNLogger;//sharedLog is a global var defining the default logger

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
		new NwnXml(cast(string)std.file.read(file));
		return 0;
	}

	window = new MainWindow("");
	
	auto menubar = new MenuBar();
	auto menu = menubar.append("Move console");

	auto consoleWrap = new ScrolledWindow(PolicyType.NEVER, PolicyType.ALWAYS);
	consoleWrap.setMinContentHeight(100);
	console = new TextView;
	console.setEditable(false);
	console.setCursorVisible(false);
	console.setLeftMargin(5);
	console.setWrapMode(WrapMode.WORD);
	console.setWrapMode(WrapMode.WORD_CHAR);
	consoleWrap.add(console);

	vbox = new VBox(false, 0);
	vbox.packStart(menubar, false, true, 0);
	vbox.packEnd(consoleWrap, true, true, 5);
	window.add(vbox);

	string ico = Resource.FindFilePath("nwn2guiviewer.ico");
	if(ico !is null) window.setIconFromFile(ico);
	else warning("Icon file nwn2guiviewer.ico could not be found in path");

	BuildFromXmlFile(file);
	window.showAll();
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

	NwnXml xml;
	sw.start();
	try{
		xml = new NwnXml(cast(string)std.file.read(file));
	}
	catch(ParseException e){
		critical("Ill-formed XML: ",e.msg);
		return;
	}
	catch(Exception e){
		critical("Could not parse XML: ",e.msg);
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
		critical("Could not load GUI: ",e.msg);
		return;
	}
	sw.stop();
	info("Loaded scene in ",sw.peek().to!("msecs",float)," ms");

	if(mon !is null)mon.destroy;

	mon = gio.File.File.parseName(absolutePath(file))
		.monitorFile(FileMonitorFlags.NONE, null);
	mon.addOnChanged((oldFile, newFile, e, mon){
		if(e == FileMonitorEvent.CHANGES_DONE_HINT)
		if(UIScene.Get !is null){
			UIScene.Get.container.destroy;
			UIScene.Get.destroy;
			console.getBuffer.setText("");

			if(newFile !is null)
				BuildFromXmlFile(newFile.getPath);
			else
				BuildFromXmlFile(oldFile.getPath);
		}
	});

	window.showAll();
}
class BuildException : Exception {
	@safe pure nothrow this(NwnXmlNode* node, in string msg,
			string excFile =__FILE__,
			size_t excLine = __LINE__,
			Throwable excNext = null) {
		import std.conv : to;
		super(node.line.to!string~":"~node.column.to!string~"| <"~node.tag~">: "~msg, excFile, excLine, excNext);
	}
}
void BuildWidgets(NwnXmlNode* xmlNode, Node parent, string sDecal=""){
	
	if(xmlNode.tag == "ROOT"){
		foreach(node ; xmlNode.children){
			if(node.tag == "UIScene"){
				try{
					parent = new UIScene(window, vbox, node.attr);
				}
				catch(Exception e){
					throw new BuildException(node, e.msg);
				}
			}
		}
		if(parent is null){
			throw new Exception("UIScene not found in the root of the document");
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
					parent = new UIPane(parent, xmlNode.attr);
					break;
				case "UIFrame": 
					parent = new UIFrame(parent, xmlNode.attr);
					break;
				case "UIIcon":
					parent = new UIIcon(parent, xmlNode.attr);
					break;
				case "UIButton":
					parent = new UIButton(parent, xmlNode.attr);
					break;
				case "UIText":
					parent = new UIText(parent, xmlNode.attr);
					break;

				default:
					warning(xmlNode.tag, " is not handled by the program. Treated as a UIPane");
					parent = new UIPane(parent, xmlNode.attr);
					break;

			}
		}
		catch(Exception e){
			throw new BuildException(xmlNode, e.msg);
		}

		foreach_reverse(e ; xmlNode.children){
			BuildWidgets(e, parent,sDecal~"  ");
		}
	}


}