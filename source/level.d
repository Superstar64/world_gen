import nbt;
import std.algorithm;
import std.bitmanip;
import blockdata;
import std.traits;
import std.typetuple;
import std.conv;
import std.stdio : writef, writeln, stdout;

struct Block {
	ubyte id;
	ubyte meta;
}

struct LevelPos {
	int x;
	int y;
	int z;
}

private struct Pos {
	int x;
	int z;
}

private struct ChunkInteral{
	byte[16 * 16 * 16] ids;
	byte[16 * 16 * 16 / 2] data;
	byte[16 * 16 * 16 / 2] bLight;
	byte[16 * 16 * 16 / 2] sLight;
}
private byte[256] nullBiomes;

private struct Chunk {
	ChunkInteral*[16] parts;
	int[16 * 16] heightMap;
	Tag_Compound[] entites;
	LevelPos[] tileTicks;

	ubyte[] save(int cx, int cz) {
		ubyte[] buffer;
		NBTRoot root;
		{
			Tag_Compound level;
			{
				level["xPos"] = Tag_Int(cx);
				level["zPos"] = Tag_Int(cz);
				level["LastUpdate"] = Tag_Long(1);
				level["LightPopulated"] = Tag_Byte(1);
				level["TerrainPopulated"] = Tag_Byte(1);
				level["V"] = Tag_Byte(1);
				level["InhabitedTime"] = Tag_Long(1);
				level["Biomes"] = Tag_Byte_Array(nullBiomes);
				level["HeightMap"] = Tag_Int_Array(heightMap[]);
				Tag_Compound[] sections;
				foreach(c,sec;parts){
					if(sec){
						Tag_Compound section;
						section["Y"] = Tag_Byte(cast(byte) c);
						section["Blocks"] = Tag_Byte_Array(sec.ids);
						section["Data"] = Tag_Byte_Array(sec.data);
						section["BlockLight"] = Tag_Byte_Array(sec.bLight);
						section["SkyLight"] = Tag_Byte_Array(sec.sLight);
						sections ~= section;
					}
				}
				level["Sections"] = Tag_List(sections);
				level["Entities"] = Tag_List(entites);
				Tag_Compound[] tileEntities;
				foreach (t; tileTicks) {
					Tag_Compound tile;
					tile["i"] = Tag_String(BlockIDToName[getBlockID(t.x & 0xf,t.y,t.z & 0xf)].dup);
					tile["t"] = Tag_Int(0);
					tile["p"] = Tag_Int(0);
					tile["x"] = Tag_Int(t.x);
					tile["y"] = Tag_Int(t.y);
					tile["z"] = Tag_Int(t.z);
					tileEntities ~= tile;
				}
				level["TileEntities"] = Tag_List(tileEntities);
			}
			root.tag["Level"] = level;
		}
		writeNBTBuffer(buffer, root, 1);
		return buffer;
	}
	
	auto getOff(uint x,uint y,uint z){
		return x + z * 16 + (y % 16) * 16 * 16;
	}
	
	ubyte getBlockID(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			return 0;
		}
		return parts[sec].ids[getOff(x,y,z)];
	}
	
	ubyte getMeta(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			return 0;
		}
		auto off = parts[sec].data[getOff(x,y,z)/2];
		if(x % 2 ==0){
			return off & 0xf;
		}else{
			return (off & 0xf0) >> 4;
		}
	}
	
	ubyte getBLight(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			return 0;
		}
		auto off = parts[sec].bLight[getOff(x,y,z)/2];
		if(x % 2 ==0){
			return off & 0xf;
		}else{
			return (off & 0xf0) >> 4;
		}
	}
	
	ubyte getSLight(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			return 0;
		}
		auto off = parts[sec].sLight[getOff(x,y,z)/2];
		if(x % 2 ==0){
			return off & 0xf;
		}else{
			return (off & 0xf0) >> 4;
		}
	}
	
	void setBlockID(uint x, uint y, uint z,ubyte id) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			parts[sec] = new ChunkInteral;
		}
		parts[sec].ids[getOff(x,y,z)] = id;
	}
	
	void setMeta(uint x, uint y, uint z,ubyte data) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		assert(data < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			parts[sec] = new ChunkInteral;
		}
		auto off = parts[sec].data[getOff(x,y,z)/2];
		if(x % 2 ==0){
			parts[sec].data[getOff(x,y,z)/2] = cast(byte)((off & 0xf0) | data);
		}else{
			parts[sec].data[getOff(x,y,z)/2] = cast(byte)((off & 0xf) | (data << 4));
		}
	}
	
	void setBLight(uint x, uint y, uint z,ubyte data) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		assert(data < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			parts[sec] = new ChunkInteral;
		}
		auto off = parts[sec].bLight[getOff(x,y,z)/2];
		if(x % 2 ==0){
			parts[sec].bLight[getOff(x,y,z)/2] = cast(byte)((off & 0xf0) | data);
		}else{
			parts[sec].bLight[getOff(x,y,z)/2] = cast(byte)((off & 0xf) | (data << 4));
		}
	}
	
	void setSLight(uint x, uint y, uint z,ubyte data) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		assert(data < 16);
		size_t sec = y/16;
		if(!parts[sec]){
			parts[sec] = new ChunkInteral;
		}
		auto off = parts[sec].sLight[getOff(x,y,z)/2];
		if(x % 2 ==0){
			parts[sec].sLight[getOff(x,y,z)/2] = cast(byte)((off & 0xf0) | data);
		}else{
			parts[sec].sLight[getOff(x,y,z)/2] = cast(byte)((off & 0xf) | (data << 4));
		}
	}

	ref int getHeight(uint x, uint z) {
		return heightMap[x + z * 16];
	}
	
	bool ysection(uint y){
		assert(y < 256);
		return parts[y / 16] !is null;
	}
}

