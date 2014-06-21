module material;

import std.file;
import std.string;
//import derelict.sdl2.sdl;
//import derelict.sdl2.image;

class Material{
	this(DirEntry file){
		//surface = IMG_Load(file.name.toStringz);
		path = file.name;
	}

	string path;

	//SDL_Surface* surface = null;
}