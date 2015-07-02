module logger;

import std.stdio;
import std.experimental.logger;

import nwnxml;
import window;

public{
	import std.experimental.logger : trace, info, warning, critical;
}


class NWNLogger : Logger
{
	this() @safe
	{
		super(LogLevel.all);
		sharedLog = this;//sharedLog is a global var defining the default logger
	}

	override void writeLogMsg(ref LogEntry log) @trusted
	{
		if(log.logLevel==LogLevel.trace){
			writeln("\x1b[2m",log.file,"=> ",log.funcName,"@",log.line,": ",log.msg,"\x1b[m");
			return;
		}

		writeln("\x1b[2m",log.timestamp.toString[12..20],": \x1b[m",log.msg);

		if(Window.win !is null){
			Window.AppendLog(log.msg);
		}
	}

	static void xmlLimitation(T...)(NwnXmlNode* node, T msg){
		sharedLog.info(node.line,":",node.column,":<",node.tag,"> NWN2GuiViewer limit.: ", msg);
	}
	static void xmlWarning(T...)(NwnXmlNode* node, T msg){
		sharedLog.warning(node.line,":",node.column,":<",node.tag,"> Warning: ", msg);
	}
	static void xmlException(T...)(NwnXmlNode* node, T msg){
		sharedLog.critical(node.line,":",node.column,":<",node.tag,"> ERROR: ", msg);
	}
}