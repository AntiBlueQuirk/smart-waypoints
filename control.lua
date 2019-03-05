local config = {
	disable_on_error    = false, -- If true, stops that cause errors will be renamed to disable them.
	trains_can_print    = true,  -- If true, orders will have access to print.
	bad_index_is_error  = false, -- If true, if an order tries to jump to an non-existent order, it counts as an error.
	debug_orders        = true,  -- If true, orders will indicate status and action whenever they run.
	delimiter           = "/",   -- The prefix and separator to use for smart waypoint orders.
	disable_prefix      = "# ",  -- The prefix added to a station name to disable it.
}

local function lookup_value(tab, val)
    for k, v in pairs(tab) do
        if v == val then
            return k
        end
    end
    return nil
end

--script.on_event({defines.events.on_gui_click},
--   function (e)
--		for index, player in pairs(game.connected_players) do  --loop through all online players on the server
--			player.print("on_gui_click: "..serpent.block(e))
--		end
--   end
--)
--script.on_event({defines.events.on_gui_opened},
--   function (e)
--		for index, player in pairs(game.connected_players) do  --loop through all online players on the server
--			player.print("on_gui_opened: "..serpent.block(e))
--		end
--   end
--)
--script.on_event({defines.events.on_train_changed_state},
--   function (e)
--		e.name = nil; e.tick = nil
--		e.old_state = lookup_value(defines.train_state, e.old_state)
--		for index, player in pairs(game.connected_players) do  --loop through all online players on the server
--			player.print("on_train_changed_state: "..serpent.block(e))
--		end
--   end
--)
--script.on_event({defines.events.on_train_schedule_changed},
--   function (e)
--		e.name = nil; e.tick = nil
--		for index, player in pairs(game.connected_players) do  --loop through all online players on the server
--			player.print("on_train_schedule_changed: "..serpent.block(e))
--		end
--   end
--)


local train_states = nil

function init_train_states()
	if train_states == nil then
		train_states = {}
		for _,surf in pairs(game.surfaces) do
			for _,lt in pairs(surf.get_trains()) do
				table.insert(train_states, make_train_state(lt))
			end
		end
	end
end
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
local train_genv =
{
	assert   = assert,   error = error, ipairs = ipairs, pairs    = pairs,
	next     = next,     pcall = pcall, select = select, tonumber = tonumber,
	tostring = tostring,
	string = {
		byte   = string.byte  , char = string.char, find    = string.find   , format = string.format,
		gmatch = string.gmatch, gsub = string.gsub, len     = string.len    , lower  = string.lower ,
		match  = string.match , rep  = string.rep , reverse = string.reverse, sub    = string.sub   ,
		upper  = string.upper ,
	},
	table = {
		insert = table.insert, maxn = table.maxn , remove = table.remove, sort = table.sort,
	},
	math = {
		abs   = math.abs  , acos = math.acos, asin  = math.asin , atan   = math.atan  ,
		atan2 = math.atan2, ceil = math.ceil, cos   = math.cos  , cosh   = math.cosh  ,
		deg   = math.deg  , exp  = math.exp , floor = math.floor, fmod   = math.fmod  ,
		frexp = math.frexp, huge = math.huge, ldexp = math.ldexp, log    = math.log   ,
		log10 = math.log10, max  = math.max , min   = math.min  , modf   = math.modf  ,
		pi    = math.pi   , pow  = math.pow , rad   = math.rad  , random = math.random,
		sin   = math.sin  , sinh = math.sinh, sqrt  = math.sqrt , tan    = math.tan   ,
		tanh  = math.tanh ,
	},
}
function get_train_name(lt)
	local locos = lt.locomotives
	if #locos.front_movers > 0 then
		return locos.front_movers[1].backer_name
	elseif #locos.back_movers > 0 then
		return locos.back_movers[1].backer_name
	end
	return "Train "..lt.id
end

function make_train_state(lt)
	local ts = {
		train = lt,
		luae = nil,
		last_si = lt.schedule and lt.schedule.current,
		last_station = nil,
		fstate = nil,
	}
	return ts
