package rendering

import "core:fmt"
import "core:os"

import "shared:gl"
import "../util"

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
    animations : map[string]^Animation,
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
    filebuf, ok := os.read_entire_file(filepath);
    file := string(filebuf);
    if !ok
    {
        fmt.eprintf("Could not open file %q\n", filepath);
        os.exit(1);
    }
        
    s.animations = make(map[string]^Animation);
    gl.GenBuffers(2, &s.vbuff);

    atlas_file: string;
    if !util.read_fmt(&file, "%F%>", &atlas_file)
    {
        fmt.eprintf("Failed to load sprite '%s'\n", filepath);
        os.exit(1);
    }
    s.atlas = load_texture(atlas_file, string{}, string{});

    anim_name: string;
    anim: ^Animation;

    if !util.read_fmt(&file, "%f%_%f%>", &s.dim.x, &s.dim.y)
    {
        fmt.eprintf("%s: Sprite must declare dimensions after texture name\n", filepath);
        os.exit(1);
    }

    for util.read_fmt(&file, "%s%>", &anim_name)
    {
        anim = new(Animation);
        using anim;
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
        for util.read_fmt(&file, "%d%_", &keys[idx].active_frame)
        {
            if !util.read_fmt(&file, "%f%_%f%_%f%_%f%>",
                              &keys[idx].uv.x,  &keys[idx].uv.y,
                              &keys[idx].dim.x, &keys[idx].dim.y)
            {
                fmt.eprintf("%s: '%s'(%d): Invalid UV or Dimensions\n", filepath, anim_name, idx);
                os.exit(1);
            }
            idx += 1;
        }
        sprite_add_anim(&s, anim_name, anim);
    }

    return s;
}

make_sprite :: proc() -> (s: Sprite)
{
    s.animations = make(map[string]^Animation);
    gl.GenBuffers(2, &s.vbuff);

    return s;
}

sprite_add_anim :: proc(using s: ^Sprite, name: string, anim: ^Animation)
{
    s.animations[name] = anim;
}

sprite_set_anim :: proc(using s: ^Sprite, name: string)
{
    anim := animations[name];
    if !anim.repeat do
        if s.prev_anim == nil do
            s.prev_anim = s.curr_anim;
    else do
        s.prev_anim = nil;

    s.anim_frame = 0;
    s.curr_anim = anim;
    s.key_index = 0;
}

draw_sprite :: proc(shader: Shader, s: ^Sprite, pos, scale: [2]f32)
{
    if s.anim_frame == u16(s.curr_anim.length)
    {
        s.anim_frame = 0;
        s.key_index = 0;
        if !s.curr_anim.repeat
        {
            s.curr_anim = s.prev_anim;
            s.prev_anim = nil;
        }
    }

    if s.anim_frame > u16(s.curr_anim.keys[s.key_index].active_frame) &&
        s.anim_frame == u16(s.curr_anim.keys[s.key_index+1].active_frame) do
            s.key_index += 1;

    key := s.curr_anim.keys[s.key_index];
    vertices, uvs: [6][2]f32;
    
    scaled_dim := key.dim * scale;

    vertices[0] = {pos.x,              pos.y};
    vertices[1] = {pos.x+scaled_dim.x, pos.y+scaled_dim.y};
    vertices[2] = {pos.x,              pos.y+scaled_dim.y};
    
    vertices[3] = vertices[0];
    vertices[4] = {pos.x+scaled_dim.x, pos.y};
    vertices[5] = vertices[1];

    unit_uv  := key.uv  * {1.0/f32(s.atlas.width), 1.0/f32(s.atlas.height)};
    unit_dim := key.dim * {1.0/f32(s.atlas.width), 1.0/f32(s.atlas.height)};

    uvs[0] = unit_uv;
    uvs[1] = unit_uv + unit_dim;
    uvs[2] = {unit_uv.x, unit_uv.y+unit_dim.y};

    uvs[3] = uvs[0];
    uvs[4] = {unit_uv.x+unit_dim.x, unit_uv.y};
    uvs[5] = uvs[1];

    gl.BindBuffer(gl.ARRAY_BUFFER, s.vbuff);
    gl.BufferData(gl.ARRAY_BUFFER, 6*size_of([2]f32), &vertices[0], gl.STATIC_DRAW);

    gl.BindBuffer(gl.ARRAY_BUFFER, s.uvbuff);
    gl.BufferData(gl.ARRAY_BUFFER, 6*size_of([2]f32), &uvs[0], gl.STATIC_DRAW);

    gl.UseProgram(shader.id);
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, s.atlas.diffuse);

    gl.Uniform2i(shader.uniforms.resolution, 1024, 768);
    gl.Uniform1i(shader.uniforms.diffuse_sampler, 0);

    gl.EnableVertexAttribArray(0);
    gl.BindBuffer(gl.ARRAY_BUFFER, s.vbuff);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, nil);

    gl.EnableVertexAttribArray(1);
    gl.BindBuffer(gl.ARRAY_BUFFER, s.uvbuff);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 0, nil);

    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    gl.DrawArrays(gl.TRIANGLES, 0, 6);

    gl.Disable(gl.BLEND);

    gl.DisableVertexAttribArray(0);
    gl.DisableVertexAttribArray(1);

    /* printf("ANIM_FRAME: %d; KEY_INDEX: %d\n", s->anim_frame, s->key_index); */
    /* printf("CURR_ANIM: %p; PREV_ANIM: %p\n", s->curr_anim, s->prev_anim); */
    s.anim_frame += 1;
}
