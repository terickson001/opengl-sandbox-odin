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
     name      : string,
     repeat    : bool,
     length    : u8,
     key_count : u8,
     keys      : [16]Animation_Key,
}

Sprite :: struct
{
     atlas      : Texture,
     dim        : [2]f32,
     frame_time : f32,
     accum_time : f32,
     animations : map[string]^Animation,
     anim_frame : u16,
     curr_anim  : ^Animation,
     prev_anim  : ^Animation,
     key_index  : u8,
     shader     : Shader,
     
     ctx        : Context,
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
     
     s = make_sprite();
     
     atlas_file: string;
     if !util.read_fmt(&file, "%F%>", &atlas_file)
         {
         fmt.eprintf("Failed to load sprite '%s'(%s)\n", filepath, atlas_file);
         os.exit(1);
     }
     s.atlas = load_texture(atlas_file, {}, {});
     
     anim_name: string;
     anim: ^Animation;
     
     if !util.read_fmt(&file, "%f%_%f%>", &s.dim.x, &s.dim.y)
         {
         fmt.eprintf("%s: Sprite must declare dimensions after texture name\n", filepath);
         os.exit(1);
     }
     if !util.read_fmt(&file, "%f%>", &s.frame_time)
         {
         fmt.eprintf("%s: Sprite must declare frame_time after dimensions\n", filepath);
         os.exit(1);
     }
     s.frame_time = 1.0 / s.frame_time;
     
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
         anim.key_count = u8(idx);
         anim.name = anim_name;
         sprite_add_anim(&s, anim);
     }
     
     return s;
}

make_sprite :: proc() -> (s: Sprite)
{
     s.animations = make(map[string]^Animation);
     s.ctx = make_context(2, 0);
     
     return s;
}

sprite_add_anim :: proc(using s: ^Sprite, anim: ^Animation)
{
     s.animations[anim.name] = anim;
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

update_sprite :: proc(s: ^Sprite, dt: f32)
{
     s.accum_time += dt;
     advance := u16(s.accum_time / s.frame_time);
     s.anim_frame += advance;
     s.accum_time -= f32(advance) * s.frame_time;
     
     if s.anim_frame >= u16(s.curr_anim.length)
         {
         s.anim_frame -= u16(s.curr_anim.length);
         s.key_index = 0;
         if !s.curr_anim.repeat
             {
             s.curr_anim = s.prev_anim;
             s.prev_anim = nil;
         }
     }
     
     curr_key := &s.curr_anim.keys[s.key_index];
     next_key: ^Animation_Key;
     if s.key_index+1 < s.curr_anim.key_count do
         next_key = &s.curr_anim.keys[s.key_index+1];
     
     if s.anim_frame > u16(curr_key.active_frame) && next_key != nil &&
         s.anim_frame >= u16(next_key.active_frame) do
         s.key_index += 1;
     
}

draw_sprite :: proc(shader: ^Shader, s: ^Sprite, pos, scale: [2]f32)
{
     key := s.curr_anim.keys[s.key_index];
     vertices: [6][3]f32;
     uvs: [6][2]f32;
     
     scaled_dim := key.dim * scale;
     
     vertices[0] = {pos.x,              pos.y, 0};
     vertices[1] = {pos.x+scaled_dim.x, pos.y+scaled_dim.y, 0};
     vertices[2] = {pos.x,              pos.y+scaled_dim.y, 0};
     
     vertices[3] = vertices[0];
     vertices[4] = {pos.x+scaled_dim.x, pos.y, 0};
     vertices[5] = vertices[1];
     
     unit_uv  := key.uv  * {1.0/f32(s.atlas.width), 1.0/f32(s.atlas.height)};
     unit_dim := key.dim * {1.0/f32(s.atlas.width), 1.0/f32(s.atlas.height)};
     
     uvs[0] = unit_uv;
     uvs[1] = unit_uv + unit_dim;
     uvs[2] = {unit_uv.x, unit_uv.y+unit_dim.y};
     
     uvs[3] = uvs[0];
     uvs[4] = {unit_uv.x+unit_dim.x, unit_uv.y};
     uvs[5] = uvs[1];
     
     bind_context(&s.ctx);
     
     update_vbo(&s.ctx, 0, vertices[:]);
     update_vbo(&s.ctx, 1, uvs[:]);
     
     
     gl.ActiveTexture(gl.TEXTURE0);
     gl.BindTexture(gl.TEXTURE_2D, s.atlas.diffuse);
     
     set_uniform(shader, "diffuse_sampler", 0);
     
     gl.Enable(gl.BLEND);
     gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
     gl.DrawArrays(gl.TRIANGLES, 0, 6);
     gl.Disable(gl.BLEND);
}
