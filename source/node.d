module node;

import std.stdio;
import std.conv : to;
import std.traits;
import std.string : toLower;
//import derelict.sdl2.sdl;
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
		parent = parent_;
		if(parent !is null)
			parent.children ~= this;

		name = name_;
		position = position_;
		size = size_;
	}

	string name;
	Node parent;
	Vect position;
	Vect size;

	Node children[];

	@property Vect absposition(){
		Vect ret = Vect(0,0);
		Node p = this;
		while(p !is null){
			ret+=p.position;
			p = parent;
		}
		return ret;
	}


	abstract void Draw();

	//Called to draw the node and all its children
	final void EngineDraw(){
		Draw();
		foreach(child ; children)
			child.EngineDraw();
	}

	@disable mixin template NodeCtor()
	{
		this(string name_, Node parent_, Vect position_=Vect(0,0), Vect size_=Vect(0,0)){
			super(name_, parent_, position_, size_);
		}
	}
}


class UIScene : Node {
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
	}

	//SDL_Surface* window;

	override void Draw(){
		writeln("Scene draw");
		//SDL_FillRect(window,null, 0xFFFFFFFF);
	}
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
	}

	override void Draw(){

	}
}

class UIFrame : UIPane {
	this(Node parent, ref string[string] attributes){

		foreach(key, value ; attributes.dup){
			switch(key){
				case "fillstyle":
					switch(value){
						case FillStyle.Stretch: value=FillStyle.Stretch; break;
						case FillStyle.Tile: value=FillStyle.Tile; break;
						default: throw new Exception("Unknown fillstyle "~value);
					}
					attributes.remove(key);
					break;
				case "fill": 
					fill = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "topleft": 
					topleft = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "top": 
					top = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "topright": 
					topright = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "left": 
					left = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "right": 
					right = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomleft": 
					bottomleft = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottom": 
					bottom = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomright": 
					bottomright = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				default: break;
			}
		}

		super(parent, attributes);
	}

	override void Draw(){
		
	}



	enum FillStyle : string{
		Stretch="stretch",
		Tile="tile"
	}

	Material fill;
	FillStyle fillstyle = FillStyle.Stretch;

	uint border;
	Material topleft, top, topright, left, right, bottomleft, bottom, bottomright;
}

//class UIButton : Node {
//	mixin NodeCtor;

//	override void Draw(){

//	}
//}