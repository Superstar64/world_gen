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
module blockdata;
import level : Block;
import std.traits;

enum Transparent {
	None,
	Full,
	Defuse,
	Water //Defuse - 2
}

struct BlockData {
	ubyte id;
	ubyte light;
	Transparent trans;
	bool search = true;
	ubyte meta;
	@property Block _get() {
		return Block(id, meta);
	}

	alias _get this;
}

enum BlockIDToName = {

	string[int] map;
	foreach (E;
	EnumMembers!Blocks) {
		if (E.search) {
			map[E.id] = "minecraft:" ~ E.stringof;
		}
	}
	return map;
}();

auto getTrans(ubyte id) {
	foreach (E; EnumMembers!Blocks) {
		if (E.search) {
			if (E.id == id) {
				return E.trans;
			}
		}
	}
	assert(0);
}

auto getLight(ubyte id) {
	foreach (E; EnumMembers!Blocks) {
		if (E.search) {
			if (E.id == id) {
				return E.light;
			}
		}
	}
	assert(0);
}

//in game names from minecraft wiki
enum Blocks : BlockData {
	air = BlockData(0, 0, Transparent.Full),
	stone = BlockData(1),
	grass = BlockData(2),
	dirt = BlockData(3),
	cobblestone = BlockData(4),
	planks = BlockData(5),
	sapling = BlockData(6, 0, Transparent.Full),
	bedrock = BlockData(7),
	flowing_water = BlockData(8, 0, Transparent.Water),
	water = BlockData(9, 0, Transparent.Water),
	flowing_lava = BlockData(10, 15,
		Transparent.Full),
	lava = BlockData(11, 15, Transparent.Full),
	sand = BlockData(12),
	gravel = BlockData(13),
	gold_ore = BlockData(14),
	iron_ore = BlockData(15),
	coal_ore = BlockData(16),
	log = BlockData(17),
	leaves = BlockData(18, 0, Transparent.Defuse),
	sponge = BlockData(19),
	glass = BlockData(20, 0, Transparent.Full),
	lapis_ore = BlockData(21),
	lapis_block = BlockData(22),
	dispenser = BlockData(23),
	sandstone = BlockData(24),
	noteblock = BlockData(25),
	bed = BlockData(26, 0,
		Transparent.Full),
	golden_rail = BlockData(27, 0, Transparent.Full),
	detector_rail = BlockData(28, 0, Transparent.Full),
	sticky_piston = BlockData(29, 0, Transparent.Full),
	web = BlockData(30),
	shrub = BlockData(31, 0, Transparent.Full),
	tallgrass = BlockData(31, 0,
		Transparent.Full, false, 1),
	fern = BlockData(31, 0, Transparent.Full,
		false, 2),
	deadbush = BlockData(32),
	piston = BlockData(33, 0,
		Transparent.Full),
	piston_head = BlockData(34, 0, Transparent.Full),
	wool = BlockData(35),
	piston_extension = BlockData(36, 0, Transparent.Full),
	yellow_flower = BlockData(37, 0, Transparent.Full),
	red_flower = BlockData(38, 0, Transparent.Full),
	brown_mushroom = BlockData(39, 1),
	red_mushroom = BlockData(40),
	gold_block = BlockData(41),
	iron_block = BlockData(42),
	double_stone_slab = BlockData(43),
	stone_slab = BlockData(44),
	brick_block = BlockData(45),
	tnt = BlockData(46),
	bookshelf = BlockData(47),
	mossy_cobblestone = BlockData(48),
	obsidian = BlockData(49),
	torch = BlockData(50, 14, Transparent.Full),
	torchEast = BlockData(50, 14,
		Transparent.Full, false, 1),
	torchWest = BlockData(50, 14,
		Transparent.Full, false, 2),
	torchSouth = BlockData(50, 14,
		Transparent.Full, false, 3),
	torchNorth = BlockData(50, 14,
		Transparent.Full, false, 4),
	torchUp = BlockData(50, 14,
		Transparent.Full, false, 5),
	fire = BlockData(51, 15, Transparent.Full),
	mob_spawner = BlockData(52),
	oak_stairs = BlockData(53),
	chest = BlockData(54, 0, Transparent.Full),
	redstone_wire = BlockData(55, 0,
		Transparent.Full),
	diamond_ore = BlockData(56),
	diamond_block = BlockData(57),
	crafting_table = BlockData(58),
	wheat = BlockData(59, 0, Transparent.Full),
	wheatFull = BlockData(59, 0,
		Transparent.Full, false, 7),
	farmland = BlockData(60),
	farmlandWet = BlockData(60, 0, Transparent.None, false, 7),
	furnace = BlockData(61),
	lit_furnace = BlockData(62, 13),
	standing_sign = BlockData(63, 0, Transparent.Full),
	wooden_door = BlockData(64, 0, Transparent.Full),
	ladder = BlockData(65, 0,
		Transparent.Full),
	rail = BlockData(66, 0, Transparent.Full),
	stone_stairs = BlockData(67),
	wall_sign = BlockData(68),
	lever = BlockData(69, 0, Transparent.Full),
	stone_pressure_plate = BlockData(70, 0, Transparent.Full),
	iron_door = BlockData(71, 0, Transparent.Full),
	wooden_pressure_plate = BlockData(72, 0, Transparent.Full),
	redstone_ore = BlockData(73),
	lit_redstone_ore = BlockData(74, 9,
		Transparent.Defuse),
	unlit_redstone_torch = BlockData(75, 0,
		Transparent.Full),
	redstone_torch = BlockData(76, 7, Transparent.Full),
	stone_button = BlockData(77, 0, Transparent.Full),
	snow_layer = BlockData(78, 0, Transparent.Full),
	ice = BlockData(79, 0,
		Transparent.Water),
	snow = BlockData(80),
	cactus = BlockData(81, 0,
		Transparent.Full),
	clay = BlockData(82),
	reeds = BlockData(83, 0,
		Transparent.Full),
	jukebox = BlockData(84),
	fence = BlockData(85, 0,
		Transparent.Full),
	pumpkin = BlockData(86),
	netherrack = BlockData(87),
	soul_sand = BlockData(88),
	glowstone = BlockData(89, 15,
		Transparent.Defuse),
	portal = BlockData(90, 11, Transparent.Full),
	lit_pumpkin = BlockData(91, 15, Transparent.Full),
	cake = BlockData(92, 0,
		Transparent.Full),
	unpowered_repeater = BlockData(93, 0,
		Transparent.Full),
	powered_repeater = BlockData(94, 0,
		Transparent.Full),
	stained_glass = BlockData(95, 0, Transparent.Full),
	trapdoor = BlockData(96, 0, Transparent.Full),
	monster_egg = BlockData(97),
	stonebrick = BlockData(98),
	brown_mushroom_block = BlockData(99),
	red_mushroom_block = BlockData(100),
	iron_bars = BlockData(101, 0,
		Transparent.Full),
	glass_pane = BlockData(102, 0, Transparent.Full),
	melon_block = BlockData(103),
	pumpkin_stem = BlockData(104, 0,
		Transparent.Full),
	melon_stem = BlockData(105, 0, Transparent.Full),
	vine = BlockData(106, 0, Transparent.Full),
	fence_gate = BlockData(107, 0,
		Transparent.Full),
	brick_stairs = BlockData(108),
	stone_brick_stairs = BlockData(109),
	mycelium = BlockData(110),
	waterlily = BlockData(111, 0, Transparent.Full),
	nether_brick = BlockData(112),
	nether_brick_fence = BlockData(113, 0,
		Transparent.Full),
	nether_brick_stairs = BlockData(114, 0),
	nether_wart = BlockData(115),
	enchanting_table = BlockData(116, 0,
		Transparent.Full),
	brewing_stand = BlockData(117, 1, Transparent.Full),
	cauldron = BlockData(118, 0, Transparent.Full),
	end_portal = BlockData(119,
		15, Transparent.Full),
	end_portal_frame = BlockData(120, 1),
	end_stone = BlockData(121),
	dragon_egg = BlockData(122, 1),
	redstone_lamp = BlockData(123),
	lit_redstone_lamp = BlockData(124, 15,
		Transparent.Defuse),
	double_wooden_slab = BlockData(125),
	wooden_slab = BlockData(126),
	cocoa = BlockData(127),
	sandstone_stairs = BlockData(128),
	emerald_ore = BlockData(129),
	ender_chest = BlockData(130, 7, Transparent.Full),
	tripwire_hook = BlockData(131),
	tripwire = BlockData(132),
	emerald_block = BlockData(133),
	spruce_stairs = BlockData(134),
	birch_stairs = BlockData(135),
	jungle_stairs = BlockData(136),
	command_block = BlockData(137),
	beacon = BlockData(138, 15),
	cobblestone_wall = BlockData(139, 0, Transparent.Full),
	flower_pot = BlockData(140),
	carrots = BlockData(141),
	potatoes = BlockData(142, 0, Transparent.Full),
	wooden_button = BlockData(143, 0, Transparent.Full),
	skull = BlockData(144),
	anvil = BlockData(145, 0, Transparent.Full),
	trapped_chest = BlockData(146,
		0, Transparent.Full),
	light_weighted_pressure_plate = BlockData(147, 0,
		Transparent.Full),
	heavy_weighted_pressure_plate = BlockData(148, 0,
		Transparent.Full),
	unpowered_comparator = BlockData(149, 0,
		Transparent.Full),
	powered_comparator = BlockData(150, 0,
		Transparent.Full),
	daylight_detector = BlockData(151, 0,
		Transparent.Full),
	redstone_block = BlockData(152),
	quartz_ore = BlockData(153),
	hopper = BlockData(154, 0, Transparent.Full),
	quartz_block = BlockData(155),
	quartz_stairs = BlockData(156),
	activator_rail = BlockData(157, 0, Transparent.Full),
	dropper = BlockData(158),
	stained_hardened_clay = BlockData(159),
	stained_glass_pane = BlockData(160, 0, Transparent.Full),
	leaves2 = BlockData(161),
	log2 = BlockData(162),
	acacia_stairs = BlockData(163),
	dark_oak_stairs = BlockData(164),
	slime = BlockData(165),
	barrier = BlockData(166),
	iron_trapdoor = BlockData(167),
	prismarine = BlockData(168),
	sea_lantern = BlockData(169, 15),
	hay_block = BlockData(170),
	carpet = BlockData(171, 0, Transparent.Full),
	hardened_clay = BlockData(172),
	coal_block = BlockData(173),
	packed_ice = BlockData(174),
	double_plant = BlockData(175),
	standing_banner = BlockData(176),
	wall_banner = BlockData(177),
	daylight_detector_inverted = BlockData(178, 0, Transparent.Full),
	red_sandstone = BlockData(179),
	red_sandstone_stairs = BlockData(180),
	double_stone_slab2 = BlockData(181),
	stone_slab2 = BlockData(182),
	spruce_fence_gate = BlockData(183, 0, Transparent.Full),
	birch_fence_gate = BlockData(184, 0, Transparent.Full),
	jungle_fence_gate = BlockData(185, 0, Transparent.Full),
	dark_oak_fence_gate = BlockData(186, 0, Transparent.Full),
	acacia_fence_gate = BlockData(187, 0, Transparent.Full),
	spruce_fence = BlockData(188, 0, Transparent.Full),
	birch_fence = BlockData(189, 0, Transparent.Full),
	jungle_fence = BlockData(190, 0, Transparent.Full),
	dark_oak_fence = BlockData(191, 0, Transparent.Full),
	acacia_fence = BlockData(192, 0, Transparent.Full),
	spruce_door = BlockData(193, 0, Transparent.Full),
	birch_door = BlockData(194, 0, Transparent.Full),
	jungle_door = BlockData(195, 0, Transparent.Full),
	acacia_door = BlockData(196, 0, Transparent.Full),
	dark_oak_door = BlockData(197, 0, Transparent.Full)
}
