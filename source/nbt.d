/+
	This file is part of Superstar64's World Generator.

	Superstar64's World Generator is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation version 3 of the License..

	Superstar64's World Generator is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Superstar64's World Generator.  If not, see <http://www.gnu.org/licenses/>.
+/
module nbt;
import tagged_union;
import std.array;
import std.algorithm;
import std.range;
import std.conv;
import std.typetuple;

auto readNBTFile(string fileName) {
	static import std.file;

	return readNBTBuffer(cast(ubyte[]) std.file.read(fileName));
}

//file can not be modifed after this read
auto readNBTBuffer(ubyte[] file) {
	auto readInner() {
		auto cpy = file;
		if (file.empty || file[0] != 10) {
			throw new NBTException("Bad header");
		}
		file.popFront;
		auto name = cast(string)(readBasicArray!(true, char, short)(file));
		auto tag = Tag_Compound.read!true(file);
		return NBTRoot(name, tag);
	}

	try {
		return readInner();
	}
	catch (Exception e) {
		import std.zlib;

		file = cast(ubyte[]) uncompress(file, 0, 15 + 32);
		return readInner();
	}
}

void writeNBTFile(string fileName, const NBTRoot root, int type = 0) {
	static import std.file;

	ubyte[] buf;
	ubyte[] buf2;
	writeNBTBuffer(buf, buf2, root, type);
	std.file.write(fileName, buf);
}

//overrrides buffers
void writeNBTBuffer(ref ubyte[] outbuf, ref ubyte[] otherbuf, const NBTRoot root, int type = 0) {
	void writeTo(ref ubyte[] buffer) {
		buffer.length = 0;
		(cast(byte) 10).writeBasic(buffer);
		root.name.writeBasicArray!short(buffer);
		root.tag.write(buffer);
	}

	import etc.c.zlib;

	if (type == 0) {
		writeTo(outbuf);
	} else if (type == 1 || type == 2) {
		writeTo(otherbuf);
		outbuf.length = outbuf.capacity; //ok right?
		if (outbuf.length == 0) {
			outbuf.length = 4096;
		}
		z_stream stream;
		auto bad = deflateInit2(&stream, 9, Z_DEFLATED, type == 1 ? 15 : 15 + 16,
			9, Z_DEFAULT_STRATEGY);
		if (bad != Z_OK) {
			throw new NBTException("Bad zlib");
		}

		stream.next_in = otherbuf.ptr;
		stream.avail_in = cast(uint) otherbuf.length;
		stream.next_out = outbuf.ptr;
		stream.avail_out = cast(uint) outbuf.length;
		void realloc() {
			size_t end = outbuf.length;
			outbuf.length = outbuf.length * 2;
			outbuf.length = outbuf.capacity; // ok?
			stream.next_out = &outbuf[end];
			stream.avail_out = cast(uint)(outbuf.length - end);
		}

		while (true) {
			auto result = deflate(&stream, Z_NO_FLUSH);
			if (stream.avail_in == 0) {
				if (stream.avail_out == 0) {
					realloc();
				}
				while (true) {
					result = deflate(&stream, Z_FINISH);
					if (result != Z_STREAM_END) {
						realloc();
						continue;
					}
					break;
				}
				break;
			} else if (stream.avail_out == 0) {
				realloc();
			} else {
				assert(0);
			}
		}
		outbuf.length = stream.total_out;
		deflateEnd(&stream);
		otherbuf.length = 0;
	} else {
		assert(0);
	}
}

struct NBTRoot {
	string name;
	Tag_Compound tag;
}

version (BigEndian) {
	static assert(0, "Nbt on big endian currently not supported");
}

alias TagTuple = TypeTuple!(Tag_Byte, Tag_Short, Tag_Int, Tag_Long, Tag_Float,
	Tag_Double, Tag_Byte_Array, Tag_String, Tag_List, Tag_Compound, Tag_Int_Array);

struct Tag_Byte {
	enum id = 1;
	byte data;
	alias data this;
	mixin BasicTag; //adds read and readArray
}

