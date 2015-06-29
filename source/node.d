module node;

import std.stdio;
import std.conv : to, parse, ConvException;
import std.traits;
import std.string : toUpper, split;
import gtk.MainWindow;
import gtk.Widget;
import gtk.Layout;
import gtk.Image;
import gtk.VBox;
import gtk.Label;
import gdk.RGBA;
import gdk.Cairo;
import gdk.Event;
import cairo.Context;
import cairo.ImageSurface;
import cairo.Pattern;
import gdk.Pixbuf;
import cairo.Surface;
import material;
import resource;
import nwnxml;
import embedded;
import logger;
import window;

public import vect;

enum XMacro : string{
	RIGHT="ALIGN_RIGHT",
	LEFT="ALIGN_LEFT",
	CENTER="ALIGN_CENTER"
}
enum YMacro : string{
	TOP="ALIGN_TOP",
	BOTTOM="ALIGN_BOTTOM",
	CENTER="ALIGN_CENTER"
}
enum WidthMacro : string{
	PARENT="PARENT_WIDTH",
	DYNAMIC="DYNAMIC",
	SCREEN="SCREEN_WIDTH"

}
enum HeightMacro : string{
	PARENT="PARENT_HEIGHT",
	DYNAMIC="DYNAMIC",
	SCREEN="SCREEN_HEIGHT"
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

//#######################################################################################
//#######################################################################################
//#######################################################################################
class Node {
	this(string _name, Node _parent, in Vect _position, in Vect _size, in Vect _xmlPosition) {

		name = _name;
		position = _position;
		size = _size;
		if(size.x<=0) size.x = 1;
		if(size.y<=0) size.y = 1;
		xmlPosition = _xmlPosition;

		parent = _parent;

		container = new Layout(null, null);
		container.setSizeRequest(size.x, size.y);
		container.setHscrollPolicy(GtkScrollablePolicy.MINIMUM);
		container.setVscrollPolicy(GtkScrollablePolicy.MINIMUM);
		container.setName(name);
	
		if(parent !is null){
			parent.children ~= this;
			parent.container.put(container, position.x, position.y);
		}
	}

	string name;
	Node parent;
	Vect position;
	Vect size;
	float opacity=1.0;

	Node[] children;

	Layout container;

	Vect xmlPosition;

