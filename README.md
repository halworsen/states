## states

states is a statemachine for making garry's mod gamemodes that hopefully makes organizing the code a little easier

## how does it work?

when you switch between states the statemachine rewrites the gamemode hooks to use the hooks that are specific to the current gamestate. this way you can have multiple different gamemode hooks for different gamestates.

so using this you could, for example, have a regular gamemode hook for scoreboard drawing that is used all the time, but a custom HUD paint for each individual gamestate

## cool, how do i use this thing?

first of all, addcslua and include states.lua in your gamemode. **make sure that states.lua is included after all includes which have gamemode function definitions in them**. you also want to initialize/load all the gamestates by calling ```states.init()```

now make a folder called "states" in your root gamemode folder. inside that folder, create even more folders and start naming them by your gamestates. the folder names are what you'll be using in your code to refer to the gamestates. inside each gamestate folder, create cl_*statename*.lua, sh_*statename*.lua and sv_*statename*.lua for the gamestate.

start writing your code in those gamestate files. however, instead of writing gamemode functions (function GM:something() ... end) you write "normal" hooks, i.e. just normal functions that are hooked into the gamemode hooks, literally exactly the same as in the ```hook``` library. instead of using ```hook.Add```, you use ```states.add_state_hook(game_state, hook_name, hook_func)```

to switch between gamestates, use ```states.switch_state(new_state)```. you want to use this when initializing the gamemode, too, as states doesn't set a gamestate inside the ```init``` function.

other than that, you want to add ```states.handle_reload()``` to your GM:OnReloaded function so that states can tackle JIT reloads properly
```lua
function GM:OnReloaded()
	states.handle_reload()
end
```

```states.sync_player(ply)``` also needs to be added to GM:PlayerInitialSpawn to sync new players
```lua
function GM:PlayerInitialSpawn(ply)
	states.sync_player(ply)
end
```

## anything else?

states adds "3" new regular hooks:
* StateEnter_*statename*
* StateExit_*statename*
* StateSwitch

the actual name of the first two hooks will vary depending on the gamestate. if you switch from a gamestate called *pregame* to *playing*, StateEnter_playing and StateExit_pregame would be called along with StateSwitch, which passes two args, the old and the new state (in that order). when the gamestate changes, these hooks are always called in the following order: StateExit, StateSwitch, StateEnter. use these hooks for code that needs to be executed before you exit the gamestate or immediately after entering a gamestate. stateswitch is for code which should be executed on an arbitrary gamestate change.