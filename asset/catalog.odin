package asset

import "core:runtime"
import "core:os"
import "core:fmt"
import "core:strings"

import render "../rendering"
import "../util"

import "shared:image"

Catalog :: struct
{
    assets: map[string]^Asset,
    allocator: runtime.Allocator,
}

make_catalog :: proc(allocator := context.allocator) -> (c: Catalog)
{
    c.allocator = allocator;
    c.assets = make(T=map[string]^Asset, allocator=allocator);
    
    return c;
}

Asset :: struct
{
    file: string,
    time: u64,
    
    variant: Asset_Variant,
}

Asset_Test   :: proc(data: []byte, filepath: string, ext: string) -> bool;
Asset_Load   :: proc(data: []byte, filepath: string) -> ^Asset;
Asset_Delete :: proc(asset: ^Asset);

Asset_Variant :: union {
    Shader,
    Texture,
    Mesh,
}

Shader :: struct
{
    program: render.Shader,
    depends: []^Asset,
}

Texture :: struct
{
    texture: u32,
    info: render.Texture_Info,
}

Mesh :: struct
{
    mesh: render.Mesh,
}

load :: proc(using c: ^Catalog, filepath: string) -> bool
{
    ext := util.ext(filepath);
    name := util.name(filepath);
    data, ok := os.read_entire_file(filepath);
    if !ok
    {
        fmt.eprintf("Could not open asset file %q\n", filepath);
        return false;
    }
    
    asset: ^Asset;
    switch
    {
        case shader_test(data, filepath, ext):  asset = load_shader(data, filepath);
        case mesh_test(data, filepath, ext):    asset = load_mesh(data, filepath);
        case texture_test(data, filepath, ext): asset = load_texture(data, filepath);
        case: return false;
    }

    asset.file = strings.clone(filepath);
    file_time, _ := os.last_write_time_by_name(filepath); // @todo(Tyler): Setup cross-platform file watch
    asset.time = u64(file_time);
    
    assets[name] = asset;
    return true;
}

// Shader
@private
shader_test :: proc(data: []byte, _: string, ext: string) -> bool
{
    switch ext
    {
        case "gl", "glsl", "fs", "vs", "gs": return true;
        case "": return false; // @todo(Tyler): Checks based on file contents
        case: return false;
    }
}

@private
load_shader :: proc(data: []byte, filepath: string) -> ^Asset
{
    shader := render.load_shader_from_mem(data, filepath);

    shader_asset := new(Asset);
    shader_asset.variant = Shader{shader, nil};
    
    return shader_asset;
}

@private
mesh_test :: proc(data: []byte, _: string, ext: string) -> bool
{
    switch ext
    {
        case "obj": return true; // @todo(Tyler): SUPPORT OTHER FORMATS
        case "": return false; // @todo(Tyler): Checks based on file contents
        case: return false;
    }
}

@private
load_mesh :: proc(data: []byte, filepath: string) -> ^Asset
{
    mesh := render.load_obj_from_mem(data);

    mesh_asset := new(Asset);
    mesh_asset.variant = Mesh{mesh};

    return mesh_asset;
}

@private
texture_test :: proc(data: []byte, _: string, _: string) -> bool
{
    return image.get_type(data) != .Invalid;
}

@private
load_texture :: proc(data: []byte, filepath: string) -> ^Asset
{
    tex, info := render.image_texture(data);

    tex_asset := new(Asset);
    tex_asset.variant = Texture{tex, info};

    return tex_asset;
}
