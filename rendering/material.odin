package rendering

import "shared:gl"

Material_Component :: union
{
    ^Texture,
    [3]f32,
    f32,
}

Material :: struct
{
    albedo:    Material_Component,
    normal:    Material_Component,
    metalness: Material_Component,
    roughness: Material_Component,
    ao:        Material_Component,
    luminance: Material_Component,
    shaded:    bool,
}

set_material :: proc(s: ^Shader, m: ^Material)
{
    switch v in m.albedo
    {
        case ^Texture:
        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, v.id);
        set_uniform(s, "albedo_map", 0);
        set_uniform(s, "use_albedo_tex", true);
        
        case [3]f32:
        set_uniform(s, "albedo_const", v);
        set_uniform(s, "use_albedo_tex", false);
        
        case f32:
        set_uniform(s, "albedo_const", [3]f32{v,v,v});
        set_uniform(s, "use_albedo_tex", false);
    }
    
    #partial switch v in m.normal
    {
        case ^Texture:
        gl.ActiveTexture(gl.TEXTURE1);
        gl.BindTexture(gl.TEXTURE_2D, v.id);
        set_uniform(s, "normal_map", 1);
        set_uniform(s, "use_normal_tex", true);
        
        case [3]f32:
        set_uniform(s, "normal_const", v);
        set_uniform(s, "use_normal_tex", false);
    }
    
    #partial switch v in m.metalness
    {
        case ^Texture:
        gl.ActiveTexture(gl.TEXTURE2);
        gl.BindTexture(gl.TEXTURE_2D, v.id);
        set_uniform(s, "metalness_map", 2);
        set_uniform(s, "use_metalness_tex", true);
        
        case f32:
        set_uniform(s, "metalness_const", v);
        set_uniform(s, "use_metalness_tex", false);
    }
    
    #partial switch v in m.roughness
    {
        case ^Texture:
        gl.ActiveTexture(gl.TEXTURE3);
        gl.BindTexture(gl.TEXTURE_2D, v.id);
        set_uniform(s, "roughness_map", 3);
        set_uniform(s, "use_roughness_tex", true);
        
        case f32:
        set_uniform(s, "roughness_const", v);
        set_uniform(s, "use_roughness_tex", false);
    }
    
    #partial switch v in m.ao
    {
        case ^Texture:
        gl.ActiveTexture(gl.TEXTURE4);
        gl.BindTexture(gl.TEXTURE_2D, v.id);
        set_uniform(s, "ao_map", 4);
        set_uniform(s, "use_ao_tex", true);
        
        case f32:
        set_uniform(s, "ao_const", v);
        set_uniform(s, "use_ao_tex", false);
    }
    
    set_uniform(s, "shaded", m.shaded);
}

make_material :: proc(albedo    : Material_Component = [3]f32{1.0, 0.0, 1.0},
                      normal    : Material_Component = [3]f32{0.5, 0.5, 1.0},
                      metalness : Material_Component = 0.0,
                      roughness : Material_Component = 0.8,
                      ao        : Material_Component = 1.0,
                      luminance : Material_Component = 0.0,
                      shaded    : bool               = true) -> Material
{
    ret: Material;
    ret.albedo = albedo;
    ret.normal = normal;
    ret.metalness = metalness;
    ret.roughness = roughness;
    ret.ao = ao;
    ret.luminance = luminance;
    ret.shaded = shaded;
    
    return ret;
}