end
function trainfs_get_contents(ts)
	if not ts.fstate then ts.fstate = {} end
	if not ts.fstate.contents then
		ts.fstate.contents = ts.train.get_contents()
	end
end
function trainfs_get_fluid_contents(ts)
	if not ts.fstate then ts.fstate = {} end
	if not ts.fstate.fluid_contents then
		ts.fstate.fluid_contents = ts.train.get_fluid_contents()
	end
end
function trainfs_get_fuel_contents(ts)
	if not ts.fstate then ts.fstate = {} end
	if not ts.fstate.fuel_contents then
		local locos = ts.train.locomotives
		local counts = {}
		
		for _,loco in ipairs(locos.front_movers) do
			local inv = loco.get_inventory(defines.inventory.fuel)
			for item,inum in pairs(inv.get_contents()) do
				if counts[item] then
					counts[item] = counts[item] + inum
				else
					counts[item] = inum
				end
			end
		end
		
		ts.fstate.fuel_contents = counts
	end
end
function trainfs_get_passengers(ts)
	if not ts.fstate then ts.fstate = {} end
	if not ts.fstate.passengers then
		local psg = {}
		for _,v in ipairs(ts.train.passengers) do
			psg[v.name] = true
		end
		ts.fstate.passengers = psg
	end
end
function trainfs_get_last_station_ent(ts)
	if not ts.fstate then ts.fstate = {} end
	if not ts.fstate.last_station_ent then
		ts.fstate.last_station_ent = find_nearby_stop_with_name(ts.train.front_stock.surface, ts.train.front_stock.position, ts.last_station)
	end
end
function trainfs_get_last_station_signals(ts)
	trainfs_get_last_station_ent(ts)
	if not ts.fstate.last_station_signals and ts.fstate.last_station_ent then
		ts.fstate.last_station_signals = ts.fstate.last_station_ent.get_merged_signals()
	end
end

function train_print(ts, ...)
	local args = {...}
	local str = nil
	local first = true
	for _,v in ipairs(args) do
		if str == nil then
			str = tostring(v)
		else
			str = str .. "\t" .. tostring(v)
		end
	end
	local front = ts.train.front_stock
	if front ~= nil then
		local name = get_train_name(ts.train)
		for _, player in pairs(front.force.players) do  --loop through all online players on the server
			player.print("[Smart Waypoints] ".. name .. " says: "..str)
		end
	end
end
function train_item_count(ts, search)
	trainfs_get_contents(ts)
	if search == nil then
		local count = 0
		for item,inum in pairs(ts.fstate.contents) do
			count = count + inum
		end
		return count
	else
		return ts.fstate.contents[search] or 0
	end
	return 0
end
function train_fluid_count(ts, search)
	trainfs_get_fluid_contents(ts)
	if search == nil then
		local count = 0
		for item,inum in pairs(ts.fstate.fluid_contents) do
			count = count + inum
		end
		return count
	else
		return ts.fstate.fluid_contents[search] or 0
	end
end
function train_fuel_count(ts, search)
	trainfs_get_fuel_contents(ts)
	if search == nil then
		local count = 0
		for item,inum in pairs(ts.fstate.fuel_contents) do
			count = count + inum
		end
		return count
	else
		return ts.fstate.fuel_contents[search] or 0
	end
	return 0
end
function train_signal(ts, search)
	trainfs_get_last_station_signals(ts)
	
	if ts.fstate.last_station_signals then
		if search == nil then
			local count = 0
			for _,sig in pairs(ts.fstate.last_station_signals) do
				count = count + sig.count
			end
			return count
		else
			for _,sig in pairs(ts.fstate.last_station_signals) do
				if sig.signal.name == search then
					return sig.count
				end
			end
		end
	end
	return 0
end
function train_passengers(ts, search)
	trainfs_get_passengers(ts)
	if search == nil then
		local count = 0
		for psg,_ in pairs(ts.fstate.passengers) do
			count = count + 1
		end
		return count
	else
		return ts.fstate.passengers[search] and 1 or 0
	end
	return 0
