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
module app;
import nbt;
import level;
import gen;
import std.file;
import std.path;
import blockdata;
import std.stdio : writeln, readln;
import std.string;
import std.random;
import std.getopt;
import std.conv;
import std.algorithm : sort;
auto spawny = 128;
auto LevelDat(string worldName) {
	NBTRoot root;
	{
		Tag_Compound data;
		{
			data["version"] = Tag_Int(19133);
			data["initialized"] = Tag_Byte(1);
			data["LevelName"] = Tag_String(worldName.dup);
			data["generatorName"] = Tag_String("default".dup);
			data["generatorVersion"] = Tag_Int(0);
			data["RandomSeed"] = Tag_Long(0);
			data["MapFeatures"] = Tag_Byte(1);
			data["LastPlayed"] = Tag_Long(0);
			data["allowCommands"] = Tag_Byte(1);
			data["hardcore"] = Tag_Byte(0);
			data["GameType"] = Tag_Int(0);
			data["Difficulty"] = Tag_Byte(2);
			data["Time"] = Tag_Long(0);
			data["DayTime"] = Tag_Long(0);
			data["SpawnX"] = Tag_Int(0);
			data["SpawnY"] = Tag_Int(spawny);
			data["SpawnZ"] = Tag_Int(0);
			data["raining"] = Tag_Byte(0);
			data["rainTime"] = Tag_Int(60 * 20);
			data["thundering"] = Tag_Byte(0);
			data["thunderTime"] = Tag_Int(0);
			data["clearWeatherTime"] = Tag_Int(60 * 60 * 20);
			auto player = Tag_Compound();
			player["Pos"] = Tag_List([Tag_Double(0), Tag_Double(spawny), Tag_Double(0)]);
			data["Player"] = player;
		}
		root.tag["Data"] = data;
	}
	return root;
}

struct Init {
	size_t priority;
	void function() fun;
}

Init[] initTable;
template setter(alias symbol, alias regular, size_t priority = 0) {
	bool thisSet;
	void setFun(string, string val) {
		thisSet = true;
		symbol = val.to!(typeof(symbol));
	}

	void defaultInit() {
		if (!thisSet) {
			symbol = regular();
		}
	}

	static this() {
		initTable ~= Init(priority, &defaultInit);
	}

	enum setter = &setFun;
}

void main(string[] args) {
	bool verbose = true;
	string world = "world";
	string tempFile = "world_gen.temp";
	uint seed;
	uint size = 640;
	bool seedSet;
	void setSeed(string, string val) {
		try {
			seed = val.to!uint;
		}
		catch (Exception e) {
			import std.zlib;

			seed = crc32(0, val);
		}
		seedSet = true;
	}

	void setTemp(string, string val) {
		if (val == "-") {
			tempFile = null;
		} else {
			tempFile = val;
		}
	}

	bool help;
	getopt(args, "v|verbose", &verbose, "w|world", &world, "s|seed",
		&setSeed, "z|size", &size, "r|radius", &islandRadius, "c|chuck",
		setter!(chunkSize, () => islandRadius * 2 + 12), "h|help", &help,
		"t|temp", &setTemp, "heightLim", &heightLim, "heightHalf",
		setter!(heightHalf, () => heightLim / 2), "sandHeight",
		setter!(sandHeight, () => heightHalf - 2, 1), "landNoiseCycles",
		&landNoiseCycles, "bottomH", &bottomH, "caveHeight", &caveHeight,
		"caveLim", &caveLim, "caveInc", setter!(caveInc,
		() => caveHeight + caveLim), "wallNoiseCycles", &wallNoiseCycles,
		"wallLimit", &wallLimit, "caveNoiseCycles", &caveNoiseCycles,
		"animals", &animalListString,"deepLava",&deepLava,"spawny",&spawny);
	if (help) {
		writeln(`world_gen
-v --verbose=  be loud(default = true)
-w --world=    set world name(default = world)
-s --seed=     world seed
-z --size=     world size(default = 640)
-r --radius=   island radius(default = 250)
-c --chuck=    island fequency(radius * 2 + 12)
-t --temp=     temporary file name (- for none)


--heightLim=       height of island top(default = 16)
--heightHalf=      height of water(default = heightLim / 2)
--sandHeight=      height of sand(default = heightHalf / 2)
--landNoiseCycles= land smoothness(bigger is higher)
--animals=         list of animals(default = ["Chicken", "Cow", "Pig", "Rabbit", "Sheep", "EntityHorse"])

--bottomH=         height of island bottom(default = 64)
--caveHeight=      exact height of cave in air(default = 8)
--caveLim=         height of cave bottom(default = 16)
--caveInc=         cave layer difference(default = caveHeight + caveInc)
--wallNoiseCycles= cave wall smoothness(default = 3)
--wallLimit=       ofteness of cave walls(bigger is more often)(default = 105)
--caveNoiseCycles= cave floor smoothness(default = 6)
--deepLava=        spawn more lava the deeper the cave is(in blocks)(default = 5)
--spawny=          set player spawn y(default = 128)
`);
		return;
	}
	initTable.sort!"a.priority < b.priority";
	foreach (set; initTable) {
		set.fun();
	}

	if (exists(world)) {
		writeln(world, " already exists override? y/n");
		while (true) {
			auto str = readln().strip;
			if (str == "y" || str == "Y") {
				rmdirRecurse(world);
				break;
			}
			if (str == "n" || str == "N") {
				return;
			}
		}
	}
	mkdir(world);
	writeNBTFile(buildPath(world, "level.dat"), LevelDat(world), 2);
	write(buildPath(world, "session.lock"), []);
	auto region = buildPath(world, "region");
	mkdirRecurse(region);
	mkdirRecurse(buildPath(world, "DIM-1"));
	mkdirRecurse(buildPath(world, "DIM1"));
	mkdirRecurse(buildPath(world, "playerdata"));
	mkdirRecurse(buildPath(world, "stats"));
	mkdirRecurse(buildPath(world, "data"));
	if (verbose) {
		writeln("Generating world");
	}
	Random rng;
	if (seedSet) {
		rng = Random(seed);
	} else {
		rng = rndGen();
	}
	auto lev = genLevel(rng, size, verbose, tempFile);
	lev.calculateLightandWater(verbose);
	lev.save(region, verbose);
}
