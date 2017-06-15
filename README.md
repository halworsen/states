## ![states](https://github.com/Atebite/states)

states is a statemachine for making garry's mod gamemodes that hopefully makes organizing the code a little easier

## how does it work?

when you switch between states the statemachine redefines the gamemode hooks to use the hooks that are specific to the current gamestate. this way you can have multiple different gamemode hooks for different gamestates.

gamestate hooks are "second priority", meaning that if the original gamemode hook returns a value, the gamestate hook for that hook won't run.

so using this you could, for example, have a regular gamemode hook for scoreboard drawing that is used all the time, but a custom HUD paint for each individual gamestate

## cool, how do i use this thing?

first, drop states.lua in your root gamemode folder

in your gamemode's init.lua file, do this:

```lua
AddCSLua("states.lua")

states.switch_state("initialstate")
```


in your gamemode's shared.lua file, do this:

```lua
include("states.lua")

states.init()
```
**make sure you call states.init() after you've defined all the game*mode* hooks, as they are cached by states when you initialize it**


write your code in the respective gamestate files. hook the code by using states.add_state_hook(game_state, name, func)

e.g.
```lua
local function HUDPaint()
	...
end
states.add_state_hook("pregame", "HUDPaint", HUDPaint)
```


switch between gamestates using `states.switch_state(new_state)`

## how's the folder structure?

states.lua needs to be in your root gamemode folder

i.e.
`gamemodes/yourgamemode/gamemode/states.lua`


the "states" folder needs to be inside the root gamemode folder along with states.lua

i.e.
`gamemodes/yourgamemode/gamemode/states`


inside states, put your gamestate folders with their respective files

e.g.
```
gamemodes/yourgamemode/gamemode/states/pregame/cl_pregame.lua
gamemodes/yourgamemode/gamemode/states/pregame/sv_pregame.lua


gamemodes/yourgamemode/gamemode/states/endgame/cl_endgame.lua
gamemodes/yourgamemode/gamemode/states/endgame/sh_endgame.lua
gamemodes/yourgamemode/gamemode/states/endgame/sv_endgame.lua
```

## anything else?

states adds "3" new regular hooks:
* StateEnter_*statename*
* StateExit_*statename*
* StateSwitch

the actual name of the first two hooks will vary depending on the gamestate. if you switch from a gamestate called *pregame* to *playing*, StateEnter_playing and StateExit_pregame would be called along with StateSwitch, which passes two args, the old and the new state (in that order). when the gamestate changes, these hooks are always called in the following order: StateExit, StateSwitch, StateEnter. use these hooks for code that needs to be executed before you exit the gamestate or immediately after entering a gamestate. stateswitch is for code which should be executed on an arbitrary gamestate change.