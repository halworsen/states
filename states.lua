--[[
	states
	https://github.com/Atebite/states

	statemachine for garry's mod gamemodes
--]]

states = states or {}

states.states = {}
states.CURRENT_STATE = states.CURRENT_STATE or ""
states.hooks = states.hooks or {}

if SERVER then
	util.AddNetworkString("States_Stateswitch")
end

--[[
	Statemachine functions
--]]

function states.init()
	states.original_gamemode_hooks = states.original_gamemode_hooks or {}
	for k,v in pairs(GM or GAMEMODE) do
		if isfunction(v) then
			states.original_gamemode_hooks[k] = v
		end
	end
	
	local path = GM.FolderName.."/gamemode/states"

	local found_files, found_dirs = file.Find(path.."/*", "LUA")

	for k,game_state in pairs(found_dirs) do
		table.Add(states.states, game_state)
		states.hooks[game_state] = {}

		local folder_path = path.."/"..game_state

		-- because this is called from the gamemode init files, the include will be relative to the "root" gamemode folder
		local include_path = "states/"..game_state.."/"

		local cl_exists = file.Exists(folder_path.."/cl_"..game_state..".lua", "LUA")
		local sh_exists = file.Exists(folder_path.."/sh_"..game_state..".lua", "LUA")

		if SERVER then
			assert(file.Exists(path, "LUA"), "states folder doesn't exist")

			local sv_exists = file.Exists(folder_path.."/sv_"..game_state..".lua", "LUA")

			-- add shared file for clients and include
			if sh_exists then
				AddCSLuaFile(include_path.."sh_"..game_state..".lua")
				include(include_path.."sh_"..game_state..".lua")
			end
			
			-- add client file for clients
			if cl_exists then
				AddCSLuaFile(include_path.."cl_"..game_state..".lua")
			end

			-- include sv file
			if sv_exists then
				include(include_path.."sv_"..game_state..".lua")
			end
		else
			-- include client files
			if cl_exists then
				include(include_path.."cl_"..game_state..".lua")
			end

			if sh_exists then
				include(include_path.."sh_"..game_state..".lua")
			end
		end
	end
end

-- only the server can switch gamestate
if SERVER then
	function states.switch_state(new_state)
		if new_state == states.CURRENT_STATE then return end

		local old_state = states.CURRENT_STATE

		hook.Call("StateExit_"..old_state)

		states.update_state_hooks(true)

		hook.Call("StateSwitch", nil, old_state, new_state)
		hook.Call("StateEnter_"..new_state)

		states.CURRENT_STATE = new_state

		states.update_state_hooks()
		states.sync_state()
	end
end

--[[
	State hook related stuff
--]]

-- initializes state hooks for a given state
-- also cleans up all state hooks if clean is passed
function states.update_state_hooks(clean)
	-- this function is (should be) run both during setup and midgame, so try for both
	local gm_table = GM or GAMEMODE
	assert(gm_table, "gamemode table is nil (wtf?)")

	local hook_table = states.get_hook_table(states.CURRENT_STATE)

	if not hook_table then return end

	for name,func in pairs(hook_table) do
		if clean then
			gm_table[name] = nil
		else
			local hook_func = function(...)
				local res

				if states.original_gamemode_hooks[name] then
					res = states.original_gamemode_hooks[name](...)

					if res then return res end
				end

				res = func(...)

				if res then return res end
			end

			gm_table[name] = hook_func
		end
	end
end

function states.get_hook_table(game_state)
	return states.hooks[game_state]
end

function states.get_state_hook(game_state, name)
	local hook_table = states.get_hook_table(game_state)

	return hook_table[name]
end

-- not really used because update_state_hooks sets the GM functions to the state hooks but whatever
function states.run_state_hook(name, ...)
	local state_hook = states.get_state_hook(name)

	local success, err = pcall(stat_hook, ...)
	return assert(success, "state hook failed to run ("..states.CURRENT_STATE..","..name..")\n"..err)
end

function states.add_state_hook(game_state, name, func)
	local hook_table = states.get_hook_table(game_state)

	hook_table[name] = func
end

function states.remove_state_hook(game_state, name)
	local hook_table = states.get_hook_table(game_state)

	hook_table[name] = nil
end

-- called on autorefresh/reload
function states.handle_reload()
	states.update_state_hooks(true)
	hook.Call("StateEnter_"..states.CURRENT_STATE)
	states.update_state_hooks()
end
hook.Add("OnReloaded", "StatesHandleReload", states.handle_reload)

--[[
	State syncing
--]]

if SERVER then
	function states.sync_state()
		net.Start("States_Stateswitch")
			net.WriteString(states.CURRENT_STATE)
		net.Broadcast()
	end

	function states.sync_player(ply)
		net.Start("States_Stateswitch")
			net.WriteString(states.CURRENT_STATE)
		net.Send(ply)
	end

	-- sync new players
	hook.Add("PlayerInitialSpawn", "StatesSyncNewPlayer", states.sync_player)
end

local function sync_state()
	local old_state = states.CURRENT_STATE
	local new_state = net.ReadString()

	hook.Call("StateExit_"..old_state)

	states.update_state_hooks(true)

	hook.Call("StateSwitch", nil, old_state, new_state)
	hook.Call("StateEnter_"..new_state)

	states.CURRENT_STATE = new_state

	states.update_state_hooks()
end
net.Receive("States_Stateswitch", sync_state)