/+
	This file is part of Superstar64's World Generator.

	Superstar64's World Generator is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	Superstar64's World Generator is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Superstar64's World Generator.  If not, see <http://www.gnu.org/licenses/>.
+/
module level;
import nbt;
import std.algorithm;
import std.bitmanip;
import blockdata;
import std.traits;
import std.typetuple;
import std.conv;
import std.stdio : writef, writeln, stdout;
import std.math;
import std.mmfile;
import core.memory;

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

private byte[256] nullBiomes;

private struct Chunk {
	bool[16] init;
	byte[16 * 16 * 16][16] ids;
	byte[16 * 16 * 16 / 2][16] meta;
	byte[16 * 16 * 16 / 2][16] bLight;
	byte[16 * 16 * 16 / 2][16] sLight;
	int[16 * 16] heightMap;

	ubyte[] save(int cx, int cz, ref ChunkMeta chmeta, ref ubyte[] buffer1, ref ubyte[] buffer2) {
		with (chmeta) {
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
					foreach (c, sec; init) {
						if (sec) {
							Tag_Compound section;
							section["Y"] = Tag_Byte(cast(byte) c);
							section["Blocks"] = Tag_Byte_Array(ids[c]);
							section["Data"] = Tag_Byte_Array(meta[c]);
							section["BlockLight"] = Tag_Byte_Array(bLight[c]);
							section["SkyLight"] = Tag_Byte_Array(sLight[c]);
							sections ~= section;
						}
					}
					level["Sections"] = Tag_List(sections);
					level["Entities"] = Tag_List(entites);
					Tag_Compound[] tileEntities;
					foreach (t; tileTicks) {
						Tag_Compound tile;
						tile["i"] = Tag_String(BlockIDToName[getBlockID(t.x & 0xf,
							t.y, t.z & 0xf)].dup);
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
			writeNBTBuffer(buffer1, buffer2, root, 1);
			return buffer1;
		}
	}

	auto getOff(uint x, uint y, uint z) {
		return x + z * 16 + (y % 16) * 16 * 16;
	}

	ubyte getBlockID(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			return 0;
		}
		return ids[sec][getOff(x, y, z)];
	}

	ubyte getMeta(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			return 0;
		}
		auto off = meta[sec][getOff(x, y, z) / 2];
		if (x % 2 == 0) {
			return off & 0xf;
		} else {
			return (off & 0xf0) >> 4;
		}
	}

	ubyte getBLight(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			return 0;
		}
		auto off = bLight[sec][getOff(x, y, z) / 2];
		if (x % 2 == 0) {
			return off & 0xf;
		} else {
			return (off & 0xf0) >> 4;
		}
	}

	ubyte getSLight(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			return 0;
		}
		auto off = sLight[sec][getOff(x, y, z) / 2];
		if (x % 2 == 0) {
			return off & 0xf;
		} else {
			return (off & 0xf0) >> 4;
		}
	}

	void setBlockID(uint x, uint y, uint z, ubyte id) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			init[sec] = true;
		}
		ids[sec][getOff(x, y, z)] = id;
	}

	void setMeta(uint x, uint y, uint z, ubyte data) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		assert(data < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			init[sec] = true;
		}
		auto off = meta[sec][getOff(x, y, z) / 2];
		if (x % 2 == 0) {
			meta[sec][getOff(x, y, z) / 2] = cast(byte)((off & 0xf0) | data);
		} else {
			meta[sec][getOff(x, y, z) / 2] = cast(byte)((off & 0xf) | (data << 4));
		}
	}

	void setBLight(uint x, uint y, uint z, ubyte data) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		assert(data < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			init[sec] = true;
		}
		auto off = bLight[sec][getOff(x, y, z) / 2];
		if (x % 2 == 0) {
			bLight[sec][getOff(x, y, z) / 2] = cast(byte)((off & 0xf0) | data);
		} else {
			bLight[sec][getOff(x, y, z) / 2] = cast(byte)((off & 0xf) | (data << 4));
		}
	}

	void setSLight(uint x, uint y, uint z, ubyte data) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		assert(data < 16);
		size_t sec = y / 16;
		if (!init[sec]) {
			init[sec] = true;
		}
		auto off = sLight[sec][getOff(x, y, z) / 2];
		if (x % 2 == 0) {
			sLight[sec][getOff(x, y, z) / 2] = cast(byte)((off & 0xf0) | data);
		} else {
			sLight[sec][getOff(x, y, z) / 2] = cast(byte)((off & 0xf) | (data << 4));
		}
	}

	ref int getHeight(uint x, uint z) {
		return heightMap[x + z * 16];
	}

	bool ysection(uint y) {
		assert(y < 256);
		return init[y / 16];
	}
}