end
function make_train_luae(ts)
	local env = deepcopy(train_genv)
	if config.trains_can_print then
		env.print       = function(...) train_print(ts, ...) end
	end
	env.item_count  = function(search) return train_item_count(ts, search) end
	env.fluid_count = function(search) return train_fluid_count(ts, search) end
	env.fuel_count  = function(search) return train_fuel_count(ts, search) end
	env.signal      = function(search) return train_signal(ts, search) end
	env.passengers  = function(search) return train_passengers(ts, search) end
	return env
end
function train_update_luae(ts)
	--ts.luae.name  = ts.train.backer_name
	ts.luae.id    = ts.train.id
	ts.luae.speed = ts.train.speed * 216 -- 216 = 3.6*60; 3.6 km/h = 1 m/s, 60 m/s = 1 u/t
end

function find_stations(name)
	local found = {}
	for _,surf in pairs(game.surfaces) do
		for _,station in pairs(surf.find_entities_filtered{type="train-stop"}) do
			if station.backer_name == name then
				table.insert(found, station)
			end
		end
	end
	return found
end
function disable_stations(name)
	local new_name = "// "..name
	for _,station in ipairs(find_stations(name)) do
		station.backer_name = new_name
	end
end
function stop_error(stop_name, ts, str)
	if config.disable_on_error then
		disable_stations(stop_name)
		str = str .. "\nStops with this name disabled."
	end
	
	local front = ts.train.front_stock
	if front ~= nil then
		for _, player in pairs(front.force.players) do  --loop through all online players on the server
			player.print("[Smart Waypoints] \""..stop_name .. "\": "..str)
		end
	end
end
function find_next_station_with_name(sch, name, first)
	local records = sch.records
	for i = first, #records do
		if records[i].station == name then
			return i
		end
	end
	for i = 1, first-1 do
		if records[i].station == name then
			return i
		end
	end
	return nil
end
--note, this may fail
function find_nearby_stop_with_name(surf, pos, name)
	local range = 2
	local closest = nil
	local closestdsq = nil
	for _,e in pairs(surf.find_entities_filtered{
		area={{pos.x - range, pos.y - range}, {pos.x + range, pos.y + range}},
		type='train-stop',
	}) do
		if e.backer_name == name then
			local ep = e.position
			local dsq = {x = pos.x - ep.x, y = pos.y - ep.y}
			dsq = dsq.x * dsq.x + dsq.y * dsq.y
			if closest == nil or dsq < closestdsq then
				closest = e
				closestdsq = dsq
			end
		end
	end
	return closest
end