	@property string className() const{
		return typeid(this).name.split(".")[1];
	}
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIScene : Node {
	static Get(){
		return m_inst;
	}


	this(NwnXmlNode* xmlNode){
		string name;
		Vect size;

		foreach(key ; xmlNode.attr.byKey){
			auto value = xmlNode.attr[key];
			switch(key){
				case "name": 
					name=value;
					xmlNode.attr.remove(key);
					break;
				case "width":
					switch(value){
						case WidthMacro.SCREEN: size.x=FullscreenSize.x; break;
						default:
							try size.x=value.to!int;
							catch(ConvException)
								NWNLogger.xmlWarning(xmlNode, "width='"~value~"' is not valid. Possible values are: integer, 'SCREEN_WIDTH'");
					}
					xmlNode.attr.remove(key);
					break;
				case "height":
					switch(value){
						case HeightMacro.SCREEN: size.y=FullscreenSize.y; break;
						default:
							try size.y=value.to!int;
							catch(ConvException)
								NWNLogger.xmlWarning(xmlNode, "height='"~value~"' is not valid. Possible values are: integer, 'SCREEN_HEIGHT'");
					}
					xmlNode.attr.remove(key);
					break;
				case "OnAdd": 
					xmlNode.attr.remove(key);
					break;//TODO impl

				case "x","y": //position should always be 0
					xmlNode.attr.remove(key);
					break;
				case "draggable","fadein","fadeout","scriptloadable","priority","backoutkey": //Ignored attr
					xmlNode.attr.remove(key);
					break;

				case "fullscreen":
					if(size.x==0) size.x=FullscreenSize.x;
					if(size.y==0) size.y=FullscreenSize.y;
					xmlNode.attr.remove(key);
					break;

				default: break;
			}
		}

		super(name, null, Vect(0,0), size, Vect(cast(int)(xmlNode.column),cast(int)(xmlNode.line)));


		//window background
		auto pbuf = new Pixbuf(RES_XPM_BACKGROUND);
		auto surface = ImageSurface.create(CairoFormat.ARGB32, pbuf.getWidth, pbuf.getHeight);
		auto ctx = Context.create(surface);
		setSourcePixbuf(ctx, pbuf, 0, 0);
		ctx.paint();
		
		auto fill = Pattern.createForSurface(surface);
		fill.setExtend(CairoExtend.REPEAT);
		container.addOnDraw((Scoped!Context c, Widget w){
			c.setSource(fill);
			c.paint();

			c.identityMatrix();
			return false;
		});

		//Register instance
		m_inst = this;
	}

	enum FullscreenSize = Vect(1024, 768);
	
	private __gshared UIScene m_inst;
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIPane : Node {
	this(Node parent, NwnXmlNode* xmlNode){
		string name;
		Vect pos, size;
		bool visible = true;

		foreach(key ; xmlNode.attr.byKey){
			auto value = xmlNode.attr[key];
			try{
				switch(key){
					case "name":
						name=value;
						xmlNode.attr.remove(key);
						break;
					case "width":
						switch(value){
							case WidthMacro.PARENT: size.x=parent.size.x; break;
							case WidthMacro.DYNAMIC:
								NWNLogger.xmlWarning(xmlNode, className~": width=DYNAMIC is not supported yet");
								size.x=10;
								break;
							default:
								try size.x=value.to!int;
								catch(ConvException e)
									NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not an int ("~e.msg~")");
								break;
						}
						xmlNode.attr.remove(key);
						break;
					case "height":
						switch(value){
							case HeightMacro.PARENT: size.y=parent.size.y; break;
							case HeightMacro.DYNAMIC: 
								NWNLogger.xmlWarning(xmlNode, className~": height=DYNAMIC is not supported yet");
								size.y=10;
								break;
							default:
								try size.y=value.to!int;
								catch(ConvException e)
									NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not an int ("~e.msg~")");
								break;
						}
						xmlNode.attr.remove(key);
						break;
					case "alpha":
						try opacity = value.to!float;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not a float ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;
					case "hidden":
						try visible = !value.to!bool;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not a boolean ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;

					case "OnAdd": break;//TODO impl

					case "draggable","fadein","fadeout","scriptloadable","priority","backoutkey": break;//Ignored attr

					default: break;
				}
			}
			catch(ResourceException e){
				NWNLogger.xmlWarning(xmlNode, className~": "~e.msg);
			}
		}

		if("x" in xmlNode.attr){
			switch(xmlNode.attr["x"]){
				case XMacro.LEFT: pos.x=0; break;
				case XMacro.RIGHT: pos.x=parent.size.x-size.x; break;
				case XMacro.CENTER: pos.x=parent.size.x/2-size.x/2; break;
				default: 
					try pos.x=xmlNode.attr["x"].to!int;
					catch(ConvException e)
						NWNLogger.xmlWarning(xmlNode,  "x="~xmlNode.attr["x"]~" is not an int ("~e.msg~")");
					break;
			}
			xmlNode.attr.remove("x");
		}
		if("y" in xmlNode.attr){
			switch(xmlNode.attr["y"]){
				case YMacro.TOP: pos.y=0; break;
				case YMacro.BOTTOM: pos.y=parent.size.y-size.y; break;
				case YMacro.CENTER: pos.y=parent.size.y/2-size.y/2; break;
				default:
					try pos.y=xmlNode.attr["y"].to!int;
					catch(ConvException e)
						NWNLogger.xmlWarning(xmlNode,  "x="~xmlNode.attr["y"]~" is not an int ("~e.msg~")");
					break;
			}
			xmlNode.attr.remove("y");
		}
		super(name, parent, pos, size, Vect(cast(int)(xmlNode.column),cast(int)(xmlNode.line)));

		if(!visible){
			container.setNoShowAll(true);
			container.setVisible(visible);
		}
	}
}

//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIFrame : UIPane {
	this(Node parent, NwnXmlNode* xmlNode){
		Material mfill;//, mtopleft, mtop, mtopright, mleft, mright, mbottomleft, mbottom, mbottomright;
		Material[8] mborders;

		foreach(key ; xmlNode.attr.byKey){
			auto value = xmlNode.attr[key];
			try{
				switch(key){
					case "fillstyle":
						try fillstyle = value.toUpper.to!FillStyle;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode, key~"="~value~"  is not valid. Possible values are: ",EnumMembers!FillStyle);
						xmlNode.attr.remove(key);
						break;
					case "fill": 
						mfill = Resource.FindFileRes!Material(value);
						//xmlNode.attr.remove(key);
						break;
					case "topleft": 
						mborders[0] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "top": 
						mborders[1] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "topright": 
						mborders[2] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "left": 
						mborders[3] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "right": 
						mborders[4] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "bottomleft": 
						mborders[5] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "bottom": 
						mborders[6] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "bottomright": 
						mborders[7] = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					case "border": 
						try border = value.to!uint;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not an int ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;
					
					default: break;
				}
			}
			catch(ResourceException e){
				NWNLogger.xmlWarning(xmlNode, className~": "~e.msg);
			}
		}

		//UIframe specific
		if("width" !in xmlNode.attr)
			xmlNode.attr["width"] = "PARENT_WIDTH";
		if("height" !in xmlNode.attr)
			xmlNode.attr["height"] = "PARENT_HEIGHT";

		super(parent, xmlNode);

		if(cast(UIButton)parent !is null && "state" in xmlNode.attr){
			try{
				(cast(UIButton)parent)
					.RegisterFrame(xmlNode.attr["state"].toUpper.to!(UIButton.State), this);
			}
			catch(ConvException e)
				NWNLogger.xmlWarning(xmlNode, "state="~xmlNode.attr["state"]~" is not an valid state. Possible values are: ",EnumMembers!(UIButton.State));
		}

		fillsize = size-2*border;
		if(mfill !is null){

			//Load surface for pattern
			Pixbuf pbuf = mfill;
			if(fillstyle == FillStyle.STRETCH)
				pbuf = pbuf.scaleSimple(fillsize.x,fillsize.y,GdkInterpType.BILINEAR);

			auto surface = ImageSurface.create(CairoFormat.ARGB32, pbuf.getWidth, pbuf.getHeight);
			auto ctx = Context.create(surface);
			setSourcePixbuf(ctx, pbuf, 0, 0);
			ctx.paint();

			//Pattern
			fill = Pattern.createForSurface(surface);

			if(fillstyle == FillStyle.TILE)
				fill.setExtend(CairoExtend.REPEAT);
			else
				fill.setExtend(CairoExtend.NONE);
		}

		foreach(index, ref mat ; mborders){
			if(mat !is null){
				auto bordergeom = GetBorderGeometry(index);
				Pixbuf pbuf = mat.scaleSimple(bordergeom.width,bordergeom.height,GdkInterpType.BILINEAR);
				auto surface = ImageSurface.create(CairoFormat.ARGB32, bordergeom.width, bordergeom.height);
				auto ctx = Context.create(surface);
				setSourcePixbuf(ctx, pbuf, 0, 0);
				ctx.paint();

				//Pattern
				borders[index] = Pattern.createForSurface(surface);
			}
		}


		container.addOnDraw((Scoped!Context c, Widget w){

			foreach(index, ref pattern ; borders){
				if(pattern !is null){
					c.save;

					auto bordergeom = GetBorderGeometry(index);
					c.translate(bordergeom.x, bordergeom.y);
					c.setSource(pattern);
					c.rectangle(0, 0, bordergeom.width, bordergeom.height);
					c.clip();
					c.paintWithAlpha(opacity);

					c.restore;
				}
			}
			

			if(fill !is null){
				c.save;

				//todo: handle fillstyle=center here?
				c.translate(border, border);
				c.setSource(fill);
				c.rectangle(0, 0, fillsize.x, fillsize.y);
				c.clip();
				c.paintWithAlpha(opacity);

				c.restore;
			}
			c.identityMatrix();
			return false;
		});
	}
	


	