private struct ChunkMeta { //data oriented programming
	Tag_Compound[] entites;
	LevelPos[] tileTicks;
}

class Level {
	private Chunk[] chunks;
	private ChunkMeta[] chunkMetas;
	private MmFile mmfile;
	int size;
	this(int levelSize, string tempFile) {
		size = levelSize;
		auto chSize = chunkLen * chunkLen * 4;
		if (tempFile is null) {
			chunks = new Chunk[chSize];
			chunkMetas = new ChunkMeta[chSize];
		} else {
			mmfile = new MmFile(tempFile, MmFile.Mode.readWriteNew,
				chSize * Chunk.sizeof + chSize * ChunkMeta.sizeof, null);
			auto data = cast(ubyte[]) mmfile[];
			chunks = cast(Chunk[])(data[0 .. chSize * Chunk.sizeof]);
			chunkMetas = cast(ChunkMeta[])(data[chSize * Chunk.sizeof .. $]);
			GC.addRange(chunkMetas.ptr, chunkMetas.length * ChunkMeta.sizeof, typeid(ChunkMeta));
		}
	}

	Block opIndex(LevelPos pos) {
		return opIndex(pos.x, pos.y, pos.z);
	}

	Block opIndexAssign(Block b, LevelPos pos) {
		return opIndexAssign(b, pos.x, pos.y, pos.z);
	}

	Block opIndex(int x, int y, int z) {
		return Block(getBlockID(x, y, z), getMeta(x, y, z));
	}

	Block opIndexAssign(Block b, int x, int y, int z) {
		setBlockID(x, y, z, b.id);
		setMeta(x, y, z, b.meta);
		return b;
	}

	void setEntity(const Tag_Compound e, int x, int y, int z) {
		auto pos = Pos(x >> 4, z >> 4);
		if (!exists2(x, z)) {
			return;
		}
		Tag_Compound clone;
		foreach (k, v; e) {
			clone[k] = v;
		}
		clone["Pos"] = Tag_List([Tag_Double(x), Tag_Double(y), Tag_Double(z)]);
		getChunkMeta(pos).entites ~= clone;
	}

	bool exists(int x, int y, int z) {
		assert(y >= 0 && y < 256);
		auto pos = Pos(x >> 4, z >> 4);
		return exists2(x, z) && getChunk(pos).ysection(y);
	}

	void setEntity(const Tag_Compound e, LevelPos pos) {
		setEntity(e, pos.x, pos.y, pos.z);
	}

	void calculateLightandWater(bool print) {
		foreach (c, pos, ref chunk; this) {
			if (print) {
				writef("Calcutaing light and water for chunk(%#5s,%#5s) %s%%\r",
					pos.x, pos.z, c * 100 / length);
				stdout.flush;
			}
			calutateWater(this, chunk, pos.x, pos.z);
			calcBlockLight(this, chunk, pos.x, pos.z);
			calcSkyLight1(this, chunk);
			calcSkyLight2(this, chunk, pos.x, pos.z);
		}
		if (print) {
			writeln();
		}
	}

private:

	int chunkLen() {
		return (size + (16 - 1)) / 16;
	}

	size_t off(Pos p) {
		return p.x + chunkLen + 2 * chunkLen * (p.z + chunkLen);
	}

	ref Chunk getChunk(Pos p) {
		return chunks[off(p)];
	}

	ref ChunkMeta getChunkMeta(Pos p) {
		return chunkMetas[off(p)];
	}

	int opApply(int delegate(size_t, Pos, ref Chunk) fn) {
		int ret;
		size_t c;
		foreach (x; -chunkLen .. chunkLen) {
			foreach (z; -chunkLen .. chunkLen) {
				auto pos = Pos(x, z);
				ret = fn(c, pos, getChunk(pos));
				if (ret) {
					return ret;
				}
				c++;
			}
		}
		return ret;
	}

	int opApply(int delegate(size_t, Pos, ref Chunk, ref ChunkMeta) fn) {
		int ret;
		size_t c;
		foreach (x; -chunkLen .. chunkLen) {
			foreach (z; -chunkLen .. chunkLen) {
				auto pos = Pos(x, z);
				ret = fn(c, pos, getChunk(pos), getChunkMeta(pos));
				if (ret) {
					return ret;
				}
				c++;
			}
		}
		return ret;
	}

