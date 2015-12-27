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
			data["SpawnY"] = Tag_Int(128);
			data["SpawnZ"] = Tag_Int(0);
			data["raining"] = Tag_Byte(0);
			data["rainTime"] = Tag_Int(60 * 20);
			data["thundering"] = Tag_Byte(0);
			data["thunderTime"] = Tag_Int(0);
			data["clearWeatherTime"] = Tag_Int(60 * 60 * 20);
			auto player = Tag_Compound();
			player["Pos"] = Tag_List([Tag_Double(0), Tag_Double(128), Tag_Double(0)]);
			data["Player"] = player;
		}
		root.tag["Data"] = data;
	}
	return root;
}

void main(string[] args) {
	bool verbose = true;
	string world = "world";
	string tempFile = "world_gen.temp";
	uint seed;
	uint size = 640;
	bool seedSet;
	int radius = 250;
	int chuck = 512;
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
	
	void setTemp(string, string val){
		if(val == "-"){
			tempFile = null;
		}else{
			tempFile = val;
		}
	}
	
	bool help;
	getopt(args, "v|verbose", &verbose, "w|world", &world, "s|seed",
		&setSeed, "z|size", &size, "r|radius", &radius, "c|chuck", &chuck, "h|help",
		&help, "t|temp", &setTemp);
	if (help) {
		writeln(`world_gen
-v --verbose=  be loud(default = true)
-w --world=    set world name(default = world)
-s --seed=     world seed
-z --size=     world size(default = 640)
-r --radius=   island radius(default = 250)
-c --chuck=    island fequency(recommend radius*2 + 12)
-t --temp=     temporary file name (- for none)
`);
		return;
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
	}
	else {
		rng = rndGen();
	}
	auto lev = genLevel(rng, size, verbose, radius, chuck, tempFile);
	lev.calculateLightandWater(verbose);
	lev.save(region, verbose);
}
