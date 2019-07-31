#!/usr/bin/lua

-- Copyright (C) 2019 Stephen M. Cameron
-- Author: Stephen M. Cameron
--
-- This file is part of smcamerons-lua-adventure.
--
-- smcamerons-lua-adventure is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- smcamerons-lua-adventure is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with smcamerons-lua-adventure; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA


-- This program is a little toy adventure game in Lua, mainly made so I
-- can practice a little Lua programming.

time_to_quit = false;
current_location = "maintenance_room";

function strsplit(inputstr, sep)
	if sep == nil then
		sep = "%s";
	end
	local new_array = {};
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(new_array, str);
	end
	return new_array;
end

function map(func, array)
	local new_array = {};
	for i, v in ipairs(array) do
		new_array[i] = func(v);
	end
	return new_array;
end

function cdr(array)
	local new_array = {}
	for i = 2, table.getn(array) do
		table.insert(new_array, array[i])
	end
	return new_array;
end

function table_empty(t)
	return next(t) == nil;
end

function merge_tables(a, b)
	for k, v in pairs(b) do
		a[k] = v;
	end;
	return a;
end

function append_tables(a, b)
	new_table = {}
	i = 1;
	for k, v in pairs(a) do
		new_table[i] = v;
		i = i + 1;
	end
	for k, v in pairs(b) do
		new_table[i] = v;
		i = i + 1;
	end
	return new_table;
end

function print_words(words)
	for i, v in pairs(words) do
		io.write(v .. ", ");
	end
end

function in_array(word, array)
	for i, v in ipairs(array) do
		if v == word then
			return true
		end
	end
	return false
end

function go_direction(direction)
	if room[current_location][direction] == nil then
		io.write(direction .. ": You can't go that way\n");
		return;
	end
	if not in_array(direction, canonical_directions) then
		io.write(direction .. ": You can't go that way\n");
		return;
	end
	destination = room[current_location][direction];
	if room[destination] == nil then
		io.write(direction .. ": I do not understand\n");
		return;
	end
	current_location = destination;
end

function dogo(words)
	map(go_direction, cdr(words));
end

function dolook()
	room[current_location].visited = false;
	print_room_description(current_location, objects);
end

function doinventory()
	count = 0;
	io.write("You are carrying:\n");
	for i, v in pairs(objects) do
		if v.location == "pocket" then
			io.write("  " .. v.desc .. "\n");
			count = count + 1;
		end
	end
	if (count == 0) then
		io.write("  Nothing.\n");
	end
end

function all_in_location(loc)
	stuff = {};
	n = 1;
	for i, v in pairs(objects) do
		if v.location == loc then
			stuff[n] = i;
			n = n + 1;
		end
	end
	return stuff;
end

function all_in_room()
	return all_in_location(current_location);
end

function all_holding()
	return all_in_location("pocket");
end

function all_holding_or_here()
	return append_tables(all_in_room(), all_holding());
end

-- this is for handling the word "all".
-- lookup_nouns will translate "all" to
-- [ "all", None ].  We want to replace
-- that with the appropriate list of objects,
-- The "appropriate" list is context sensitive.
-- which for "drop", will be the list of objs
-- that the player is carrying. for "take", will
-- be the list of objects lying around.  For
-- "examine", will be union of above two lists.
-- Hence the fixupfunc, providing the context
-- correct fixup function.

function fixup_all(objlist, fixupfunc)
	foundall = false;
	fixedup = {};
	for i, v in pairs(objlist) do
		if in_array(v, everything) then
			foundall = true;
		end
	end
	if foundall then
		return merge_tables(objlist, fixupfunc());
	end
	return objlist;
end

function fixup_all_in_room(objlist)
	return fixup_all(objlist, all_in_room);
end

function fixup_all_holding(objlist)
	return fixup_all(objlist, all_holding);
end

function fixup_all_holding_or_here(objlist)
	return fixup_all(objlist, all_holding_or_here);
end

function lookup_noun(word)
	if objects[word] ~= nil then
		return { word, objects[word] };
	end
	return { word, nil };
end

function lookup_nouns(words)
	return map(lookup_noun, words);
end

function lookup_nouns_fixup(words, fixupfunc)
	wordlist = fixupfunc(words);
	return lookup_nouns(wordlist);
end

function lookup_nouns_all_in_room(words)
	return lookup_nouns_fixup(words, fixup_all_in_room);
end

function lookup_nouns_all_holding(words)
	return lookup_nouns_fixup(words, fixup_all_holding);
end

function lookup_nouns_all_holding_or_here(words)
	return lookup_nouns_fixup(words, fixup_all_holding_or_here);
end