	auto length() {
		auto ret = chunkLen * chunkLen * 4;
		assert(chunks.length == ret);
		return ret;
	}

	void addTileTick(int x, int y, int z) {
		auto pos = Pos(x >> 4, z >> 4);
		if (!exists2(x, z)) {
			return;
		}
		getChunkMeta(pos).tileTicks ~= LevelPos(x, y, z);
	}

	ref int height(int x, int z) {
		auto pos = Pos(x >> 4, z >> 4);
		assert(exists2(x, z));
		return getChunk(pos).getHeight(x & 15, z & 15);
	}

	bool exists2(int x, int z) {
		return abs(x) < size && abs(z) < size;
	}

	ubyte getBlockID(int x, uint y, int z) {
		assert(y < 256);
		if (!exists2(x, z)) {
			return 0;
		}
		return getChunk(Pos(x >> 4, z >> 4)).getBlockID(x & 0xf, y, z & 0xf);
	}

	ubyte getMeta(int x, int y, int z)
	out(result) {
		assert(result < 16);
	}
	body {
		assert(y < 256);
		if (!exists2(x, z)) {
			return 0;
		}
		return getChunk(Pos(x >> 4, z >> 4)).getMeta(x & 0xf, y, z & 0xf);
	}

	ubyte getBLight(int x, uint y, int z)
	out(result) {
		assert(result < 16);
	}
	body {
		assert(y < 256);
		if (!exists2(x, z)) {
			return 0;
		}
		return getChunk(Pos(x >> 4, z >> 4)).getBLight(x & 0xf, y, z & 0xf);
	}

	ubyte getSLight(int x, uint y, int z)
	out(result) {
		assert(result < 16);
	}
	body {
		assert(y < 256);
		if (!exists2(x, z)) {
			return 0;
		}
		return getChunk(Pos(x >> 4, z >> 4)).getSLight(x & 0xf, y, z & 0xf);
	}

	void setBlockID(int x, uint y, int z, ubyte id) {
		assert(y < 256);
		auto pos = Pos(x >> 4, z >> 4);
		if (!exists2(x, z)) {
			return;
		}
		return getChunk(pos).setBlockID(x & 0xf, y, z & 0xf, id);
	}

	void setMeta(int x, uint y, int z, ubyte data) {
		assert(y < 256);
		assert(data < 16);
		auto pos = Pos(x >> 4, z >> 4);
		if (!exists2(x, z)) {
			return;
		}
		return getChunk(pos).setMeta(x & 0xf, y, z & 0xf, data);
	}

	void setBLight(int x, uint y, int z, ubyte data) {
		assert(y < 256);
		assert(data < 16);
		auto pos = Pos(x >> 4, z >> 4);
		if (!exists2(x, z)) {
			return;
		}
		return getChunk(pos).setBLight(x & 0xf, y, z & 0xf, data);
	}

	void setSLight(int x, uint y, int z, ubyte data) {
		assert(y < 256);
		assert(data < 16);
		auto pos = Pos(x >> 4, z >> 4);
		if (!exists2(x, z)) {
			return;
		}
		return getChunk(pos).setSLight(x & 0xf, y, z & 0xf, data);
	}

}

