package engine

import "core:fmt"
import "core:math"
import "core:math/linalg"

import "shared:gl"
import "shared:image"

import "core:strings"

Texture_Info :: struct
{
    width, height: u32,
    type: u32,
}

/*
Texture :: struct
{
    using info: Texture_Info,
    albedo:    u32,
    normal:    u32,
    metalness: u32,
    roughness: u32,
    ao:        u32,
}
*/

Texture :: struct
{
    id: u32,
    using info: Texture_Info,
}

color_texture :: proc(color: [4]f32, normalize: bool) -> Texture
{
    t := Texture{};
    gl.GenTextures(1, &t.id);
    gl.BindTexture(gl.TEXTURE_2D, t.id);
    
    scale := byte(normalize ? 255 : 1);
    c: [4]byte;
    for component, i in color do c[i] = byte(component)*scale;
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, &c[0]);
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.BindTexture(gl.TEXTURE_2D, 0);
    
    /*
        t.normal,    _ = image_texture("./res/normal_default.png");
        t.metalness, _ = image_texture("./res/metalness_default.png");
        t.roughness, _ = image_texture("./res/roughness_default.png");
        t.ao,        _ = image_texture("./res/ao_default.png");
        */
    
    t.info.width  = 1;
    t.info.height = 1;
    t.info.type   = gl.TEXTURE_2D;
    
    return t;
}

texture_palette :: proc(colors: [][4]f32, normalize: b32) -> Texture
{
    t := Texture{};
    gl.GenTextures(1, &t.id);
    gl.BindTexture(gl.TEXTURE_2D, t.id);
    
    size := 1;
    for len(colors) > size*size 
    {
        size = size *  2;
    }
    
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
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.GenerateMipmap(gl.TEXTURE_2D);
    gl.BindTexture(gl.TEXTURE_2D, 0);
    
    /*
        t.normal, _    = image_texture("./res/normal_default.png");
        t.metalness, _ = image_texture("./res/metalness_default.png");
        t.roughness, _ = image_texture("./res/roughness_default.png");
        t.ao, _        = image_texture("./res/ao_default.png");
        */
    
    t.info.width  = u32(size);
    t.info.height = u32(size);
    t.info.type   = gl.TEXTURE_2D;
    
    return t;
}

texture_palette_index :: proc(palette: Texture, i: int) -> [2]f32
{
    s := int(palette.info.width);
    coord := [2]f32{f32(i%s), f32(i/s)};
    uv := coord / f32(s);
    return uv;
}

image_texture :: proc{image_texture_from_mem, image_texture_from_file};
image_texture_from_image :: proc(img: image.Image) -> Texture
{
    if img.compression != .None 
    {
        return image_texture_from_image__compressed(img);
    }
    
    pixel_depth := img.depth == 16 ? 2 : 1;
    
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
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
    gl.GenerateMipmap(gl.TEXTURE_2D);
    
    gl.BindTexture(gl.TEXTURE_2D, 0);
    
    return Texture{texture_id, {img.width, img.height, gl.TEXTURE_2D}};
}

image_texture_from_image__compressed :: proc(img: image.Image) -> Texture
{
    texture_id: u32;
    gl.GenTextures(1, &texture_id);
    
    gl.BindTexture(gl.TEXTURE_2D, texture_id);
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
    
    block_size := u32(img.compression == .DXT1 ? 8 : 16);
    offset := u32(0);
    
    GL_COMPRESSED_RGBA_S3TC_DXT1_EXT :: 0x83F1;
    GL_COMPRESSED_RGBA_S3TC_DXT3_EXT :: 0x83F2;
    GL_COMPRESSED_RGBA_S3TC_DXT5_EXT :: 0x83F3;
    
    format: u32;
    #partial switch img.compression
    {
        case .DXT1: format = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
        case .DXT3: format = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
        case .DXT5: format = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
    }
    
    width := img.width;
    height := img.height;
    for level in 0..<(img.mipmap)
    {
        if width == 0 && height == 0 
        {
            break;
        }
        
        size := ((width+3)/4) * ((height+3)/4) * block_size;
        gl.CompressedTexImage2D(gl.TEXTURE_2D, i32(level), format,
                                i32(width), i32(height), 0, i32(size), &img.data[offset]);
        offset += size;
        width  /= 2;
        height /= 2;
        
        if width  < 1 do width  = 1;
        if height < 1 do height = 1;
    }
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
    
    gl.BindTexture(gl.TEXTURE_2D, 0);
    
    return Texture{texture_id, {img.width, img.height, gl.TEXTURE_2D}};
}

image_texture_from_mem :: proc(data: []byte) -> Texture
{
    img := image.load(data);
    defer delete(img.data);
    
    return image_texture_from_image(img);
}

image_texture_from_file :: proc(filepath: string) -> Texture
{
    fmt.printf("%q\n", filepath);
    img := image.load(filepath);
    defer delete(img.data);
    
    return image_texture_from_image(img);
}

destroy_texture :: proc(t: ^Texture)
{
    gl.DeleteTextures(1, &t.id);
}
