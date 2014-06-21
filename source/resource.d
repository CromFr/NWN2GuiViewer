module resource;
import std.file : DirEntry, dirEntries, SpanMode;
import std.path;
import std.string : chompPrefix;
import core.thread;

class ResourceException : Exception{
	this(in string msg){super(msg);}
}

/**
	Resource Manager
	Centralize the objects in the program, preventing from having many instances of the same object
	Note: You can have multiple resources with the same name if the resource type is different
**/
class Resource{
static:
	/**
		Add a resource to the manager
		Throws: ResourceException if the resource name already exists for this resource type
	*/
	void AddRes(T)(in string sName, ref T res){
		TypeInfo ti = typeid(T);
		if(!(ti in m_loadedRes && sName in m_loadedRes[ti]))
			m_loadedRes[typeid(T)][sName] = res;
		else
			throw new ResourceException("Resource '"~sName~"' already exists");
	}

	/**
		Constructs a resource and add it to the manager
		Params:
			sName = Name of the resource to create
			ctorArgs = Arguments passed to the resource constructor
		Throws: ResourceException if the resource name already exists for this resource type
		Returns: the created resource
	*/
	ref T CreateRes(T, VT...)(in string sName, VT ctorArgs){
		T res = new T(ctorArgs);
		AddRes!T(sName, res);
		return *(cast(T*)&(m_loadedRes[typeid(T)][sName]));
	}

	/**
		Removes a resource from the manager
		Will let the D garbage collector handle destruction if not used somewhere else
		Params: 
			sName = registered name of the resource
			bForce = true to force destruction (can cause seg faults if the resource is used somewhere else)
		Throws: ResourceException if the resource name does not exist
	*/
	void RemoveRes(T)(in string sName, bool bForce=false){
		TypeInfo ti = typeid(T);
		if(!(ti in m_loadedRes && sName in m_loadedRes[ti])){
			if(bForce)
				destroy(m_loadedRes[typeid(T)][sName]);
			else
				m_loadedRes[typeid(T)][sName] = null;
		}
		else
			throw new ResourceException("Resource '"~sName~"' not found");
	}

	/**
		Gets the resource with its name
		Throws: ResourceException if the resource name does not exist
	*/
	ref T Get(T)(in string sName){
		TypeInfo ti = typeid(T);
		if(ti in m_loadedRes && sName in m_loadedRes[ti])
			return *(cast(T*)&(m_loadedRes[ti][sName]));

		throw new ResourceException("Resource '"~sName~"' not found");
	}

	/**
		Loads the resources contained in directory matching filePatern
		The first argument of the resource constructor must be a DirEntry, followed by any arguments provided with ctorArgs
		Params:
			directory = Path of the folder to search into
			filePatern = file patern to load (ie: "*", "*.vtx", ...)
			recursive = true to search in subfolders
			ctorArgs = Arguments passed to the resource constructor
	*/
	void LoadFromFiles(T, VT...)(in string directory, in string filePatern, in bool recursive, VT ctorArgs){
		foreach(ref file ; dirEntries(directory, filePatern, recursive?SpanMode.depth:SpanMode.shallow)){
			if(file.isFile){
				string sName = file.name.chompPrefix(directory~"/");
				CreateRes!T(sName, file, ctorArgs);
			}
		}
	}



	T FindFileRes(T)(in string fileName){
		try return Get!T(fileName);
		catch(ResourceException e){
			foreach(p ; path){
				foreach(ref file ; dirEntries(p, SpanMode.depth)){
					if(file.isFile && filenameCmp!(CaseSensitive.no)(file.name.baseName, fileName)==0){
						std.stdio.writeln("Loaded ",fileName," from ",file.name);
						return CreateRes!T(fileName, file);
					}
				}
			}

			throw new ResourceException("Resource '"~fileName~"' not found in path");
		}
		//return null;
	}
	__gshared DirEntry[] path;



private:
	this(){}
	__gshared Object[string][TypeInfo] m_loadedRes;
}


unittest {
	import std.stdio;
	import std.file;
	static class Foo{
		this(){}
		this(DirEntry file, int i){s = file.name;}
		string s = "goto bar";
	}

	auto rm = new Resource;

	auto foo = new Foo;
	rm.AddRes("yolo", foo);

	assert(rm.Get!Foo("yolo") == foo);
	assert(rm.Get!Foo("yolo") is foo);

	rm.LoadFromFiles!Foo(".", "dub.json", false, 5);
	assert(rm.Get!Foo("dub.json") !is null);

	auto fe = new FileException("ahahaha");
	rm.AddRes("Boom headshot", fe);
}