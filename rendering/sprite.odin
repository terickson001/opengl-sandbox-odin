package rendering

import "core:fmt"
import "core:os"

import "shared:gl"

Animation_Key :: struct
{
    active_frame : u8,
    uv, dim      : [2]f32,
}

Animation :: struct
{
    repeat : bool,
    length : u8,
    keys   : [16]Animation_Key,
}

Sprite :: struct
{
    atlas      : Texture,
    dim        : [2]f32,
    animations : map[string]Animation,
    anim_frame : u16,
    curr_anim  : ^Animation,
    prev_anim  : ^Animation,
    key_index  : u8,
    shader     : Shader,
    vbuff      : u32,
    uvbuff     : u32,
}

load_sprite :: proc(filepath: string) -> (s: Sprite)
{
    file := string(os.read_entire_file(filepath));

    s.animations = make(map[string]Animation);
    gl.GenBuffers(2, &s.vbuff);

    atlas_file: string;
    if !util.read_fmt(&file, "%F%>", &atlas_file)
    {
        fmt.eprintf("Failed to load sprite '%s'\n", filepath);
        os.exit(1);
    }
    s.atlas = image_texture(atlas_file, 0, 0);

    anim_name: string;
    anim: Animation:

    if !util.read_fmt(&file, "%f%_%f%>", &s.dims.x, &s.dims.y)
    {
        fmt.eprintf("%s: Sprite must declare dimensions after texture name\n", filepath);
        os.exit(1);
    }

    for util.read_fmt(&file, "%s%>", &anim_name)
    {
        using anim = Animation{};
        if !util.read_fmt(&file, "%B{repeat,norepeat}%>", &repeat)
        {
            fmt.eprintf("%s: Animation '%s' must declare 'repeat' or 'norepeat'\n", filepath, anim_name);
            os.exit(1);
        }

        if !util.read_fmt(&file, "%d%>", &length)
        {
            fmt.eprintf("%s: Animation '%s' must declare an animation length\n", filepath, anim_name);
            os.exit(1);
        }

        idx := 0;
        for util.read_fmt(&file, "%d%_", &keys[i].active_frame)
        {
            if !util.read_fmt(&file, "%f%_%f%_%f%_%f%>",
                              &keys[i].uv.x,  &keys[i].uv.y,
                              &keys[i].dim.x, &keys[i].dim.y)
            {
                fmt.eprintf("%s: '%s'(%d): Invalid UV or Dimensions\n", filepath, anim_name, i);
                os.exit(1);
            }
            i += 1;
        }
        sprite_add_anim(&s, anim_name, anim);
    }
}
