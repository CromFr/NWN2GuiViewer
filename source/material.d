module material;

import std.file;
import std.string;
import std.stdio;

import gdk.Pixbuf;
import tga;

class Material : Pixbuf{
	this(DirEntry file){
		path = file.name;

		char[] pixData;
		Image img = readImage(File(path));
		auto rowStride = img.header.width*4;
		foreach_reverse(row ; 0..img.header.height){
			foreach(col ; 0..img.header.width){
				auto p = img.pixels[row*img.header.width + col];
				pixData ~= [p.r,p.g,p.b,p.a];
			}
		}
		super(
			cast(char[])pixData,
			Colorspace.RGB, true,
			8,
			cast(int)img.header.width,
			cast(int)img.header.height,
			cast(int)img.header.width*4,
			null, null);
	}

	this(Pixbuf pb){
		super(pb.getPixbufStruct);
	}

	string path;
}