/+Copyright (C) 2015  Freddy Angel Cubas "Superstar64"

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
+/
import level;
import nbt;
import blockdata;
import std.random;
import std.algorithm;
import std.math;
import std.typetuple;
import std.stdio;
import noise;

auto chunkSize = 512;
auto islandRadius = 256;

Level genLevel(ref Random rng, int size, bool verbose, string tempFile) {
	foreach (a; animalListString) {
		auto comp = Tag_Compound();
		comp["id"] = Tag_String(a.dup);
		animalList ~= comp;
	}

	Level lev = new Level(size, tempFile);
	auto set = Setter(levelSet(lev), levelGet(lev), levelSetEntity(lev));
	generate(set, rng, size, verbose);
	fill(lev, Blocks.air, LevelPos(-size, 255, -size), LevelPos(size, 256, size)); //todo light calculating glitches out when block at sky limit
	return lev;
}

void generate(Setter set, ref Random rng, int size, bool verbose) {
	auto iter = size / chunkSize;

	size_t total;
	foreach (cx; -iter .. iter + 1) {
		foreach (cz; -iter .. iter + 1) {
			total++;
		}
	}
	size_t cur;
	foreach (cx; -iter .. iter + 1) {
		foreach (cz; -iter .. iter + 1) {
			auto x = cx * chunkSize;
			auto z = cz * chunkSize;
			import std.stdio;

			if (verbose) {
				writef("Generating island at (%#5s,%#5s) %s%%\r", x, z, cur * 100 / total);
				stdout.flush;
			}
			genForest(set.from(transformOff(x, 127 - 16, z)), rng, islandRadius);
			cur++;
		}
	}
	if (verbose) {
		writeln();
	}
}

void fill(Level lev, Block block, LevelPos a, LevelPos b) {
	foreach (x; min(a.x, b.x) .. max(a.x, b.x)) {
		foreach (z; min(a.z, b.z) .. max(a.z, b.z)) {
			foreach (y; min(a.y, b.y) .. max(a.y, b.y)) {
				lev[x, y, z] = block;
			}
		}
	}
}

void fill(Setter set, Block block, LevelPos a) {
	foreach (x; 0 .. a.x) {
		foreach (z; 0 .. a.z) {
			foreach (y; 0 .. a.y) {
				set[x, y, z] = block;
			}
		}
	}
}

void fill(Setter set, Block block, int x, int y, int z) {
	fill(set, block, LevelPos(x, y, z));
}

auto levelSet(Level lev) {
	return (Block b, LevelPos pos) { lev[pos] = b; };
}

auto levelGet(Level lev) {
	return (LevelPos pos) { return lev[pos]; };
}

auto levelSetEntity(Level lev) {
	return (const Tag_Compound b, LevelPos pos) { lev.setEntity(b, pos); };
}

alias Transformer = LevelPos delegate(LevelPos);

Transformer transformOff(LevelPos pos) {
	return transformOff(pos.x, pos.y, pos.z);
}

Transformer transformOff(int x, int y, int z) {
	return (LevelPos a) => LevelPos(a.x + x, a.y + y, a.z + z);
}

Transformer transform0() {
	return (LevelPos a) => a;
}

Transformer transformNegZ() {
	return (LevelPos a) => LevelPos(a.x, a.y, -a.z);
}

Transformer transformNegY() {
	return (LevelPos a) => LevelPos(a.x, -a.y, a.z);
}

struct Setter {
	void delegate(Block, LevelPos) set;
	Block delegate(LevelPos) get;
	void delegate(const Tag_Compound, LevelPos) setEntity;

	Block opIndex(int x, int y, int z) {
		return opIndex(LevelPos(x, y, z));
	}

	Block opIndex(LevelPos pos) {
		return get(pos);
	}

	Block opIndexAssign(Block b, int x, int y, int z) {
		return opIndexAssign(b, LevelPos(x, y, z));
	}

	Block opIndexAssign(Block b, LevelPos pos) {
		set(b, pos);
		return b;
	}

	typeof(this) from(Transformer tran = transform0) {
		static auto dual1(typeof(set) head, Transformer tail) {
			return (Block b, LevelPos pos) => head(b, tail(pos));
		}

		static auto dual2(typeof(get) head, Transformer tail) {
			return (LevelPos pos) => head(tail(pos));
		}

		static auto dual3(typeof(setEntity) head, Transformer tail) {
			return (const Tag_Compound b, LevelPos pos) => head(b, tail(pos));
		}

		return Setter(dual1(set, tran), dual2(get, tran), dual3(setEntity, tran));
	}

}

