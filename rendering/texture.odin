package rendering

using import "core:fmt"
using import "core:math"
import "core:strings"
import "shared:gl"

Texture_Info :: struct
{
    width, height: u32,
}

Texture :: struct
{
    using info: Texture_Info,
    diffuse:  u32,
    normal:   u32,
    specular: u32,
}

load_image :: proc(filepath: string) -> (u32, Texture_Info)
{
    dot := strings.last_index_byte(filepath, '.');
    ext := filepath[dot:];
    
    switch ext
    {
        case "DDS": return load_dds(filepath);
        case "tga": return load_tga(filepath);
        case "bmp": return load_bmp(filepath);
        case "png": return load_png(filepath);
        case: eprintf("File %q is of unsupported filetype \".%s\"\n", filepath, ext);
    }
    return 0, Texture_Info{};
}

color_texture :: proc(color: Vec4, normalize: bool) -> Texture
{
    t := Texture{};
    gl.GenTextures(1, &t.diffuse);
    gl.BindTexture(gl.TEXTURE_2D, t.diffuse);

    scale := byte(normalize ? 255 : 1);
    c: [4]byte;
    for component, i in color do c[i] = byte(component)*scale;
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, &c[0]);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    t.normal, _   = load_png("./res/normal_default.png");
    t.specular, _ = load_png("./res/specular_default.png");

    t.info.width  = 1;
    t.info.height = 1;
    return t;
}

texture_pallette :: proc(colors: []Vec4, normalize: b32) -> Texture
{
    t := Texture{};
    gl.GenTextures(1, &t.diffuse);
    gl.BindTexture(gl.TEXTURE_2D, t.diffuse);

    size := 1;
    for len(colors) > size*size do
        size = size *  2;
    
    data := make([]byte, size*size*4);
    scale := byte(normalize ? 255 : 1);
    for c, i in colors
    {
        data[i*4+0] = scale * byte(c.r);
        data[i*4+1] = scale * byte(c.g);
        data[i*4+2] = scale * byte(c.b);
        data[i*4+3] = scale * byte(c.a);
    }

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(size), i32(size), 0, gl.RGBA, gl.UNSIGNED_BYTE, &data[0]);
    delete(data);
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
    gl.GenerateMipmap(gl.TEXTURE_2D);
    gl.BindTexture(gl.TEXTURE_2D, 0);
    
    t.normal, _   = load_png("./res/normal_default.png");
    t.specular, _ = load_png("./res/specular_default.png");

    t.info.width  = u32(size);
    t.info.height = u32(size);
    
    return t;
}

texture_pallete_index :: proc(pallete: Texture, i: int) -> Vec2
{
    s := int(pallete.info.width);
    coord := Vec2{f32(i%s), f32(i/s)};
    uv := coord / f32(s);
    return uv;
}

load_texture :: proc(diff, norm, spec: string) -> Texture
{
    t := Texture{};

    t.diffuse, t.info = load_image(diff);

    if norm != "" do t.normal, _ = load_image(norm);
    else           do t.normal, _ = load_image("./res/normal_default.png");

    if spec != "" do t.specular, _ = load_image(spec);
    else           do t.specular, _ = load_image("./res/specular_default.png");

    return t;
}

activate_texture :: proc(s: Shader, t: Texture)
{
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, t.diffuse);
    gl.Uniform1i(s.uniforms.diffuse_sampler, 0);

    gl.ActiveTexture(gl.TEXTURE1);
    gl.BindTexture(gl.TEXTURE_2D, t.normal);
    gl.Uniform1i(s.uniforms.normal_sampler, 1);

    gl.ActiveTexture(gl.TEXTURE2);
    gl.BindTexture(gl.TEXTURE_2D, t.specular);
    gl.Uniform1i(s.uniforms.specular_sampler, 2);
}

disable_texture :: proc(s: Shader, t: Texture)
{
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    gl.ActiveTexture(gl.TEXTURE1);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    gl.ActiveTexture(gl.TEXTURE2);
    gl.BindTexture(gl.TEXTURE_2D, 0);
}

destroy_texture :: proc(t: ^Texture)
{
    gl.DeleteTextures(3, &t.diffuse);
}