function take_object(entry)
	-- entry is a table { "noun", object };

	if entry[2] == nil then
		io.write(entry[1] .. ": I don't know about that.\n");
		return;
	end
	if entry[2].location == "pocket" then
		io.write(entry[1] .. ": You already have that.\n");
		return;
	end
	if not entry[2].location == current_location then
		io.write(entry[1] .. ": I don't see that here.\n");
		return;
	end
	if not entry[2].portable then
		io.write(entry[1] .. ": I can't seem to take it.\n");
		return;
	end
	entry[2].location = "pocket";
	io.write(entry[1] .. ": Taken.\n");
end

function drop_object(entry)
	-- entry is a table { "noun", object };
	if entry[2] == nil then
		io.write(entry[1] .. ": I do not know what that is.\n");
		return;
	end
	if not entry[2].location == "pocket" then
		io.write(entry[1] .. ": You don't have that.\n");
		return;
	end
	entry[2].location = current_location;
	io.write(entry[1] .. ": Dropped.\n");
end

function examine_object(entry)
	-- entry is a table { "noun", object };
	if entry[2] == nil then
		io.write(entry[1] .. ": I do not know what that is.\n");
		return;
	end
	if entry[2].location ~= "pocket" and entry[2].location ~= current_location then
		io.write(entry[1] .. ": That is not here.\n");
		return;
	end
	if entry[2].examine == nil then
		io.write(entry[1] .. ": You do not see anything special about that.\n");
		return;
	end
	io.write(entry[1] .. ": " .. entry[2].examine .. "\n");
end;

function dotake(words)
	totake = lookup_nouns_all_in_room(cdr(words));
	if table_empty(totake) then
		io.write("You need to tell me what to take.\n");
		return;
	end
	map(take_object, totake);
end

function dodrop(words)
	todrop = lookup_nouns_all_holding(cdr(words));
	if table_empty(todrop) then
		io.write("You will need to tell me what to drop.\n");
		return;
	end
	map(drop_object, todrop);
end

function doexamine(words)
	tox = lookup_nouns_all_holding_or_here(cdr(words));
	if table_empty(tox) then
		io.write("You will need to tell me what to examine.\n");
		return;
	end
	map(examine_object, tox);
end

function not_implemented(w)
	io.write(w[1], " is not yet implemented.\n");
end

function execute_command(cmd)
	if cmd == "" then
		return
	end
	words = strsplit(cmd, " ,.;");
	if verb[words[1]] == nil then
		io.write("I don't understand what you mean by '" .. words[1] .. "'\n");
		return;
	end
	verb[words[1]][1](words);
end

function dolisten()
	io.write("You hear the faint hum of space machinery.\n");
end

function do_exit()
	time_to_quit = true;
end

function print_room_description(loc, obj)
	local foundone = false
	if not room[loc].visited then
		io.write(room[loc].shortdesc .. "\n\n");
		io.write(room[loc].desc .. "\n\n");
		for k, v in pairs(obj) do
			if v.location == loc then
				if not foundone then
					io.write("You see:\n");
					foundone = true;
				end
				io.write("   " .. v.desc .. "\n");
			end
		end
	end
	room[loc].visited = true;
end

verb = {
		go = { dogo },
		take = { dotake },
		get = { dotake },
		drop = { dodrop },
		look = { dolook },
		examine = { doexamine },
		x = { doexamine },
		inventory = { doinventory },
		i = { doinventory },
		listen = { dolisten },
		quit = { do_exit },
};

room = {
	maintenance_room = {
			shortdesc = "Maintenance Room",
			desc = "You are in the maintenance room.  The floor is covered\n" ..
				"in some kind of grungy substance.  A control panel is on the\n" ..
				"wall.  A door leads out into a corridor to the south\n",
			south = "corridor",
			visited = false,
		},
	corridor = {
			shortdesc = "Corridor",
   			desc = "You are in a corridor.  To the east is the bridge.  To the\n" ..
				"west is the hold.  A doorway on the north side of the corridor\n" ..
				   "leads into the maintenance room.\n",
			north = "maintenance_room",
			visited = false,
		},
	pocket = {
			shortdesc = "pocket",
			desc = "pocket",
			visited = false,
		},
};

objects = {
	knife = { location = "pocket", name = "knife", desc = "a small pocket knife", portable=true },
	mop = { location = "maintenance_room", name = "mop", desc = "a mop", portable=true },
	bucket = { location = "maintenance_room", name = "bucket", desc = "a bucket", portable=true },
	panel = { location = "maintenance_room", name = "panel", desc = "a control panel", portable=false },
	substance = { location = "maintenance_room", name = "substance", desc = "some kind of grungy substance", portable=false,
			examine = "the grungy substance looks extremely unpleasant.", },
};

canonical_directions = { "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest", "up", "down" };
everything = { "all", "everything", };

function gameloop()
	while not time_to_quit do
		print_room_description(current_location, objects)
		io.write("> ");
		command = io.read("*line");
		execute_command(command);
	end
end

gameloop();