void save(Level lev, string regionPath, bool verbose) {
	Region[Pos] regions;
	foreach (c, pos, ref chunk, ref chunkMeta; lev) {

		auto regPos = pos;
		regPos.x >>= 5;
		regPos.z >>= 5;
		if (!(regPos in regions)) {
			regions[regPos] = Region();
		}
		regions[regPos].chunkAt(pos) = &chunk;
		regions[regPos].chunkMetaAt(pos) = &chunkMeta;
	}
	size_t percent;
	ubyte[] nbtbuf1;
	ubyte[] nbtbuf2;
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
				auto data = chunk.save(chunkx, chunky,
					*region.chunkMetaAt(Pos(chunkx, chunky)), nbtbuf1, nbtbuf2);
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

struct Region {
	Chunk*[32 * 32] chunks;
	ChunkMeta*[32 * 32] chunkMetas;
	auto ref chunkAt(Pos chunkPos) {
		return chunks[(chunkPos.x & 31) + (chunkPos.z & 31) * 32];
	}

	auto ref chunkMetaAt(Pos chunkPos) {
		return chunkMetas[(chunkPos.x & 31) + (chunkPos.z & 31) * 32];
	}

}

void calcBlockLight(Level lev, ref Chunk chunk, int offx, int offz) {
	void spreadStart(int x, int y, int z) {
		if (chunk.ysection(y)) {
			ubyte light = lev.getBlockID(x, y, z).getLight;
			if (light > 0) {
				spread!((x, y, z) => lev.getBLight(x, y, z), (x, y, z,
					l) => lev.setBLight(x, y, z, l))(lev, light, x, y, z);
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
				if (chunk.ysection(y)) {
					auto type = chunk.getBlockID(cx, y, cz).getTrans;
					if (type != Transparent.Full) {
						break;
					}
					chunk.setSLight(cx, y, cz, 15);
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
				spread!((x, y, z) => lev.getSLight(x, y, z), (x, y, z,
					l) => lev.setSLight(x, y, z, l))(lev, 14, x - 1, y, z);
				spread!((x, y, z) => lev.getSLight(x, y, z), (x, y, z,
					l) => lev.setSLight(x, y, z, l))(lev, 14, x + 1, y, z);
				spread!((x, y, z) => lev.getSLight(x, y, z), (x, y, z,
					l) => lev.setSLight(x, y, z, l))(lev, 14, x, y, z - 1);
				spread!((x, y, z) => lev.getSLight(x, y, z), (x, y, z,
					l) => lev.setSLight(x, y, z, l))(lev, 14, x, y, z + 1);
			}
			if (height > 0) {
				spread!((x, y, z) => lev.getSLight(x, y, z), (x, y, z,
					l) => lev.setSLight(x, y, z, l))(lev, 14, x, height - 1, z);
			}
		}
	}
}

void calutateWater(Level lev, ref Chunk chunk, int offx, int offz) {
	ubyte id;
	ubyte inc = 1;
	ubyte countMax = 8;

	void tryflood()(int x, int y, int z, ubyte count) {
		assert(count > 0);
		if (!lev.exists(x, y, z)) {
			return;
		}
		if (lev.getBlockID(x, y, z) != Blocks.air.id && !(lev.getBlockID(x, y,
				z) == id && lev.getMeta(x, y, z) > count)) {
			return;
		}
		flood(x, y, z, count);
	}

	void flood(int x, int y, int z, ubyte count) {
		if (count >= countMax) {
			return;
		}

		lev.setBlockID(x, y, z, id);
		lev.setMeta(x, y, z, count);

		if (y > 0 && lev.getBlockID(x, y - 1, z) == id && lev.getMeta(x, y - 1, z) > 0) {
			return;
		}
		if (y > 0 && lev.getBlockID(x, y - 1, z) == Blocks.air.id) {
			y -= 1;
			while (y > 0 && lev.getBlockID(x, y, z) == Blocks.air.id) {
				lev.setBlockID(x, y, z, id);
				lev.setMeta(x, y, z, cast(ubyte)(count + 8));
				y--;
			}
			if (y == 0 || lev.getBlockID(x, y, z) == id) {
				return;
			}
			y += 1;
			assert(lev.getBlockID(x, y, z) == id);
			count = 0;
		}
		tryflood(x + 1, y, z, cast(ubyte)(count + inc));
		tryflood(x - 1, y, z, cast(ubyte)(count + inc));
		tryflood(x, y, z + 1, cast(ubyte)(count + inc));
		tryflood(x, y, z - 1, cast(ubyte)(count + inc));

	}

	void calcWater(int x, int y, int z) {
		if (lev.getBlockID(x, y, z) == Blocks.water.id && lev.getMeta(x, y, z) == 0) {
			id = Blocks.water.id;
			inc = 1;
			flood(x, y, z, 0);
		}
		if (lev.getBlockID(x, y, z) == Blocks.lava.id && lev.getMeta(x, y, z) == 0) {
			id = Blocks.lava.id;
			inc = 2;
			flood(x, y, z, 0);
		}
	}

	foreach (y; 0 .. 256) {
		foreach (cz; 0 .. 16) {
			foreach (cx; 0 .. 16) {
				calcWater(cx + offx * 16, y, cz + offz * 16);
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
		if (lightGet(x, y, z) < light) {
			lightSet(x, y, z, light);
		} else {
			return;
		}
		assert(light >= lightGet(x, y, z));
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
