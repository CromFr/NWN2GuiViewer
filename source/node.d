module node;

import std.stdio;
import std.conv : to, parse;
import std.traits;
import std.string : toLower, toUpper;
import std.experimental.logger;
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

public import vect;

enum XMacro : string{
	Right="ALIGN_RIGHT",
	Left="ALIGN_LEFT",
	Center="ALIGN_CENTER"
}
enum YMacro : string{
	Top="ALIGN_TOP",
	Bottom="ALIGN_BOTTOM",
	Center="ALIGN_CENTER"
}
enum WidthMacro : string{
	Parent="PARENT_WIDTH",
	Dynamic="DYNAMIC"
}
enum HeightMacro : string{
	Parent="PARENT_HEIGHT",
	Dynamic="DYNAMIC"
}

//#######################################################################################
//#######################################################################################
//#######################################################################################
class Node {
	this(string name_, Node parent_, in Vect position_=Vect(0,0), in Vect size_=Vect(0,0)) {

		name = name_;
		position = position_;
		size = size_;

		parent = parent_;

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

	@property Vect absposition(){
		Vect ret = Vect(0,0);
		Node p = this;
		while(p !is null){
			ret+=p.position;
			p = parent;
		}
		return ret;
	}
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIScene : Node {
	static Get(){
		return m_inst;
	}


	this(MainWindow window, VBox innercont, ref string[string] attributes){
		string name;
		Vect size;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "name": 
					name=value;
					attributes.remove(key);
					break;
				case "width":
					size.x=value.to!int;
					attributes.remove(key);
					break;
				case "height":
					size.y=value.to!int;
					attributes.remove(key);
					break;
				case "OnAdd": 
					attributes.remove(key);
					break;//TODO impl

				case "x","y": //position should always be 0
					attributes.remove(key);
					break;
				case "draggable","fadein","fadeout","scriptloadable","priority","backoutkey": //Ignored attr
					attributes.remove(key);
					break;

				default: break;
			}
		}

		super(name, null, Vect(0,0), size);

		window.setTitle(name);

		//Forbid resize
		window.setDefaultSize(size.x, size.y);
		//auto geom = GdkGeometry(size.x, size.y, size.x, size.y);
		//window.setGeometryHints(null, &geom, GdkWindowHints.MIN_SIZE|GdkWindowHints.MAX_SIZE);

		//window background
		auto pbuf = Resource.FindFileRes!Material("bg.tga");
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
		
		innercont.packStart(container, false, false, 0);

		//Register instance
		m_inst = this;
	}

	private __gshared UIScene m_inst;
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIPane : Node {
	this(Node parent, ref string[string] attributes){
		string name;
		Vect pos, size;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "name": 
					name=value;
					attributes.remove(key);
					break;
				case "width": 
					switch(value){
						case WidthMacro.Parent: size.x=parent.size.x; break;
						case WidthMacro.Dynamic: warning("Dynamic is not handled"); size.x=10; break;
						default: size.x=value.to!int; break;
					}
					attributes.remove(key);
					break;
				case "height": 
					switch(value){
						case HeightMacro.Parent: size.y=parent.size.y; break;
						case HeightMacro.Dynamic: warning("Dynamic is not handled"); size.y=10; break;
						default: size.y=value.to!int; break;
					}
					attributes.remove(key);
					break;
				case "alpha": 
					opacity = value.to!float;
					attributes.remove(key);
					break;

				case "OnAdd": break;//TODO impl

				case "draggable","fadein","fadeout","scriptloadable","priority","backoutkey": break;//Ignored attr

				default: break;
			}
		}

		if("x" in attributes){
			switch(attributes["x"]){
				case XMacro.Left: pos.x=0; break;
				case XMacro.Right: pos.x=parent.size.x-size.x; break;
				case XMacro.Center: pos.x=parent.size.x/2-size.x/2; break;
				default: pos.x=attributes["x"].to!int; break;
			}
			attributes.remove("x");
		}
		if("y" in attributes){
			switch(attributes["y"]){
				case YMacro.Top: pos.y=0; break;
				case YMacro.Bottom: pos.y=parent.size.y-size.y; break;
				case YMacro.Center: pos.y=parent.size.y/2-size.y/2; break;
				default: pos.y=attributes["y"].to!int; break;
			}
			attributes.remove("y");
		}
		super(name, parent, pos, size);
		//container.overrideBackgroundColor(GtkStateFlags.NORMAL, new RGBA(0,1,0,1));
	}
}