class Level {
	private Chunk[Pos] chunks;

	Block opIndex(LevelPos pos) {
		return opIndex(pos.x, pos.y, pos.z);
	}

	Block opIndexAssign(Block b, LevelPos pos) {
		return opIndexAssign(b, pos.x, pos.y, pos.z);
	}

	Block opIndex(int x, int y, int z) {
		return Block(getBlockID(x,y,z),getMeta(x,y,z));
	}

	Block opIndexAssign(Block b, int x, int y, int z) {
		setBlockID(x,y,z,b.id);
		setMeta(x,y,z,b.meta);
		return b;
	}

	void setEntity(Tag_Compound e, int x, int y, int z) {
		tryCreateChunk(Pos(x >> 4, z >> 4));
		auto pos = Pos(x >> 4, z >> 4);
		chunks[pos].entites ~= e;
	}

	bool exists(int x, int y, int z) {
		assert(y >= 0 && y < 256);
		auto pos = Pos(x >> 4, z >> 4);
		return !!(pos in chunks) && chunks[pos].ysection(y);
	}

	void setEntity(Tag_Compound e, LevelPos pos) {
		setEntity(e, pos.x, pos.y, pos.z);
	}

	void calculateLightandWater(bool print) {
		auto list = genChunkList();
		
		foreach (c, chunkElm; list) {
			auto pos = chunkElm.pos;
			if (print) {
				writef("Calcutaing light and water for chunk(%#5s,%#5s) %s%%\r",
					pos.x, pos.z, c * 100 / list.length);
				stdout.flush;
			}
			calcBlockLight(this, *chunkElm.chunk, pos.x, pos.z);
			calcSkyLight1(this, *chunkElm.chunk);
			calcSkyLight2(this, *chunkElm.chunk, pos.x, pos.z);
			tileTickWater(this, *chunkElm.chunk, pos.x, pos.z);
		}
		if (print) {
			writeln();
		}
	}

private:

   auto genChunkList() {
		ChunkElm[] list;
		foreach (pos, ref chunk; chunks) {
		   list ~= ChunkElm(pos, &chunk);
		}
		list.sort!("a.chunk < b.chunk"); //yes, compare the pointers
		return list;
    }


	void addTileTick(int x, int y, int z) {
		assert(exists(x, y, z));
		auto pos = Pos(x >> 4, z >> 4);
		tryCreateChunk(pos);
		chunks[pos].tileTicks ~= LevelPos(x, y, z);
	}

	void createChunk(Pos pos) {
		chunks[pos] = Chunk();
	}

	void tryCreateChunk(Pos pos) {
		if (!(pos in chunks)) {
			createChunk(pos);
		}
	}

	ref int height(int x, int z) {
		auto pos = Pos(x >> 4, z >> 4);
		assert(pos in chunks);
		return chunks[pos].getHeight(x & 15, z & 15);
	}

	bool exists2(int x, int z) {
		auto pos = Pos(x >> 4, z >> 4);
		return !!(pos in chunks);
	}
	
	ubyte getBlockID(int x, uint y, int z) {
		assert(y < 256);
		if(!exists2(x,z)){
			return 0;
		}
		return chunks[Pos(x>>4,z>>4)].getBlockID(x & 0xf, y , z & 0xf);
	}
	
	ubyte getMeta(int x, int y, int z) out(result){assert(result < 16);}
	body {
		assert(y < 256);
		if(!exists2(x,z)){
			return 0;
		}
		return chunks[Pos(x>>4,z>>4)].getMeta(x & 0xf, y , z & 0xf);
	}
	