struct Tag_Short {
	enum id = 2;
	short data;
	alias data this;
	mixin BasicTag;
}

struct Tag_Int {
	enum id = 3;
	int data;
	alias data this;
	mixin BasicTag;
}

struct Tag_Long {
	enum id = 4;
	long data;
	alias data this;
	mixin BasicTag;
}

struct Tag_Float {
	enum id = 5;
	float data;
	alias data this;
	mixin BasicTag;
}

struct Tag_Double {
	enum id = 6;
	double data;
	alias data this;
	mixin BasicTag;
}

struct Tag_Byte_Array {
	enum id = 7;
	byte[] data;
	alias data this;
	static auto read(bool slice, F)(ref F file) {
		return typeof(this)(readBasicArray!(slice, byte)(file));
	}

	void write(F)(ref F file) const {
		data.writeBasicArray(file);
	}

	mixin ComplexTag; //adds readArray
	mixin BasicToString;
}

struct Tag_String {
	enum id = 8;
	char[] data;
	alias data this;
	static auto read(bool slice, F)(ref F file) {
		return typeof(this)(readBasicArray!(slice, char, short)(file));
	}

	void write(F)(ref F file) const {
		data.writeBasicArray!short(file);
	}

	mixin ComplexTag;
	mixin BasicToString;
}

struct Tag_List {
	enum id = 9;
	TaggedUnion!(staticMap!(ArrayOf, TagTuple)) data;
	alias data this;

	this(T)(T t) {
		data = t;
	}

	private template ArrayOf(T) {
		alias ArrayOf = T[];
	}

	static auto read(bool slice, F)(ref F file) {
		auto tid = readBasic!(byte)(file);
		if (tid == 0) {
			readBasic!int(file);
			return Tag_List.init;
		}
		foreach (Tag; TagTuple) {
			if (tid == Tag.id) {
				Tag_List result;
				result = Tag.readArray!slice(file);
				return result;
			}
		}
		throw NBTException.badID(tid);
	}

	void write(F)(ref F file) const {
		if (data.id == size_t.max) {
			(cast(byte) 0).writeBasic(file);
			(cast(int) 0).writeBasic(file);
		}
		foreach (c, Tag; TagTuple) {
			if (data.id == c) {
				(cast(byte) Tag.id).writeBasic(file);
				Tag.writeArray(data.getID!c, file);
			}
		}
	}

	mixin ComplexTag;
	string toString() const {
		foreach (c, Type; data.Types) {
			if (data.id == c) {
				return "Tag_List" ~ (data.getID!c).to!string;
			}
		}
		return "Tag_List[]";
	}
}

struct Tag_Compound {
	enum id = 10;
	TaggedUnion!(TagTuple)[string] data;
	alias data this;

	static auto read(bool slice, F)(ref F file) {
		Tag_Compound result;

		upper: while (true) {
			auto tid = readBasic!(byte)(file);
			if (tid == 0) {
				return result;
			}
			foreach (Tag; TagTuple) {
				if (tid == Tag.id) {
					auto name = cast(string) readBasicArray!(slice, char, short)(file);
					if (name in result.data) {
						throw new NBTException("Duplicate tag name in compound " ~ name);
					}
					result.data[name] = Tag.read!slice(file);
					continue upper;
				}
			}
			throw NBTException.badID(tid);
		}
		assert(0);
	}

	void write(F)(ref F file) const {
		foreach (name, tag; data) {
			foreach (c, Tag; TagTuple) {
				if (tag.id == c) {
					(cast(byte) Tag.id).writeBasic(file);
					name.writeBasicArray!short(file);
					(tag.getID!c).write(file);
				}
			}
		}
		(cast(byte) 0).writeBasic(file);
	}

	mixin ComplexTag;
	string toString() const {
		static int indent; //thread local
		string getIndent() {
			string indention;
			foreach (i; 0 .. indent) {
				indention ~= "\t";
			}
			return indention;
		}

		string result;
		result ~= "\n" ~ getIndent() ~ "{\n";

		indent++;

		auto names = sort(data.keys).array;
		foreach (index, name; names) {
			auto tag = data[name];
			foreach (c, Type; TagTuple) {
				if (tag.id == c) {
					result ~= getIndent() ~ '"' ~ name ~ '"' ~ ":" ~ (tag.getID!c).to!string ~ (
						index == names.length - 1 ? "" : ",\n");
				}
			}
		}
		indent--;
		return result ~ "\n" ~ getIndent() ~ "}";
	}
}

