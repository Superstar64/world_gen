/+Copyright (C) 2015  Freddy Angel Cubas "Superstar64"

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation,  version 3 of the License.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
+/
import std.random;
import std.math;

struct Grid(T, Index = uint) {
	uint width;
	uint height;
	T[] grid;

	this(Index width, Index height, T def = T.init) {
		this.width = width;
		this.height = height;
		grid = new T[width * height];
		foreach (ref e; grid) {
			e = def;
		}
	}

	auto ref opIndex(Index x, Index y) {
		assert(x < width);
		assert(y < height);
		return grid[x + (y * width)];
	}
}

auto singlepolate(double v0, double v1, double val) {
	//val = sqrt(1-(val-1)^^2);
	val = 1 - (cos(val * PI) + 1) / 2;
	//val = -log(1-val);if(val>1) val = 1;
	//val*=32; val = (cast(int)val) & cast(int)(val * val); val/=32;

	return (v0 * (1 - val) + v1 * val);
}

auto interpolate(double topleft, double topright, double bottomleft,
	double bottomright, double x, double y) {
	auto top = singlepolate(topleft, topright, x);
	auto bottom = singlepolate(bottomleft, bottomright, x);
	return singlepolate(bottom, top, y);
}

//grid of random numbers between -1.0 and 1.0,
Grid!double genNoise(uint width, uint height, ref Random rng, int cycles = 4) {
	auto ret = Grid!double(width, height, 0.0);
	auto baseW = width / 2 ^^ cycles;
	auto baseH = height / 2 ^^ cycles;
	auto base = Grid!double(baseW + 2, baseH + 2, 0.0);
	double amp = 1.0;
	foreach (i; 0 .. cycles) {
		foreach (ref e; base.grid) {
			e = uniform(-amp, amp, rng);
		}
		foreach (x; 0 .. ret.width) {
			foreach (y; 0 .. ret.height) {
				auto bx = baseW * x / ret.width;
				auto by = baseH * y / ret.height;
				auto bx2 = bx + 1;
				auto by2 = by + 1;
				auto xoff = (cast(double)(baseW) * x) / ret.width;
				auto yoff = (cast(double)(baseH) * y) / ret.height;
				ret[x, y] += interpolate(base[bx, by2], base[bx2, by2],
					base[bx, by], base[bx2, by], xoff - bx, yoff - by);
			}
		}
		baseW *= 2;
		baseH *= 2;
		base = Grid!double(baseW + 2, baseH + 2, 0.0);
		amp /= 2;
	}
	foreach (ref e; ret.grid) {
		e /= 2;
	}

	return ret;
}
