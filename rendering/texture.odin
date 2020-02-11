package rendering

import "core:fmt"
import "core:math"
import "core:math/linalg"

import "core:strings"
import "shared:gl"
import "shared:image"

Texture_Info :: struct
{
    width, height: u32,
    type: u32,
}

Texture :: struct
{
    using info: Texture_Info,
    diffuse:  u32,
    normal:   u32,
    specular: u32,
}

color_texture :: proc(color: [4]f32, normalize: bool) -> Texture
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

    t.normal, _   = image_texture("./res/normal_default.png");
    t.specular, _ = image_texture("./res/specular_default.png");

    t.info.width  = 1;
    t.info.height = 1;
    t.info.type   = gl.TEXTURE_2D;
    
    return t;
}

texture_palette :: proc(colors: [][4]f32, normalize: b32) -> Texture
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
    
    t.normal, _   = image_texture("./res/normal_default.png");
    t.specular, _ = image_texture("./res/specular_default.png");

    t.info.width  = u32(size);
    t.info.height = u32(size);
    t.info.type   = gl.TEXTURE_2D;
    
    return t;
}

texture_pallete_index :: proc(pallete: Texture, i: int) -> [2]f32
{
    s := int(pallete.info.width);
    coord := [2]f32{f32(i%s), f32(i/s)};
    uv := coord / f32(s);
    return uv;
}

image_texture :: proc(filepath: string) -> (u32, Texture_Info)
{
    img := image.load(filepath);

    pixel_depth := img.depth == 16 ? 2 : 1;
    if img.flipped.y
    {
        row_size := u32(img.width) * (u32(img.format) & 7) * u32(pixel_depth);
        end := row_size * img.height;
        swap := make([]byte, row_size);
        for row in 0..<(img.height/2)
        {
            a := img.data[row*row_size:(row+1)*row_size];
            b := img.data[end-(row+1)*row_size:end-row*row_size];
            copy(swap, a);
            copy(a, b);
            copy(b, swap);
        }
        delete(swap);
    }

    format := u32(gl.RGBA);
    iformat := u32(gl.RGBA8);
    
    switch img.format
    {
    case .RGB:
        format = gl.RGB;
        iformat = img.depth == 16 ? gl.RGB16 : gl.RGB8;
    case .RGBA:
        format = gl.RGBA;
        iformat = img.depth == 16 ? gl.RGBA16 : gl.RGBA8;
    case .GRAY:
        format = gl.RED;
        iformat = img.depth == 16 ? gl.R16 : gl.R8;
    case .GRAYA:
        format = gl.RG;
        iformat = img.depth == 16 ? gl.RG16 : gl.RG8;
    }

    type := u32(img.depth == 16 ? gl.UNSIGNED_SHORT : gl.UNSIGNED_BYTE);
    
    texture_id: u32;
    gl.GenTextures(1, &texture_id);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    gl.TexStorage2D(gl.TEXTURE_2D, 1, u32(iformat), i32(img.width), i32(img.height));
    gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, i32(img.width), i32(img.height), format, type, &img.data[0]);

    delete(img.data);
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
    gl.GenerateMipmap(gl.TEXTURE_2D);

    gl.BindTexture(gl.TEXTURE_2D, 0);

    return texture_id, {img.width, img.height, gl.TEXTURE_2D};
}

load_texture :: proc(diff, norm, spec: string) -> Texture
{
    t := Texture{};

    t.diffuse, t.info = image_texture(diff);
    if norm != "" do t.normal, _ = image_texture(norm);
    else          do t.normal, _ = image_texture("./res/normal_default.png");

    if spec != "" do t.specular, _ = image_texture(spec);
    else          do t.specular, _ = image_texture("./res/specular_default.png");

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
