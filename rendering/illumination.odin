package rendering

import "shared:gl"

import "core:math/linalg"

Shadowmap :: struct
{
    tex: u32,
    fbo: u32,
    res: u32,
}

Light :: struct
{
    pos: [3]f32,
    color: [3]f32,
    pow: f32,
    extent: f32,
    
    shadowmap: Shadowmap,
}

init_shadowmap :: proc(light: ^Light, shadow_res: u32)
{
    using light.shadowmap;
    
    light.extent = 25.0;
    res = shadow_res;
    
    gl.GenTextures(1, &tex);
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, tex);
    for i in 0..<6
    {
        gl.TexImage2D(u32(gl.TEXTURE_CUBE_MAP_POSITIVE_X + i), 0, gl.DEPTH_COMPONENT, i32(res), i32(res), 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil);
    }
    
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);
    
    gl.GenFramebuffers(1, &fbo);
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.FramebufferTexture(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, tex, 0);
    gl.DrawBuffer(gl.NONE);
    gl.ReadBuffer(gl.NONE);
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
}

setup_shadowmap :: proc(light: Light, s: ^Shader)
{
    using light.shadowmap;
    
    gl.UseProgram(s.id);
    
    gl.Viewport(0, 0, i32(res), i32(res));
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.Clear(gl.DEPTH_BUFFER_BIT);
    
    proj := linalg.matrix4_perspective(linalg.radians(f32(90.0)), 1, 1, light.extent);
    pos := cast(linalg.Vector3)light.pos;
    matrices: [6]linalg.Matrix4;
    matrices[0] = proj * linalg.matrix4_look_at(pos, pos + { 1, 0, 0}, { 0,-1, 0});
    matrices[1] = proj * linalg.matrix4_look_at(pos, pos + {-1, 0, 0}, { 0,-1, 0});
    matrices[2] = proj * linalg.matrix4_look_at(pos, pos + { 0, 1, 0}, { 0, 0, 1});
    matrices[3] = proj * linalg.matrix4_look_at(pos, pos + { 0,-1, 0}, { 0, 0,-1});
    matrices[4] = proj * linalg.matrix4_look_at(pos, pos + { 0, 0, 1}, { 0,-1, 0});
    matrices[5] = proj * linalg.matrix4_look_at(pos, pos + { 0, 0,-1}, { 0,-1, 0});
    set_uniform(s, "shadow_matrices", matrices);
    
    set_uniform(s, "far_plane", light.extent);
    set_uniform(s, "light_pos", light.pos);
}