	ubyte getBLight(int x, uint y, int z) out(result){assert(result < 16);}
	body{
		assert(y < 256);
		if(!exists2(x,z)){
			return 0;
		}
		return chunks[Pos(x>>4,z>>4)].getBLight(x & 0xf, y , z & 0xf);
	}
	
	ubyte getSLight(int x, uint y, int z) out(result){assert(result < 16);}
	body{
		assert(y < 256);
		if(!exists2(x,z)){
			return 0;
		}
		return chunks[Pos(x>>4,z>>4)].getSLight(x & 0xf, y , z & 0xf);
	}
	
	void setBlockID(int x, uint y, int z,ubyte id) {
		assert(y < 256);
		auto pos = Pos(x>>4,z>>4);
		tryCreateChunk(pos);
		return chunks[pos].setBlockID(x & 0xf, y , z & 0xf,id);
	}
	
	void setMeta(int x, uint y, int z,ubyte data) {
		assert(y < 256);
		assert(data < 16);
		auto pos = Pos(x>>4,z>>4);
		tryCreateChunk(pos);
		return chunks[pos].setMeta(x & 0xf, y , z & 0xf,data);
	}
	
	void setBLight(int x, uint y, int z,ubyte data) {
		assert(y < 256);
		assert(data < 16);
		auto pos = Pos(x>>4,z>>4);
		tryCreateChunk(pos);
		return chunks[pos].setBLight(x & 0xf, y , z & 0xf,data);
	}
	
	void setSLight(int x, uint y, int z,ubyte data) {
		assert(y < 256);
		assert(data < 16);
		auto pos = Pos(x>>4,z>>4);
		tryCreateChunk(pos);
		return chunks[pos].setSLight(x & 0xf, y , z & 0xf,data);
	}
	
}

void save(Level lev, string regionPath, bool verbose) {
	Region[Pos] regions;
	foreach (pos, ref chunk; lev.chunks) {

		auto regPos = pos;
		regPos.x >>= 5;
		regPos.z >>= 5;
		if (!(regPos in regions)) {
			regions[regPos] = Region();
		}
		regions[regPos].chunkAt(pos) = &chunk;
	}
	size_t percent;
	foreach (pos, region; regions) {
		ubyte[] file = new ubyte[8192];
		uint offsetCount = 2;
		foreach (count, chunk; region.chunks) {
			if (chunk !is null) {
				auto chunkx = (pos.x << 5) + (cast(int) count) % 32;
				auto chunky = (pos.z << 5) + (cast(int) count) / 32;
				if (verbose) {
					writef("Saving chunk(%#5s,%#5s) at region(%#5s,%#5s) %s%%\r",
						chunkx, chunky, pos.x, pos.z, percent * 100 / regions.length);
					stdout.flush();
				}
				auto data = chunk.save(chunkx, chunky);
				ubyte[int.sizeof] store;
				*(cast(int*) store.ptr) = cast(int)(data.length + 1);
				reverse(store[]);
				file ~= store[];
				file ~= 2;
				file ~= data;

				auto len = data.length + 5;
				auto pad = 4096 - len % 4096;
				file.length = file.length + pad;
				assert(file.length % 4096 == 0);
				assert((len + pad) % 4096 == 0);
				auto sectSize = (len + pad) / 4096;

				ubyte[4] chunkLoc;
				chunkLoc[2] = cast(ubyte)(offsetCount & 0xff);
				chunkLoc[1] = cast(ubyte)((offsetCount >> 8) & 0xff);
				chunkLoc[0] = cast(ubyte)((offsetCount >> 16) & 0xff);
				chunkLoc[3] = cast(ubyte) sectSize;

				ubyte[4]* chunkSect = cast(ubyte[4]*)(&file[4 * count]);
				*chunkSect = chunkLoc;
				offsetCount += sectSize;
			}
		}
		import std.file;
		import std.path;
		import std.conv;

		write(buildPath(regionPath, "r." ~ pos.x.to!string ~ "." ~ pos.z.to!string ~ ".mca"),
			file);
		percent++;
	}
	if (verbose) {
		writeln();
	}
}

private:

static struct ChunkElm {
    Pos pos;
    Chunk* chunk;
}


struct Region {
	Chunk*[32 * 32] chunks;

	auto ref chunkAt(Pos chunkPos) {
		return chunks[(chunkPos.x & 31) + (chunkPos.z & 31) * 32];
	}
}

