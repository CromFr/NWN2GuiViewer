module material;

import std.file;
import std.string;

import gdk.Pixbuf;

class Material : Pixbuf{
	this(DirEntry file){
		super(file.name);

		path = file.name;
	}

	string path;
}