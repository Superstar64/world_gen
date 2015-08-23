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

private struct InteralBlock {
	ubyte id;
	mixin(bitfields!(ubyte, "meta", 4, ubyte, "add", 4, ubyte, "blockLight",
		4, ubyte, "skyLight", 4));
	ubyte getLightFromID() {
		foreach (BData; EnumMembers!Blocks) {
			static if (BData.search) {
				if (id == BData.id) {
					return BData.light;
				}
			}
		}
		return 0;
	}

	Transparent getTransFromID() {
		foreach (BData; EnumMembers!Blocks) {
			static if (BData.search) {
				if (id == BData.id) {
					return BData.trans;
				}
			}
		}
		return Transparent.None;
	}
}

private struct Chunk {
	InteralBlock[256 * 16 * 16] blocks;
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
				level["Biomes"] = Tag_Byte_Array(new byte[256]);
				level["HeightMap"] = Tag_Int_Array(heightMap.dup);
				Tag_Compound[] sections;
				{
					foreach (i; 0 .. 16) {
						auto ids = new byte[16 * 16 * 16];
						auto meta = new byte[16 * 16 * 16 / 2];
						auto blockLight = new byte[16 * 16 * 16 / 2];
						auto skyLight = new byte[16 * 16 * 16 / 2];
						foreach (y; 0 .. 16) {
							foreach (z; 0 .. 16) {
								foreach (x; 0 .. 16) {
									auto block = getBlock(x, y + (16 * i), z);
									auto offset = x + z * 16 + y * 16 * 16;
									ids[offset] = block.id;
									offset /= 2;
									if (x % 2 == 0) {
										meta[offset] |= block.meta;
										blockLight[offset] |= block.blockLight;
										skyLight[offset] |= block.skyLight;
									}
									else {
										meta[offset] |= (block.meta << 4);
										blockLight[offset] |= (block.blockLight << 4);
										skyLight[offset] |= (block.skyLight << 4);
									}

								}
							}
						}
						foreach (id; ids) {
							if (id != 0) {
								Tag_Compound section;
								section["Y"] = Tag_Byte(cast(byte) i);
								section["Blocks"] = Tag_Byte_Array(ids);
								section["Data"] = Tag_Byte_Array(meta);
								section["BlockLight"] = Tag_Byte_Array(blockLight);
								section["SkyLight"] = Tag_Byte_Array(skyLight);
								sections ~= section;
								break;
							}
						}
						continue;
					}
				}
				level["Sections"] = Tag_List(sections);
				level["Entities"] = Tag_List(entites);
				Tag_Compound[] tileEntities;
				foreach (t; tileTicks) {
					auto block = getBlock(t.x & 15, t.y, t.z & 15);
					Tag_Compound tile;
					tile["i"] = Tag_String(BlockIDToName[block.id].dup);
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

	ref InteralBlock getBlock(uint x, uint y, uint z) {
		assert(y < 256);
		assert(x < 16);
		assert(z < 16);
		return blocks[x + z * 16 + y * 16 * 16];
	}

	ref int getHeight(uint x, uint z) {
		return heightMap[x + z * 16];
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
		return Block(block(x, y, z).id, block(x, y, z).meta);
	}

	Block opIndexAssign(Block b, int x, int y, int z) {
		block(x, y, z).id = b.id;
		block(x, y, z).meta = b.meta;
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
		return !!(pos in chunks);
	}

	void setEntity(Tag_Compound e, LevelPos pos) {
		setEntity(e, pos.x, pos.y, pos.z);
	}

	static struct ChunkElm {
		Pos pos;
		Chunk* chunk;
	}

	auto genChunkList() {
		ChunkElm[] list;
		foreach (pos, ref chunk; chunks) {
			list ~= ChunkElm(pos, &chunk);
		}
		list.sort!("a.chunk < b.chunk"); //yes, compare the pointers
		return list;
	}

	void calculateBlockLight(bool print, ChunkElm[] chunks) {
		foreach (c, chunkElm; chunks) {
			auto pos = chunkElm.pos;
			if (print) {
				writef("Calcutaing block light for chunk(%#5s,%#5s) %s%%\r",
					pos.x, pos.z, c * 100 / chunks.length);
				stdout.flush;
			}
			calcBlockLight(this, *chunkElm.chunk, pos.x, pos.z);
		}
		if (print) {
			writeln();
		}
	}

	void calculateSkyLight1(bool print, ChunkElm[] chunks) {
		foreach (c, chunkElm; chunks) {
			auto pos = chunkElm.pos;
			if (print) {
				writef("Calcutaing sky light 1 for chunk(%#5s,%#5s) %s%%\r",
					pos.x, pos.z, c * 100 / chunks.length);
				stdout.flush;
			}
			calcSkyLight1(this, *chunkElm.chunk);
		}
		if (print) {
			writeln();
		}
	}

	void calculateSkyLight2(bool print, ChunkElm[] chunks) {
		foreach (c, chunkElm; chunks) {
			auto pos = chunkElm.pos;
			if (print) {
				writef("Calcutaing sky light 2 for chunk(%#5s,%#5s) %s%%\r",
					pos.x, pos.z, c * 100 / chunks.length);
				stdout.flush;
			}
			calcSkyLight2(this, *chunkElm.chunk, pos.x, pos.z);
		}
		if (print) {
			writeln();
		}
	}

	void tileWater(bool print, ChunkElm[] chunks) {
		foreach (c, chunkElm; chunks) {
			auto pos = chunkElm.pos;
			if (print) {
				writef("TileTicking water for      chunk(%#5s,%#5s) %s%%\r",
					pos.x, pos.z, c * 100 / chunks.length);
				stdout.flush;
			}
			tileTickWater(this, *chunkElm.chunk, pos.x, pos.z);
		}
		if (print) {
			writeln();
		}
	}

private:
	ref InteralBlock block(int x, int y, int z) {
		assert(y >= 0 && y < 256);
		auto pos = Pos(x >> 4, z >> 4);
		tryCreateChunk(pos);
		return chunks[pos].getBlock(x & 15, y, z & 15);
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

struct Region {
	Chunk*[32 * 32] chunks;

	auto ref chunkAt(Pos chunkPos) {
		return chunks[(chunkPos.x & 31) + (chunkPos.z & 31) * 32];
	}
}

void calcBlockLight(Level lev, ref Chunk chunk, int offx, int offz) {
	void spreadStart(InteralBlock b, int x, int y, int z) {
		ubyte light = b.getLightFromID;
		if (light > 0) {

			spread!(a => a.blockLight, (ref b, l) => b.blockLight = l)(lev, light,
				x, y, z);
		}
	}

	foreach (y; 0 .. 256) {
		foreach (cz; 0 .. 16) {
			foreach (cx; 0 .. 16) {
				auto block = chunk.getBlock(cx, y, cz);
				spreadStart(block, cx + offx * 16, y, cz + offz * 16);
			}
		}
	}
}

void calcSkyLight1(Level lev, ref Chunk chunk) {
	foreach (cz; 0 .. 16) {
		foreach (cx; 0 .. 16) {
			foreach_reverse (y; 0 .. 256) {
				auto block = chunk.getBlock(cx, y, cz);
				Transparent type = block.getTransFromID;
				if (type != Transparent.Full) {
					break;
				}
				chunk.getBlock(cx, y, cz).skyLight = 15;
				chunk.heightMap[cx + cz * 16] = y;
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
				spread!(a => a.skyLight, (ref b, l) => b.skyLight = l)(lev, 14, x - 1,
					y, z);
				spread!(a => a.skyLight, (ref b, l) => b.skyLight = l)(lev, 14, x + 1,
					y, z);
				spread!(a => a.skyLight, (ref b, l) => b.skyLight = l)(lev, 14, x,
					y, z - 1);
				spread!(a => a.skyLight, (ref b, l) => b.skyLight = l)(lev, 14, x,
					y, z + 1);
			}
			if (height > 0) {
				spread!(a => a.skyLight, (ref b, l) => b.skyLight = l)(lev, 14, x,
					height - 1, z);
			}
		}
	}
}

void tileTickWater(Level lev, ref Chunk chunk, int offx, int offz) {
	void tileWater(InteralBlock b, int x, int y, int z) {

		if (b.id == Blocks.water.id) {
			foreach (xI; TypeTuple!(-1, 1)) {
				foreach (zI; TypeTuple!(-1, 1)) {
					if (!lev.exists(x + xI, y, z + zI) || lev.block(x + xI, y, z + zI).id == 0) {
						lev.block(x, y, z).id = Blocks.flowing_water.id;
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
				auto block = chunk.getBlock(cx, y, cz);
				tileWater(block, cx + offx * 16, y, cz + offz * 16);
			}
		}
	}
}

void spread(alias lightGet, alias lightSet)(Level lev, ubyte light, int x, int y, int z) {
	if (lev.exists(x, y, z)) {
		auto block = lev.block(x, y, z);
		Transparent type = block.getTransFromID;
		if (type == Transparent.None) {
			return;
		}
		if (type == Transparent.Water) {
			if (light <= 2) {
				return;
			}
			light -= 2;
		}
		if (lightGet(block) < light) {
			lightSet(lev.block(x, y, z), light);
		}
		else {
			return;
		}
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