	enum FillStyle : string{
		STRETCH="stretch",
		TILE="tile",
		CENTER="center"
	}

	Pattern fill;
	FillStyle fillstyle = FillStyle.STRETCH;
	Vect fillsize;

	uint border = 0;
	Pattern[8] borders;

private:
	auto GetBorderGeometry(size_t borderIndex){
		import std.typecons: Tuple;
		alias data = Tuple!(int,"x", int,"y", int,"width", int,"height");
		switch(borderIndex){
			case 0: return data(0,0,                          border,border);
			case 1: return data(border,0,                     fillsize.x,border);
			case 2: return data(size.x-border,0,              border,border);

			case 3: return data(0,border,                     border,fillsize.y);
			case 4: return data(size.x-border,border,         border,fillsize.y);

			case 5: return data(0, size.y-border,             border,border);
			case 6: return data(border, size.y-border,        fillsize.x,border);
			case 7: return data(size.x-border,size.y-border,  border,border);
			default: assert(0);
		}
	}
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIIcon : UIPane {
	this(Node parent, NwnXmlNode* xmlNode){
		Material mimg;

		foreach(key ; xmlNode.attr.byKey){
			auto value = xmlNode.attr[key];
			try{
				switch(key){
					case "img": 
						mimg = Resource.FindFileRes!Material(value);
						xmlNode.attr.remove(key);
						break;
					default: break;
				}
			}
			catch(ResourceException e){
				NWNLogger.xmlWarning(xmlNode, className~": "~e.msg);
			}
		}

		super(parent, xmlNode);

		if(mimg !is null){

			//Load surface for pattern
			Pixbuf pbuf = mimg.scaleSimple(size.x,size.y,GdkInterpType.BILINEAR);

			auto surface = ImageSurface.create(CairoFormat.ARGB32, pbuf.getWidth, pbuf.getHeight);
			auto ctx = Context.create(surface);
			setSourcePixbuf(ctx, pbuf, 0, 0);
			ctx.paint();

			//Pattern
			img = Pattern.createForSurface(surface);
			img.setExtend(CairoExtend.NONE);
		}



		container.addOnDraw((Scoped!Context c, Widget w){
			if(img !is null){
				c.save;

				c.setSource(img);
				c.paintWithAlpha(opacity);//todo: handle alpha

				c.restore;
			}
			c.identityMatrix();
			return false;
		});
	}

	Pattern img;
}



//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIButton : UIPane {
	this(Node parent, NwnXmlNode* xmlNode){

		foreach(key ; xmlNode.attr.byKey){
			auto value = xmlNode.attr[key];
			try{
				switch(key){
					case "text": 
						defaultText = value;
						xmlNode.attr.remove(key);
						break;
					default: break;
				}
			}
			catch(ResourceException e){
				NWNLogger.xmlWarning(xmlNode, className~": "~e.msg);
			}
		}

		super(parent, xmlNode);


		if("style" in xmlNode.attr){
			auto stylesheet = Resource.FindFileRes!NwnXml("stylesheet.xml");
			auto styleNode = stylesheet.FindFirstByName(stylesheet.root, xmlNode.attr["style"]);
			if(styleNode !is null){
				//Merge with current xmlNode.attr
				foreach(key, value ; styleNode.attr){
					if(key !in xmlNode.attr && key!="name"){
						//do not override current xmlNode.attr with style xmlNode.attr
						xmlNode.attr[key] = value;
					}
				}
				//Add children (they will be overridden later when parsing inner UIFrames)
				foreach_reverse(child ; styleNode.children){
					if(child.tag == "UIFrame"){
						auto node = NwnXmlNode(child.tag, child.attr, null, [], xmlNode.line, xmlNode.column);
						new UIFrame(this, &node);
					}
					else if(child.tag == "UIText"){
						auto node = NwnXmlNode(child.tag, child.attr, null, [], xmlNode.line, xmlNode.column);
						node.attr["text"] = defaultText;
						node.attr["width"] = "PARENT_WIDTH";
						node.attr["height"] = "PARENT_HEIGHT";
						new UIText(this, &node);
					}
				}
			}
			else
				NWNLogger.xmlWarning(xmlNode, "Style "~xmlNode.attr["style"]~" could not be found in stylesheet.xml");
			xmlNode.attr.remove("style");
		}

		if(childText is null && defaultText!is null){
			//Create default UIText

			auto node = NwnXmlNode("UIText", [
				"align": "center",
				"valign": "middle",
				"text": defaultText,
				"width": "PARENT_WIDTH",
				"height": "PARENT_HEIGHT"
			], null, [], xmlNode.line, xmlNode.column);
			new UIText(this, &node);
		}

		//UP: normal state
		//DOWN: pressing button, with mouse over
		//FOCUSED: button has been pressed
		//HILITED: the mouse if over
		//HIFOCUS: has been pressed, mouse if over
		//DISABLED: disabled by parameter/script

		container.addOnButtonPress(delegate(Event e, Widget w){
			foreach(state, node ; childrenFrames){
				SetState(State.DOWN);
			}
			return false;
		});
		container.addOnButtonRelease((Event e, Widget w){
			foreach(state, node ; childrenFrames){
				if(mouseover) SetState(State.HIFOCUS);
				else SetState(State.FOCUSED);
			}
			return false;
		});
		container.addOnEnterNotify((Event e, Widget w){
			mouseover = true;
			foreach(state, node ; childrenFrames){
				SetState(State.HILITED);
			}
			return false;
		});
		container.addOnLeaveNotify((Event e, Widget w){
			//Be sure that the mouse is out
			// Because the event is also received on mouse click released
			double x, y;
			e.getCoords(x, y);
			if(!(0<=x && x<size.x && 0<=y && y<size.y)){
				mouseover = false;
				SetState(State.UP);
			}
			return false;
		});
	}

