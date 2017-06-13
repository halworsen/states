--[[
	SMERT(tm) statemachine for gamemodes and shit that follow a pregame>game>endgame progression

	state is changed via a function
	on enter or exit, a hook is called for that state

	statemachine first calls gamemode hooks (GM:houk), then the state hook

	important:
	the StateEntered hook is called on autorefresh
--]]

states = states or {}

local original_gamemode_hooks = original_gamemode_hooks or {}
for k,v in pairs(GM or GAMEMODE) do
	if isfunction(v) then
		original_gamemode_hooks[k] = v
	end
end

states.states = {
	"pregame",
	"playing",
	"endgame"
}
CURRENT_STATE = CURRENT_STATE or ""

states.hooks = states.hooks or {}
for k,game_state in pairs(states.states) do
	states.hooks[game_state] = {}
end

if SERVER then
	util.AddNetworkString("Statemachine_Stateswitch")
end

--[[
	Statemachine functions
--]]

function states.load_state_files()
	local path = "gamemodes/"..engine.ActiveGamemode().."/gamemode/statemachine/states"

	for k,game_state in pairs(states.states) do
		local folder_path = path.."/"..game_state

		-- because this is called from the init files, the include will be relative to the "root" gamemode folder
		local include_path = "statemachine/states/"..game_states.."/"

		if SERVER then
			assert(file.Exists(path, "GAME"), "states folder doesn't exist")
			assert(file.Exists(folder_path, "GAME"), "folder for gamestate "..game_states.." doesn't exist")

			-- add shared file for clients
			if file.Exists(folder_path.."/sh_"..game_states..".lua", "GAME") then
				AddCSLuaFile(include_path.."sh_"..game_states..".lua")
				--print("added state file sh_"..game_states..".lua to client")
			end
			
			-- add client file for clients
			if file.Exists(folder_path.."/cl_"..game_states..".lua", "GAME") then
				AddCSLuaFile(include_path.."cl_"..game_states..".lua")
				--print("added state file cl_"..game_states..".lua to client")
			end

			-- include sv file
			if file.Exists(folder_path.."/sv_"..game_states..".lua", "GAME") then
				include(include_path.."sv_"..game_states..".lua")
				--print("included state file sv_"..game_states..".lua")
			end

			-- include sh file
			if file.Exists(folder_path.."/sh_"..game_states..".lua", "GAME") then
				include(include_path.."sh_"..game_states..".lua")
			end
		else
			-- include cl and sh file
			-- file.exist doesnt work for files sent by server, so fuck
			-- gonna throw errors if they don't exist
			include(include_path.."cl_"..game_states..".lua")
			include(include_path.."sh_"..game_states..".lua")
			--print("included client and shared files")
		end
	end

	-- enter state #1
	if SERVER then
		states.switch_state(states.states[1])
	end
end

-- only the server can switch gamestate
-- when the state is switched, a net message is broadcast to sync everyone to the same gamestate
if SERVER then
	function states.switch_state(new_state)
		if new_state == CURRENT_STATE then return end

		local old_state = CURRENT_STATE

		hook.Call("StateExit_"..old_state)

		states.update_state_hooks(true)

		hook.Call("StateSwitch", nil, old_state, new_state)
		hook.Call("StateEnter_"..new_state)

		CURRENT_STATE = new_state

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
	-- this function is run both during setup and midgame, so try for both
	local gm_table = GM or GAMEMODE
	assert(gm_table, "gamemode table table is nil! (wtf?)")

	local hook_table = states.get_hook_table(CURRENT_STATE)

	if not hook_table then return end

	for name,func in pairs(hook_table) do
		local val = function(...)
			local res

			if original_gamemode_hooks[name] then
				res = original_gamemode_hooks[name](...)

				if res then return res end
			end

			res = func(...)

			if res then return res end
		end

		if clean then val = nil end

		gm_table[name] = val
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
	return assert(success, "state hook failed to run! ("..CURRENT_STATEs..","..name..")\n"..err)
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
	hook.Call("StateEnter_"..CURRENT_STATE)
	states.update_state_hooks()
end

--[[
	Statemachine syncing and shit
--]]

if SERVER then
	function states.sync_state()
		net.Start("Statemachine_Stateswitch")
			net.WriteString(CURRENT_STATE)
		net.Broadcast()
	end

	function states.sync_player(ply)
		net.Start("Statemachine_Stateswitch")
			net.WriteString(CURRENT_STATE)
		net.Send(ply)
	end
end

local function sync_state()
	local old_state = CURRENT_STATE
	local new_state = net.ReadString()

	hook.Call("StateExit_"..old_state)

	states.update_state_hooks(true)

	hook.Call("StateSwitch", nil, old_state, new_state)
	hook.Call("StateEnter_"..new_state)

	CURRENT_STATE = new_state

	states.update_state_hooks()
end
net.Receive("Statemachine_Stateswitch", sync_state)