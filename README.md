# c-engine

This is my personal engine.

The games meant to be made with this are strategy games 
similar to that of fire emblem. As of now the engine is based 
in 2d, but I want to bump that to 3d for a mixed experience.

## Main subsystems

- Windowing: Sokol-App
- Renderer: Sokol-GFX
- Audio: Sokol-audio
- Networking: steam_flat.h
- StoryDB: storydb-zig
- Serde: serde-zig
- Imgui: cimgui
- Editor: editor.zig 

/*
this may not happen.
- Scripting: lua-zig
*/

# IMPORTANT

dont run zig fmt. I have some custom formatting things that I much prefer
over the defaults zig formatting.

## Thoughts

I like the idea of very procedural code. Think heavy c style for everything. Im not perfect at doing this
as I still make heavy use of namespaces and methods attached to a struct. However I think it is better to 
generally have  data types and functions that change that data. 

## Editor Settings (config_editor.json)

``` json
{
    "mode": This is the default serialization mode. Generally should be JSON,
    "starting_level": Name of level you want to default load when you run the program
}
```


# Design

I have been given to thought a lot about the game design and direction I would like to go in. 
A game that is somewhere between fire emblem(GBA games), divinity original sin 2, and og baldur's gate,
with a multiplayer aspect to each person having their own pod/team so to speak. You build your team 
to accomplish certain things in a mission/level. You have many options to get through the game ideally. 
IE You can have pods based on destruction of buildings that allow you to make b-line cuts through a base,
however this is very noisey and will attract the enemies. Or you can go full stealth. Or even you have 
make one pod that is noisely going for a head on approach as the rest of the part sneaks through.
