package rendering

import "../util"
import "shared:gl"

import "core:math/linalg"
import "core:fmt"
import "core:os"

// @todo(Tyler): near-far plane calculation

MAX_POINT_LIGHTS :: 16;
POINT_SHADOW_RES :: 1024;

point_depth_maps: u32;
point_depth_maps_bitmap: util.Bitmap;
point_depth_map_fbo: u32;
Light :: struct
{
    pos: [3]f32,
    color: [3]f32,
    power: f32,
    extent: f32,
    depth_index: i32,
}

init_depth_maps :: proc()
{
    gl.GenTextures(1, &point_depth_maps);
    gl.BindTexture(gl.TEXTURE_CUBE_MAP_ARRAY, point_depth_maps);
    gl.TexImage3D(gl.TEXTURE_CUBE_MAP_ARRAY, 0, gl.DEPTH_COMPONENT, i32(POINT_SHADOW_RES), i32(POINT_SHADOW_RES), i32(MAX_POINT_LIGHTS*6), 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil);
    
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP_ARRAY, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);
    
    gl.GenFramebuffers(1, &point_depth_map_fbo);
    gl.BindFramebuffer(gl.FRAMEBUFFER, point_depth_map_fbo);
    gl.FramebufferTexture(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, point_depth_maps, 0);
    gl.DrawBuffer(gl.NONE);
    gl.ReadBuffer(gl.NONE);
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
    
    point_depth_maps_bitmap = util.make_bitmap(MAX_POINT_LIGHTS);
}

make_light :: proc(pos := [3]f32{0,0,0}, color := [3]f32{1, 1, 1}, power := f32(1)) -> (light: Light)
{
    light.pos = pos;
    light.color = color;
    light.power = power;
    light.extent = 25.0;
    light.depth_index = -1;
    
    return light;
}

add_light :: proc(using light: ^Light)
{
    idx, ok := util.bitmap_find_first(&point_depth_maps_bitmap, true);
    if !ok
    {
        fmt.eprintf("ERROR: Out of point light cubemaps\n");
        os.exit(1);
    }
    util.bitmap_set(&point_depth_maps_bitmap, idx);
    depth_index = i32(idx);
}

remove_light :: proc(using light: ^Light)
{
    if depth_index < 0 do return;
    util.bitmap_clear(&point_depth_maps_bitmap, u64(depth_index));
    depth_index = -1;
}

start_point_depth_pass :: proc(s: ^Shader)
{
    gl.UseProgram(s.id);
    
    gl.Viewport(0, 0, i32(POINT_SHADOW_RES), i32(POINT_SHADOW_RES));
    gl.BindFramebuffer(gl.FRAMEBUFFER, point_depth_map_fbo);
    gl.Clear(gl.DEPTH_BUFFER_BIT);
}

setup_light_pass :: proc(light: Light, s: ^Shader)
{
    proj := linalg.matrix4_perspective(linalg.radians(f32(90.0)), 1, 0.1, light.extent);
    pos := cast(linalg.Vector3)light.pos;
    matrices: [6]linalg.Matrix4;
    matrices[0] = linalg.matrix_mul(proj, linalg.matrix4_look_at(pos, pos + { 1, 0, 0}, { 0,-1, 0}));
    matrices[1] = linalg.matrix_mul(proj, linalg.matrix4_look_at(pos, pos + {-1, 0, 0}, { 0,-1, 0}));
    matrices[2] = linalg.matrix_mul(proj, linalg.matrix4_look_at(pos, pos + { 0, 1, 0}, { 0, 0, 1}));
    matrices[3] = linalg.matrix_mul(proj, linalg.matrix4_look_at(pos, pos + { 0,-1, 0}, { 0, 0,-1}));
    matrices[4] = linalg.matrix_mul(proj, linalg.matrix4_look_at(pos, pos + { 0, 0, 1}, { 0,-1, 0}));
    matrices[5] = linalg.matrix_mul(proj, linalg.matrix4_look_at(pos, pos + { 0, 0,-1}, { 0,-1, 0}));
    set_uniform(s, "shadow_matrices", matrices);
    
    set_uniform(s, "far_plane", light.extent);
    set_uniform(s, "light_pos", light.pos);
    set_uniform(s, "depth_index", light.depth_index);
}