	Pattern img;
	bool mouseover = false;

	enum State{
		UP,
		DOWN,
		DISABLED,
		FOCUSED,
		HILITED,
		HIFOCUS,
		HEADER,
		HIHEADER,
		DOWNHEADER,
		BASE,
	}
	UIFrame[State] childrenFrames;
	UIText childText;
	string defaultText;

	void RegisterFrame(in State state, UIFrame frame){
		if(state in childrenFrames){
			childrenFrames[state].container.destroy();
			childrenFrames[state].destroy();
		}

		childrenFrames[state] = frame;
		frame.container.setNoShowAll(true);
		frame.container.setVisible(state==State.UP || state==State.BASE);
	}
	void RegisterText(UIText text){
		if(childText !is null){
			childText.container.destroy();
			childText.destroy();
		}

		childText = text;
	}

	void SetState(in State state){
		foreach(s, node ; childrenFrames){
			node.container.setVisible(s==state || s==State.BASE);
		}
		if(childText !is null){
			childText.container.setVisible(false);
			childText.container.setVisible(true);
		}
	}
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIText : UIPane {
	this(Node parent, NwnXmlNode* xmlNode){

		bool editable = false;
		bool multiline = false;
		int lines = 1;
		auto halign = Align.START;
		auto valign = Align.START;
		uppercase = false;
		string text = "";
		auto color = new RGBA(1,1,1);
		uint fontsize = 14;


		foreach(key ; xmlNode.attr.byKey){
			auto value = xmlNode.attr[key];
			try{
				switch(key){
					case "editable":
						NWNLogger.xmlWarning(xmlNode, className~": editable is not supported yet");
						try editable = value.to!bool;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not a boolean ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;
					case "align":
						switch(value) with(HAlign){
							case HAlign.LEFT: halign = Align.START; break;
							case HAlign.CENTER: halign = Align.CENTER; break;
							case HAlign.RIGHT: halign = Align.END; break;
							default:
								NWNLogger.xmlWarning(xmlNode, key~"="~value~" is not valid. Possible values are: ",EnumMembers!HAlign);
						}
						xmlNode.attr.remove(key);
						break;
					case "valign":
						switch(value) with(VAlign){
							case VAlign.TOP: valign = Align.START; break;
							case VAlign.MIDDLE: valign = Align.CENTER; break;
							case VAlign.BOTTOM: valign = Align.END; break;
							default:
								NWNLogger.xmlWarning(xmlNode, key~"="~value~" is not valid. Possible values are: ",EnumMembers!VAlign);
						}
						xmlNode.attr.remove(key);
						break;
					case "multiline":
						try multiline = value.to!bool;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not a boolean ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;
					case "maxlines":
						try lines = value.to!int;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not a int ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;
					case "uppercase":
						try uppercase = value.to!bool;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode,  key~"="~value~" is not a boolean ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;
					case "color":
						try{
							uint colorvalue = parse!int(value, 16);
							color = new RGBA(
								((colorvalue&0xFF0000)>>16)/255.0,
								((colorvalue&0x00FF00)>>8)/255.0,
								((colorvalue&0x0000FF))/255.0
							);
						}
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode, key~"="~value~" is not a hexadecimal color value, ie 'F0F0F0' ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;
					case "pointsize":
						try fontsize = value.to!uint;
						catch(ConvException e)
							NWNLogger.xmlWarning(xmlNode, key~"="~value~" is not an int >= 0 ("~e.msg~")");
						xmlNode.attr.remove(key);
						break;


					case "strref":
						if(text=="")
							text = "{strref}";
						NWNLogger.xmlWarning(xmlNode, className~": strref is not handled yet");
						xmlNode.attr.remove(key);
						break;
					case "text":
						text = value;
						xmlNode.attr.remove(key);
						break;

					default: break;
				}
			}
			catch(ResourceException e){
				NWNLogger.xmlWarning(xmlNode, className~": "~e.msg);
			}
		}

		super(parent, xmlNode);

		auto lbl = new Label(text);
		lbl.setLineWrap(multiline);
		if(multiline) lbl.setLineWrapMode(PangoWrapMode.WORD);
		lbl.setLines(multiline? lines : 1);
		lbl.setHalign(halign);
		lbl.setValign(valign);
		lbl.overrideColor(StateFlags.NORMAL, color);

		//See modifyFont (new PgFontDescription(PgFontDescription.fromString(family ~ " " ~ size)));
		lbl.modifyFont("", cast(int)(fontsize*0.7));

		if(uppercase)
			lbl.setText(lbl.getText.toUpper);

		if(editable){

		}
		else{
			lbl.setEvents(0);
			container.setEvents(0);
		}


		lbl.setSizeRequest(size.x, size.y);
		container.add(lbl);

		//Register to button
		if(cast(UIButton)parent !is null){
			(cast(UIButton)parent).RegisterText(this);
		}
	}

	enum HAlign{
		LEFT="left",
		CENTER="center",
		RIGHT="right",
	}
	enum VAlign{
		TOP="top",
		MIDDLE="middle",
		BOTTOM="bottom",
	}






	bool uppercase;
}