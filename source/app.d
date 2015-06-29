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
import gdk.Pixbuf;

import nwnxml;
import resource;
import node;
import embedded;

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
    	if(log.logLevel==LogLevel.trace){
			writeln("\x1b[2m",log.file,"=> ",log.funcName,"@",log.line,": ",log.msg,"\x1b[m");
			return;
		}

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
		new NwnXml(DirEntry(file));
		return 0;
	}

	window = new MainWindow("");
	
	auto menubar = new MenuBar();
	auto menu = menubar.append("Move console");

	auto consoleWrap = new ScrolledWindow(PolicyType.EXTERNAL, PolicyType.ALWAYS);
	consoleWrap.setMinContentHeight(100);
	console = new TextView;
	console.setEditable(false);
	console.setCursorVisible(false);
	console.setLeftMargin(5);
	console.setWrapMode(WrapMode.NONE);
	consoleWrap.add(console);

	vbox = new VBox(false, 0);
	vbox.packStart(menubar, false, true, 0);
	vbox.packEnd(consoleWrap, true, true, 5);
	window.add(vbox);

	window.setIcon(new Pixbuf(RES_XPM_ICON));

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
	import std.conv : to;

	@safe pure nothrow this(NwnXmlNode* xmlNode, in string msg,
			string excFile =__FILE__,
			size_t excLine = __LINE__,
			Throwable excNext = null) {
		super(msg,excFile,excLine,excNext);
		node = xmlNode;
		thrown = this;
	}
	@safe pure nothrow this(NwnXmlNode* xmlNode, Throwable toForward) {
		super(toForward.msg,toForward.file,toForward.line,toForward.next);
		node = xmlNode;
		info = toForward.info;
		thrown = toForward;
	}
	override string toString(){
		string ret;
		if(msg.length>0){
			if(node !is null)
				ret ~= node.line.to!string~":"~node.column.to!string~"| <"~node.tag~">: "~msg~" ("~typeid(thrown).name~")\n";
			else
				ret ~= msg~" ("~typeid(thrown).name~")\n";
		}

		debug{
			ret ~= "---- Stacktrace ----\n";
			foreach(t ; info)
				ret~=" "~t~"\n";
		}

		return ret;
	}
	NwnXmlNode* node;
	Throwable thrown;
}
void BuildWidgets(NwnXmlNode* xmlNode, Node parent, string sDecal=""){
	
	if(xmlNode.tag == "ROOT"){
		foreach(node ; xmlNode.children){
			if(node.tag == "UIScene"){
				try{
					parent = new UIScene(window, vbox, node);
				}
				catch(Exception e){
					throw new BuildException(xmlNode, e);
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
					warning(xmlNode.tag, " is not handled by the program. Treated as a UIPane");
					parent = new UIPane(parent, xmlNode);
					break;

			}
		}
		catch(Exception e){
			throw new BuildException(xmlNode, e);
		}

		foreach_reverse(e ; xmlNode.children){
			BuildWidgets(e, parent,sDecal~"  ");
		}
	}


}