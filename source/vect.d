module vect;

alias Vect = VectT!int;
alias Vectf = VectT!float;

struct VectT(T) {
	this(T _x, T _y){
		m_x=_x; m_y=_y;
	}

	@property{
		T x()const{return m_x;}
		void x(T _x){m_x=_x;}
		T y()const{return m_y;}
		void y(T _y){m_y=_y;}
	}

	bool opEquals(const VectT!T other)const{
	  return (m_x==other.m_x && m_y==other.m_y);
	}

	VectT!T opBinary(string op)(const VectT!T other)const{
		return VectT!T(mixin("m_x "~op~" other.m_x"), mixin("m_y "~op~" other.m_y"));
	}
	VectT!T opBinary(string op, O)(const O other)const
		if(__traits(isArithmetic, O)){
		return VectT!T(mixin("m_x "~op~" other"), mixin("m_y "~op~" other"));
	}

	T[] opSlice(){
		return [m_x, m_y];
	}

	void opOpAssign(string op)(const VectT!T other){
		mixin("this.m_x "~op~"= other.m_x;");
		mixin("this.m_y "~op~"= other.m_y;");
	}




private:
	T m_x=0, m_y=0;
}