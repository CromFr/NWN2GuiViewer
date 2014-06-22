module node;

import std.stdio;
import std.conv : to;
import std.traits;
import std.string : toLower;
import gtk.MainWindow;
import gtk.Widget;
import gtk.Layout;
import gtk.Image;
import gdk.RGBA;
import gdk.Cairo;
import cairo.Context;
import cairo.ImageSurface;
import cairo.Pattern;
import gdk.Pixbuf;
import cairo.Surface;
import material;
import resource;

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
	Parent="PARENT_WIDTH"
}
enum HeightMacro : string{
	Parent="PARENT_HEIGHT"
}


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
	
		if(parent !is null){
			parent.children ~= this;
			parent.container.put(container, position.x, position.y);
		}
	}

	string name;
	Node parent;
	Vect position;
	Vect size;

	Node children[];

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


class UIScene : Node {
	static Get(){
		return m_inst;
	}


	this(ref string[string] attributes){
		string name;
		Vect size;

		foreach(key, value ; attributes.dup){
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

		//Create window
		window = new MainWindow(name);
		window.setIconFromFile("res/icon.ico");

		//Forbid resize
		window.setDefaultSize(size.x, size.y);
		auto geom = GdkGeometry(size.x, size.y, size.x, size.y);
		window.setGeometryHints(null, geom, GdkWindowHints.HINT_MIN_SIZE|GdkWindowHints.HINT_MAX_SIZE);
		window.overrideBackgroundColor(GtkStateFlags.NORMAL, new RGBA(0,0,0,1));
		
		window.add(container);

		//Register instance
		m_inst = this;
	}

	MainWindow window;

	private __gshared UIScene m_inst;
}


class UIPane : Node {
	this(Node parent, ref string[string] attributes){
		string name;
		Vect pos, size;

		foreach(key, value ; attributes.dup){
			switch(key){
				case "name": 
					name=value;
					attributes.remove(key);
					break;
				case "width": 
					switch(value){
						case WidthMacro.Parent: size.x=parent.size.x; break;
						default: size.x=value.to!int; break;
					}
					attributes.remove(key);
					break;
				case "height": 
					switch(value){
						case HeightMacro.Parent: size.y=parent.size.y; break;
						default: size.y=value.to!int; break;
					}
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

class UIFrame : UIPane {
	this(Node parent, ref string[string] attributes){
		Material mfill, mtopleft, mtop, mtopright, mleft, mright, mbottomleft, mbottom, mbottomright;


		foreach(key, value ; attributes.dup){
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
					attributes.remove(key);
					break;
				case "topleft": 
					mtopleft = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "top": 
					mtop = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "topright": 
					mtopright = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "left": 
					mleft = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "right": 
					mright = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomleft": 
					mbottomleft = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottom": 
					mbottom = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomright": 
					mbottomright = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "border": 
					border = value.to!uint;
					attributes.remove(key);
					break;
				default: break;
			}
		}

		super(parent, attributes);

		if(mfill !is null){
			Vect fillsize = size-2*border;

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

		container.addOnDraw(&OnDraw);
	}
	


	bool OnDraw(Context c, Widget w){
		c.translate(border, border);
		c.setSource(fill);
		c.paint();

		c.identityMatrix();

		return true;
	}


	enum FillStyle : string{
		Stretch="stretch",
		Tile="tile"
	}

	Pattern fill;
	FillStyle fillstyle = FillStyle.Stretch;

	uint border = 0;
	Pattern topleft, top, topright, left, right, bottomleft, bottom, bottomright;
}