function do_stop_passed_logic(ts, old_si)
	local sch = ts.train.schedule
	local schc = #sch.records
	
	local old_stop = sch.records[old_si]
	local stop_name = old_stop.station
	local stop_namef = stop_name:sub(1,1)
	local direct_mode = false
	ts.last_station = stop_name
	
	--train_print(ts, "Left "..stop_name)
	--train_print(ts, "Last station: "..(ts.last_station or "nil"))
	if stop_namef == config.delimiter then
		local lua_start = stop_name:find(stop_namef, 2, true)
		
		if not lua_start then
			lua_start = #stop_name+1
			direct_mode = true
		end
		
		local param = stop_name:sub(2, lua_start-1)
		param = param:match('^%s*(.-)%s*$')
		local paramf = param:sub(1,1)
		
		local lua_str
		if not direct_mode then
			lua_str = stop_name:sub(lua_start+1)
			
			-- trim lua here
			if #lua_str == 0 then
				direct_mode = true
			else
				if lua_str:find("return", 1, true) then
					lua_str = "return (function()\n"..lua_str.."\nend)()"
				else
					lua_str = "return "..lua_str
				end
			end
		else
			lua_str = ""
		end
		
		local mode = 4
		local new_si = nil
		if #param == 0 then
			mode = 4 -- ``: expecting anything, do nothing
			new_si = 0 -- ignored, but must be non-nil
		elseif #param == 1 and paramf == "=" then
			mode = 0 -- `=`: expecting number, skip to absolute index returned
			new_si = 0 -- ignored, but must be non-nil
		elseif #param == 1 and paramf == "+" then
			mode = 1 -- `+`: expecting number, skip to relative index returned
			new_si = 0 -- ignored
		elseif paramf == "=" then
			mode = 2 -- `=X`: expecting boolean, if true, skip to absolute index X
			new_si = tonumber(param:sub(2))
		elseif paramf == "+" or paramf == "-" then
			mode = 3 -- `+X` or "-X": expecting boolean, if true, skip to relative index +-X
			new_si = tonumber(param:sub(2))
		elseif paramf == "'" then
			mode = 2 -- `'X`: expecting boolean, if true, skip to next station with name X; yes, we're just reusing mode 2 here.
			new_si = find_next_station_with_name(sch, param:sub(2), old_si)
			if new_si == nil then
				train_print(ts, "Can't find station in schedule named "..param:sub(2))
				new_si = 0
			end
		else
			mode = 2 -- `X`: abbreviation for `=X`
			new_si = tonumber(param)
		end
		if new_si == nil or (direct_mode and (mode == 0 or mode == 1)) then
			stop_error(stop_name, ts, "Invalid order action.")
		end
		
		if not ts.luae then
			ts.luae = make_train_luae(ts)
		end
		train_update_luae(ts)
		
		local okay, res
		
		if #lua_str > 0 then
			local lfunc = load(lua_str, "", "t", ts.luae)
			okay, res = pcall(lfunc)
		else
			okay, res = true, true
		end
		
		local orig_res = res
		if okay then
			if mode == 0 or mode == 1 then -- expecting number
				if type(res) ~= "number" then
					stop_error(stop_name, ts, "Expected lua to return number.")
				else
					if mode == 1 then
						res = res + old_si
						while res < 1    do res = res + schc end
						while res > schc do res = res - schc end
					end
					
					if res > 0 and res <= #sch.records then
						ts.train.go_to_station(res)
						ts.last_si = res
						if config.debug_orders then
							train_print(ts, stop_name.." returned "..tostring(orig_res)..": Skipped to "..res..".")
						end
					else
						if config.debug_orders then
							train_print(ts, stop_name.." returned "..tostring(orig_res)..": Can't skip to "..res..", bad index.")
						end
					end
				end
			elseif mode == 2 or mode == 3 then
				if res then
					res = new_si
					if mode == 3 then
						res = res + old_si
						while res < 1    do res = res + schc end
						while res > schc do res = res - schc end
					end
					
					if res > 0 and res <= #(sch.records) then
						ts.train.go_to_station(res)
						ts.last_si = res
						if config.debug_orders then
							train_print(ts, stop_name.." returned "..tostring(orig_res)..": Skipped to "..res..".")
						end
					else
						if config.bad_index_is_error then
							stop_error(stop_name, ts, "Train tried to go to bad index "..res..". (Action: "..param..")")
						elseif config.debug_orders then
							train_print(ts, stop_name.." returned "..tostring(orig_res)..": Can't skip to "..res..", bad index.")
						end
					end
				else
					if config.debug_orders then
						train_print(ts, stop_name.." returned "..tostring(orig_res)..": Not skipping.")
					end
				end
			elseif mode == 4 then
				if config.debug_orders then
					train_print(ts, stop_name.." returned "..tostring(orig_res)..".")
				end
			end -- else mode == 4
		else
			stop_error(stop_name, ts, "Error running lua: \""..res.."\".")
		end
	end
end

function do_train_check(ts)
	local sch = ts.train.schedule
	if sch then
		local new_si = sch.current
		local old_si = ts.last_si
		if not old_si then
			ts.last_si = new_si
		elseif new_si and new_si ~= old_si then
			ts.last_si = new_si
			
			do_stop_passed_logic(ts, old_si)
		end
	end
	
	if ts.fstate then ts.fstate = nil end
end

script.on_event({defines.events.on_train_created},
   function (e)
		table.insert(train_states, make_train_state(e.train))
   end
)
script.on_event({defines.events.on_tick},
	function (e)
		init_train_states()
		
		local compact = false
		for _,ts in ipairs(train_states) do
			if not ts.train.valid then
				compact = true
			else
				do_train_check(ts)
			end
		end
		
		if compact then
			local new_trains = {}
			
			for _,ts in ipairs(train_states) do
				if ts.train.valid then
					table.insert(new_trains, ts)
				end
			end
			train_states = new_trains
		end
	end
)