//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIFrame : UIPane {
	this(Node parent, ref string[string] attributes){
		Material mfill;//, mtopleft, mtop, mtopright, mleft, mright, mbottomleft, mbottom, mbottomright;
		Material[8] mborders;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "fillstyle":
					switch(value){
						case FillStyle.Stretch: fillstyle=FillStyle.Stretch; break;
						case FillStyle.Tile: fillstyle=FillStyle.Tile; break;
						default: throw new Exception("Unknown fillstyle "~value);
					}
					attributes.remove(key);
					break;
				case "fill": 
					mfill = Resource.FindFileRes!Material(value.toLower);
					//attributes.remove(key);
					break;
				case "topleft": 
					mborders[0] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "top": 
					mborders[1] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "topright": 
					mborders[2] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "left": 
					mborders[3] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "right": 
					mborders[4] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomleft": 
					mborders[5] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottom": 
					mborders[6] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomright": 
					mborders[7] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "border": 
					border = value.to!uint;
					attributes.remove(key);
					break;
				
				default: break;
			}
		}

		//UIframe specific
		if("width" !in attributes)
			attributes["width"] = "PARENT_WIDTH";
		if("height" !in attributes)
			attributes["height"] = "PARENT_HEIGHT";

		super(parent, attributes);

		if(cast(UIButton)parent !is null && "state" in attributes){
			(cast(UIButton)parent)
				.RegisterFrame(attributes["state"].toUpper.to!(UIButton.State), this);
		}

		fillsize = size-2*border;
		if(mfill !is null){

			//Load surface for pattern
			Pixbuf pbuf = mfill;
			if(fillstyle == FillStyle.Stretch)
				pbuf = pbuf.scaleSimple(fillsize.x,fillsize.y,GdkInterpType.BILINEAR);

			auto surface = ImageSurface.create(CairoFormat.ARGB32, pbuf.getWidth, pbuf.getHeight);
			auto ctx = Context.create(surface);
			setSourcePixbuf(ctx, pbuf, 0, 0);
			ctx.paint();

			//Pattern
			fill = Pattern.createForSurface(surface);

			if(fillstyle == FillStyle.Tile)
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
		Stretch="stretch",
		Tile="tile",
		Center="center"
	}

	Pattern fill;
	FillStyle fillstyle = FillStyle.Stretch;
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
	this(Node parent, ref string[string] attributes){
		Material mimg;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "img": 
					mimg = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				default: break;
			}
		}

		super(parent, attributes);

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
	this(Node parent, ref string[string] attributes){

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "text": 
					defaultText = value;
					attributes.remove(key);
					break;
				default: break;
			}
		}

		super(parent, attributes);


		if("style" in attributes){
			auto stylesheet = Resource.FindFileRes!NwnXml("stylesheet.xml");
			auto styleNode = stylesheet.FindFirstByName(stylesheet.root, attributes["style"]);
			if(styleNode !is null){
				//Merge with current attributes
				foreach(key, value ; styleNode.attr){
					if(key !in attributes && key!="name"){
						//do not override current attributes with style attributes
						attributes[key] = value;
					}
				}
				//Add children (they will be overridden later when parsing inner UIFrames)
				foreach_reverse(child ; styleNode.children){
					if(child.tag == "UIFrame"){
						new UIFrame(this, child.attr);
					}
					else if(child.tag == "UIText"){
						child.attr["text"] = defaultText;
						new UIText(this, child.attr);
					}
				}
			}
			else
				throw new Exception("Style "~attributes["style"]~" could not be found in stylesheet.xml");
			attributes.remove("style");
		}

		if(childText is null && defaultText!is null){
			//Create default UIText
			auto attr = [
				"align": "center",
				"valign": "middle",
				"text": defaultText,
			];
			new UIText(this, attr);
		}


		container.addOnButtonPress(delegate(Event e, Widget w){
			foreach(state, node ; childrenFrames){
				if(mouseover) node.container.setVisible(state==State.HIFOCUS || state==State.BASE);
				else node.container.setVisible(state==State.DOWN || state==State.BASE);
			}
			return false;
		});
		container.addOnButtonRelease((Event e, Widget w){
			foreach(state, node ; childrenFrames){
				if(mouseover) node.container.setVisible(state==State.HILITED || state==State.BASE);
				else node.container.setVisible(state==State.UP || state==State.BASE);
			}
			return false;
		});
		container.addOnEnterNotify((Event e, Widget w){
			mouseover = true;
			foreach(state, node ; childrenFrames){
				node.container.setVisible(state==State.HILITED || state==State.BASE);
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
				foreach(state, node ; childrenFrames){
					node.container.setVisible(state==State.UP || state==State.BASE);
				}
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
		if(state in childrenFrames)
			childrenFrames[state].destroy();

		childrenFrames[state] = frame;
		frame.container.setVisible(state==State.UP || state==State.BASE);
	}
	void RegisterText(UIText text){
		if(childText !is null)
			childText.destroy();

		childText = text;
	}
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIText : UIPane {
	this(Node parent, ref string[string] attributes){

		bool editable = false;
		bool multiline = false;
		int lines = 1;
		auto halign = Align.START;
		auto valign = Align.START;
		uppercase = false;
		string text = "";
		auto color = new RGBA(1,1,1);
		uint fontsize = 14;


		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "editable":
					warning("UITexts: editable is not supported yet");
					editable = value.to!bool;
					attributes.remove(key);
					break;
				case "align":
					switch(value){
						case "left": halign = Align.START; break;
						case "center": halign = Align.CENTER; break;
						case "right": halign = Align.END; break;
						default: throw new Exception("Unknown align='"~value~"'. Possible values are 'left', 'center', 'right'");
					}
					attributes.remove(key);
					break;
				case "valign":
					switch(value){
						case "top": valign = Align.START; break;
						case "middle": valign = Align.CENTER; break;
						case "bottom": valign = Align.END; break;
						default: throw new Exception("Unknown valign='"~value~"'. Possible values are 'top', 'middle', 'bottom'");
					}
					attributes.remove(key);
					break;
				case "multiline":
					multiline = value.to!bool;
					attributes.remove(key);
					break;
				case "maxlines":
					lines = value.to!int;
					attributes.remove(key);
					break;
				case "uppercase":
					uppercase = value.to!bool;
					attributes.remove(key);
					break;
				case "color":
					uint colorvalue = parse!int(value, 16);
					color = new RGBA(
						((colorvalue&0xFF0000)>>16)/255.0,
						((colorvalue&0x00FF00)>>8)/255.0,
						((colorvalue&0x0000FF))/255.0
					);
					attributes.remove(key);
					break;
				case "pointsize":
					fontsize = value.to!uint;
					attributes.remove(key);
					break;


				case "strref":
					if(text=="")
						text = "STRREF";
					warning("strref is not handled yet");
					attributes.remove(key);
					break;
				case "text":
					text = value;
					attributes.remove(key);
					break;

				default: break;
			}
		}

		super(parent, attributes);

		auto lbl = new Label("yolooooo");
		lbl.setLineWrap(multiline);
		if(multiline) lbl.setLineWrapMode(PangoWrapMode.WORD);
		lbl.setLines(multiline? lines : 1);
		lbl.setHalign(halign);
		lbl.setValign(valign);
		lbl.overrideColor(StateFlags.NORMAL, color);

		//gtk fonts seems to be 2x larger that nwn2. Could be fixed by using nwn2 fonts.
		//See modifyFont (new PgFontDescription(PgFontDescription.fromString(family ~ " " ~ size)));
		lbl.modifyFont("", fontsize/2);

		if(uppercase)
			lbl.setText(lbl.getText.toUpper);


		lbl.setSizeRequest(size.x, size.y);
		lbl.show();
		container.add(lbl);

		//Register to button
		if(cast(UIButton)parent !is null){
			(cast(UIButton)parent).RegisterText(this);
		}
	}


	bool uppercase;
}