struct Tag_Int_Array {
	enum id = 11;
	int[] data;
	alias data this;

	static auto read(bool slice, F)(ref F file) {
		return typeof(this)(readBasicArray!(slice, int)(file));
	}

	void write(F)(ref F file) const {
		data.writeBasicArray(file);
	}

	mixin ComplexTag;
	mixin BasicToString;
}

//big endian readers

private auto readBasic(T, F)(ref F file) {
	import std.stdio;

	ubyte[T.sizeof] store;
	if (file.length < store.length) {
		throw NBTException.eof(T.stringof);
	}
	store[] = file[0 .. store.length];
	file = file[store.length .. $];
	reverse(store[]);
	return *cast(T*) store;
}

private auto readBasicArray(bool slice, T, IntType = int, F)(ref F file) {
	T[] result;
	auto length = readBasic!(IntType)(file);
	if (file.length < length * T.sizeof) {
		throw NBTException.eof("Array of length " ~ length.to!string ~ " of " ~ T.stringof);
	}
	static if (slice) {
		result = cast(T[])(file[0 .. length * T.sizeof]);
		static assert(hasAssignableElements!F);
	} else {
		result = new T[length];
		result[] = cast(T[])(file[0 .. length * T.sizeof]);
	}
	file = file[length * T.sizeof .. $];
	foreach (ref val; result) {
		reverse(cast(ubyte[])((&val)[0 .. 1]));
	}
	return result;
}

private auto readComplexArray(bool slice, T, IntType = int, F)(ref F file) {
	T[] result;
	auto length = readBasic!(IntType)(file);
	result = new T[length];
	foreach (ref val; result) {
		val = T.read!slice(file);
	}
	return result;
}

private auto writeBasic(T, F)(const T data, ref F file) {
	ubyte[data.sizeof] store;
	store[] = cast(ubyte[])(&data)[0 .. 1];
	reverse(store[]);
	file ~= store[];
}

private auto writeBasicArray(IntType = int, T, F)(const T[] data, ref F file) {
	(cast(IntType) data.length).writeBasic(file);
	file ~= cast(ubyte[]) data;
	foreach (ref elm; cast(T[])(file[$ - data.length * T.sizeof .. $])) {
		reverse(cast(ubyte[])((&elm)[0 .. 1]));
	}
}

private void writeComplexArray(IntType = int, T, F)(const T[] data, ref F file) {
	(cast(IntType) data.length).writeBasic(file);
	foreach (d; data) {
		d.write(file);
	}
}

mixin template BasicTag() {
	static auto read(bool slice, F)(ref F file) {
		return typeof(this)(readBasic!(typeof(data))(file));
	}

	static auto readArray(bool slice, F)(ref F file) {
		return cast(typeof(this)[])(readBasicArray!(slice, typeof(data))(file));
	}

	void write(F)(ref F file) const {
		data.writeBasic(file);
	}

	static void writeArray(F)(const typeof(this)[] self, ref F file) {
		self.writeBasicArray(file);
	}

	mixin BasicToString;
}

mixin template BasicToString() {
	string toString() const {
		return (typeof(this)).stringof ~ "(" ~ data.to!string ~ ")";
	}
}

mixin template ComplexTag() {
	static auto readArray(bool slice, F)(ref F file) {
		return readComplexArray!(slice, typeof(this))(file);
	}

	static void writeArray(F)(const typeof(this)[] self, ref F file) {
		self.writeComplexArray(file);
	}
}

class NBTException : Exception {
	this(string msg) {
		super(msg);
	}

	static auto eof(string msg) {
		return new NBTException("End of file while reading " ~ msg);
	}

	static auto badID(byte id) {
		return new NBTException("Unknown Tag ID of " ~ id.to!string);
	}
}