void calcBlockLight(Level lev, ref Chunk chunk, int offx, int offz) {
	void spreadStart(int x, int y, int z) {
		if(chunk.ysection(y)){
			ubyte light = lev.getBlockID(x,y,z).getLight;
			if (light > 0) {
				spread!((x,y,z) => lev.getBLight(x,y,z),(x,y,z,l) => lev.setBLight(x,y,z,l))(lev, light,
					x, y, z);
			}
		}
	}

	foreach (y; 0 .. 256) {
		foreach (cz; 0 .. 16) {
			foreach (cx; 0 .. 16) {	
				spreadStart(cx + offx * 16, y, cz + offz * 16);
			}
		}
	}
}

void calcSkyLight1(Level lev, ref Chunk chunk) {
	foreach (cz; 0 .. 16) {
		foreach (cx; 0 .. 16) {
			foreach_reverse (y; 0 .. 256) {
				if(chunk.ysection(y)){
					auto type = chunk.getBlockID(cx, y, cz).getTrans;
					if (type != Transparent.Full) {
						break;
					}
					chunk.setSLight(cx,y,cz,15);
					chunk.heightMap[cx + cz * 16] = y;
				}
			}
		}
	}
}

void calcSkyLight2(Level lev, ref Chunk chunk, int offx, int offz) {
	foreach (int cz; 0 .. 16) {
		foreach (int cx; 0 .. 16) {
			int x = cx + offx * 16;
			int z = cz + offz * 16;
			auto height = chunk.getHeight(cx, cz);
			auto maxHeight = height;
			void scan(int xP, int zP) {
				int scanHeight;
				if (lev.exists2(x + xP, z + zP)) {
					scanHeight = lev.height(x + xP, z + zP);
				}
				if (scanHeight > maxHeight) {
					maxHeight = scanHeight;
				}
			}

			scan(-1, 0);
			scan(1, 0);
			scan(0, -1);
			scan(0, 1);
			foreach (y; height .. maxHeight) {
				spread!((x,y,z) => lev.getSLight(x,y,z),(x,y,z,l) => lev.setSLight(x,y,z,l))(lev, 14, x - 1,
					y, z);
				spread!((x,y,z) => lev.getSLight(x,y,z),(x,y,z,l) => lev.setSLight(x,y,z,l))(lev, 14, x + 1,
					y, z);
				spread!((x,y,z) => lev.getSLight(x,y,z),(x,y,z,l) => lev.setSLight(x,y,z,l))(lev, 14, x,
					y, z - 1);
				spread!((x,y,z) => lev.getSLight(x,y,z),(x,y,z,l) => lev.setSLight(x,y,z,l))(lev, 14, x,
					y, z + 1);
			}
			if (height > 0) {
				spread!((x,y,z) => lev.getSLight(x,y,z),(x,y,z,l) => lev.setSLight(x,y,z,l))(lev, 14, x,
					height - 1, z);
			}
		}
	}
}

void tileTickWater(Level lev, ref Chunk chunk, int offx, int offz) {
	void tileWater(int x, int y, int z) {

		if (lev.getBlockID(x,y,z) == Blocks.water.id) {
			foreach (xI; TypeTuple!(-1, 1)) {
				foreach (zI; TypeTuple!(-1, 1)) {
					if (!lev.exists(x + xI, y, z + zI) || lev.getBlockID(x + xI, y, z + zI) == 0) {
						lev.setBlockID(x, y, z,Blocks.flowing_water.id);
						lev.addTileTick(x, y, z);
						return;
					}
				}
			}
		}
	}

	foreach (y; 0 .. 256) {
		foreach (cz; 0 .. 16) {
			foreach (cx; 0 .. 16) {
				tileWater(cx + offx * 16, y, cz + offz * 16);
			}
		}
	}
}

void spread(alias lightGet, alias lightSet)(Level lev, ubyte light, int x, int y, int z) {
	if (lev.exists(x, y, z)) {
		auto type = lev.getBlockID(x, y, z).getTrans;
		if (type == Transparent.None) {
			return;
		}
		if (type == Transparent.Water) {
			if (light <= 2) {
				return;
			}
			light -= 2;
		}
		if (lightGet(x,y,z) < light) {
			lightSet(x,y,z,light);
		}
		else {
			return;
		}
		assert(light >= lightGet(x,y,z));
		if (light <= 1) {
			return;
		}
		light -= 1;
		if (y > 0) {
			spread!(lightGet, lightSet)(lev, light, x, y - 1, z);
		}
		if (y < 255) {
			spread!(lightGet, lightSet)(lev, light, x, y + 1, z);
		}
		spread!(lightGet, lightSet)(lev, light, x + 1, y, z);
		spread!(lightGet, lightSet)(lev, light, x - 1, y, z);
		spread!(lightGet, lightSet)(lev, light, x, y, z + 1);
		spread!(lightGet, lightSet)(lev, light, x, y, z - 1);
	}
}
