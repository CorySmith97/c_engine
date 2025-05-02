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

## Editor Settings (config_editor.json)

``` json
{
    "mode": This is the default serialization mode. Generally should be JSON,
    "starting_level": Name of level you want to default load when you run the program
}
```