void setIfAir(ref Setter setter) {
	auto org = setter;
	setter = setter.from((LevelPos pos) {
		if (org[pos] != Blocks.air) {
			return LevelPos(0, -1, 0);
		} else {
			return pos;
		}
	});
}

void drawNoise(alias check = (int x, int z) => true, alias getHeight)(Setter set,
	int x2, int z2, Block ground) {
	foreach (x; 0 .. x2) {
		foreach (z; 0 .. z2) {
			if (check(x, z)) {
				auto height = getHeight(x, z);
				foreach (ay; 0 .. height) {
					set[x, ay, z] = ground;
				}
			}
		}
	}
}

auto bottomH = 64; //height of bottom
auto caveHeight = 8; //cave air height
auto caveLim = 16; //cave rock height
auto caveInc = 24; //layer difference

auto wallNoiseCycles = 3; //cave walls smoothness
ubyte wallLimit = 105; //biggest value for a wall (bigger means for cave walls)
auto caveNoiseCycles = 6; //cave floor smoothness
int deepLava = 5;//spawn more lava the deeper the cave is
void genUnderSide(alias check)(Setter set, ref Random rng, int radius) {
	auto x2 = radius * 2;
	auto z2 = radius * 2;
	auto underset = set.from(transformNegY());

	auto getUnder(int x, int z) { //not actually random
		auto cirleFilter(double num) {
			assert(num >= 0 && num <= 1);
			return sqrt(1 - (num - 1) ^^ 2);
		}

		return cast(int)(bottomH * cirleFilter((radius - hypot(x - radius,
			z - radius)) / (cast(double) radius)));
	}

	drawNoise!(check, getUnder)(underset, x2, z2, Blocks.stone);

	int layer;

	while (layer < bottomH) { //caves made in layers
		auto caveHNoise = genNoise(x2, z2, rng, wallNoiseCycles);
		auto caveGNoise = genNoise(x2, z2, rng, caveNoiseCycles);
		foreach (x; 0 .. x2) {
			foreach (z; 0 .. z2) {
				if (check(x, z) && getUnder(x, z) > caveHeight) {
					if (cast(ubyte)(255 * caveHNoise[x, z]) > wallLimit) {
						auto val = layer + cast(int)(caveLim * caveGNoise[x, z]);
						if (val + caveHeight < getUnder(x, z)) {
							foreach (i; val .. val + caveHeight) {
								if (i - layer + deepLava * layer / bottomH > caveInc / 2) {
									underset[x, i, z] = Blocks.lava;
								} else {
									underset[x, i, z] = Blocks.air;
								}
							}
						}

					}
				}
			}
		}
		layer += caveInc;
	}
	auto genOre(Block ore) {
		int x = uniform(0, x2, rng);
		int y = uniform(0, bottomH, rng);
		int z = uniform(0, z2, rng);
		foreach (ax; -1 + x .. 2 + x) {
			foreach (ay; -1 + y .. 2 + y) {
				foreach (az; -1 + z .. 2 + z) {
					if (underset[ax, ay, az] == Blocks.stone) {
						if (uniform(0, 6, rng)) {
							underset[ax, ay, az] = ore;
						}
					}
				}
			}
		}
	}

	foreach (i; 0 .. radius * 4) {
		genOre(Blocks.diamond_ore);
		genOre(Blocks.gold_ore);
		genOre(Blocks.lapis_ore);
		foreach (j; 0 .. 2) {
			genOre(Blocks.redstone_ore);
		}
		foreach (j; 0 .. 10) {
			genOre(Blocks.iron_ore);
			genOre(Blocks.coal_ore);
		}
	}
}

auto heightLim = 16; //max height of land 
auto heightHalf = 8; //water height
auto sandHeight = 6; // sand height
auto landNoiseCycles = 4; //land smoothness (bigger is more smooth)
Tag_Compound[] animalList;
string[] animalListString = ["Chicken", "Cow", "Pig", "Rabbit", "Sheep", "EntityHorse"];

void genForest(Setter set, ref Random rng, int radius) {
	set = set.from(transformOff(-radius, 0, -radius));
	auto x2 = radius * 2;
	auto z2 = radius * 2;

	auto noise = genNoise(x2, z2, rng, landNoiseCycles);
	auto check(int x, int z) {
		return hypot(x - radius, z - radius) < radius;
	}

	auto getHeight(int x, int z) {
		auto heightn = (noise[x, z] + 1) / 2;
		return cast(int)(heightn * heightLim);
	}

	drawNoise!(check, getHeight)(set, x2, z2, Blocks.dirt);
	genUnderSide!check(set, rng, radius);

	foreach (x; 0 .. x2) {
		foreach (z; 0 .. z2) {
			if (!check(x, z)) {
				continue;
			}
			auto height = getHeight(x, z);
			if (height < heightHalf) {
				foreach (i; height .. heightHalf) {
					set[x, i, z] = Blocks.water;
				}
				if (height < sandHeight) {
					foreach (i; 0 .. height) {
						set[x, i, z] = Blocks.sand;
					}
				}
			} else {
				set[x, height - 1, z] = Blocks.grass;
				if (uniform(0, 128, rng) == 0) {
					genTree(set.from(transformOff(x, height, z)), rng);
				}
			}
			//tall grass,flowers, clay
			if (uniform(0, 64, rng) == 0) {
				auto old = set;
				bool above = height >= heightHalf;
				if (above) {
					setIfAir(set);
				}
				auto width = uniform(1, 5, rng);
				auto length = uniform(1, 5, rng);
				Block block;
				if (above) {
					block = Blocks.tallgrass;
					auto num = uniform(0, 256, rng);
					if (num == 0) {
						block = Blocks.melon_block;
					} else if (num < 2) {
						block = Blocks.pumpkin;
					} else if (num < 18) {
						block = Blocks.yellow_flower;
					} else if (num < 34) {
						block = Blocks.red_flower;
					} else if (num < 54) {
						block = Blocks.reeds;
					}
				} else {
					if (uniform(0, 8, rng) == 0) {
						block = Blocks.clay;
					} else {
						goto end;
					}
				}
				foreach (ax; x - width .. x + width) {
					foreach (az; z - length .. z + length) {
						if (check(ax, az)) {
							auto height2 = getHeight(ax, az);
							if (above) {
								if (height2 < heightHalf) {
									continue;
								}
							} else {
								if (height2 >= heightHalf) {
									continue;
								}
							}
							if (block == Blocks.reeds) {
								bool should;
								foreach (cx; TypeTuple!(-1, 1)) {
									should = should || (check(ax + cx, az)
										&& getHeight(ax + cx, az) < heightHalf);
								}
								foreach (cz; TypeTuple!(-1, 1)) {
									should = should || (check(ax, az + cz)
										&& getHeight(ax, az + cz) < heightHalf);
								}
								if (should && old[ax, height2, az] == Blocks.air) {
									foreach (i; height2 .. height2 + 3) {
										set[ax, i, az] = block;
									}
								}
							} else {
								if (above) {
									if (uniform(0, 16, rng)) {
										set[ax, height2, az] = block;
									}
								} else {
									foreach (i2; 0 .. height2) {
										set[ax, i2, az] = block;
									}
								}
							}
						}
					}
				}

			end:

				set = old;
			}
		}
	}

	auto animals = (x2 * z2) / 128;
	animals = uniform(animals + 2, animals + 10, rng);

	foreach (i; 0 .. animals) {
		int x;
		int z;
		recalc: do {
			x = uniform(0, x2, rng);
			z = uniform(0, z2, rng);
		}
		while (!check(x, z));

		auto y = getHeight(x, z);
		if (y < heightHalf) {
			if (uniform(0, 4)) {
				goto recalc;
			}
			y = heightHalf;
		}
		set.setEntity(animalList[uniform(0, animalList.length, rng)], LevelPos(x, y,
			z));
	}
}

auto genTree(Setter set, ref Random rng) {
	auto off = uniform(0, 2, rng);
	foreach (x; -2 .. 3) {
		foreach (z; -2 .. 3) {
			if (x == 0 && z == 0) {
				continue;
			}
			if (abs(x) == 2 && abs(z) == 2) {
				if (uniform(0, 16, rng)) {
					set[x, off + 2, z] = Blocks.leaves;
				}
				if (uniform(0, 16, rng)) {
					set[x, off + 3, z] = Blocks.leaves;
				}
			} else {
				set[x, off + 2, z] = Blocks.leaves;
				set[x, off + 3, z] = Blocks.leaves;
			}
		}
	}
	foreach (x; -1 .. 2) {
		foreach (z; -1 .. 2) {
			if (x == 0 && z == 0) {
				continue;
			}
			set[x, off + 4, z] = Blocks.leaves;
		}
	}
	foreach (y; 0 .. off + 5) {
		set[0, y, 0] = Blocks.log;
	}
	set[0, off + 5, 0] = Blocks.leaves;
	if (uniform(0, 2, rng)) {
		set[-1, off + 5, 0] = Blocks.leaves;
		set[1, off + 5, 0] = Blocks.leaves;
		set[0, off + 5, -1] = Blocks.leaves;
		set[0, off + 5, 1] = Blocks.leaves;
	}
}
