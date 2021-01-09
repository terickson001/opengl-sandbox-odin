package asset

import "core:runtime"
import "core:os"
import "core:fmt"
import "core:strings"
import "shared:heimdall"

import render "../rendering"
import model "model"
import "../util"

import "shared:image"

Catalog :: struct
{
    root: string,
    assets: map[string]^Asset,
    allocator: runtime.Allocator,
    watcher: heimdall.Watcher,
}

global_catalog: Catalog;

make_catalog :: proc(root: string = "./", allocator := context.allocator) -> (c: Catalog)
{
    c.root = root;
    c.allocator = allocator;
    c.assets = make(T=map[string]^Asset, allocator=allocator);
    c.watcher = heimdall.init_watcher(allocator);
    
    return c;
}

Asset :: struct
{
    file: string,
    time: u64,
    
    variant: Asset_Variant,
}

Asset_Test   :: proc(data: []byte, filepath: string, ext: string) -> bool;
Asset_Load   :: proc(data: []byte, filepath: string, ext: string) -> ^Asset;
Asset_Delete :: proc(asset: ^Asset);

/*
Asset_Handler :: struct
{
    test   : proc(data: []byte, filepath: string, ext: string) -> bool;
    load   : proc(data: []byte, filepath: string, ext: string) -> ^Asset;
    delete : proc(asset: ^Asset);
}
*/

Asset_Variant :: union {
    Shader,
    Texture,
    Mesh,
    Material,
}

Shader :: struct
{
    program: render.Shader,
    depends: []^Asset,
}

Texture :: struct
{
    texture: render.Texture,
}

Mesh :: struct
{
    mesh: render.Mesh,
}

Material :: struct
{
    material: render.Material,
}

load :: proc(using c: ^Catalog, filepath: string) -> bool
{
    asset, ok := load_generic(filepath);
    if !ok do return false;
    
    asset.file = strings.clone(filepath, c.allocator);
    file_time, _ := os.last_write_time_by_name(filepath); // @todo(Tyler): Setup cross-platform file watch
    asset.time = u64(file_time);
    
    alloc_path := strings.clone(filepath, c.allocator);
    assets[alloc_path] = new_clone(asset, c.allocator);
    heimdall.watch_file(&c.watcher, filepath, {.Modify}, reload, c, alloc_path);
    return true;
}

load_generic :: proc(filepath: string) -> (Asset, bool)
{
    ext := util.ext(filepath);
    data, ok := os.read_entire_file(filepath);
    defer delete(data);
    if !ok
    {
        fmt.eprintf("Could not open asset file %q\n", filepath);
        return Asset{}, false;
    }
    
    asset: Asset;
    switch
    {
        case shader_test(data, filepath, ext):  asset = load_shader(data, filepath, ext);
        case mesh_test(data, filepath, ext):    asset = load_mesh(data, filepath, ext);
        case texture_test(data, filepath, ext): asset = load_texture(data, filepath, ext);
        case: return Asset{}, false;
    }
    
    
    return asset, true;
}

reload :: proc(event: heimdall.Event, data: []any)
{
    assert(len(data) == 2);
    switch kind in data[0]
    {
        case: fmt.printf("data[0] type: %T\n", kind);
    }
    
    catalog := data[0].(^Catalog);
    asset_path := data[1].(string);
    #partial switch v in event.focus.variant
    {
        case heimdall.File_Focus:
        fullpath := fmt.tprintf("%s/%s", event.focus.directory, v.filename);
        ok: bool;
        asset: ^Asset;
        asset, ok = catalog.assets[asset_path];
        if !ok
        {
            fmt.eprintf("No asset %q loaded\n", asset_path);
            fmt.printf("%#v\n", catalog.assets);
            return;
        }
        
        new_asset: Asset;
        new_asset, ok = load_generic(fullpath);
        if !ok
        {
            fmt.eprintf("Could not load asset file %q\n", fullpath);
            return;
        }
        
        fmt.printf("Asset Hotloaded: %q\n", asset_path);
        asset^ = new_asset;
    }
}

get :: proc(using c: ^Catalog, path: string) -> ^Asset
{
    fmt.printf("Getting Asset %q\n", path);
    asset, ok := assets[path];
    if !ok
    {
        ok = load(c, path);
        if !ok
        {
            fmt.eprintf("Could not load asset %q\n", path);
            return nil;
        }
        asset = assets[path];
    }
    
    return asset;
}

register :: proc{register_material};

check_updates :: proc(using c: ^Catalog)
{
    heimdall.poll_events(&watcher);
}

// Shader
@private
shader_test :: proc(data: []byte, _: string, ext: string) -> bool
{
    switch ext
    {
        case "gl", "glsl": return true;
        case "": return false; // @todo(Tyler): Checks based on file contents
        case: return false;
    }
}

@private
load_shader :: proc(data: []byte, filepath: string, ext: string) -> Asset
{
    shader := render.load_shader_from_mem(data, filepath);
    
    shader_asset := Asset{};
    shader_asset.variant = Shader{shader, nil};
    
    return shader_asset;
}

get_shader :: proc(using c: ^Catalog, path: string) -> ^render.Shader
{
    asset := get(c, path);
    if asset == nil do return nil;
    
    shader_asset := &asset.variant.(Shader);
    if shader_asset == nil
    {
        fmt.eprintf("Asset %q is not a shader\n", path);
        return nil;
    }
    
    return &shader_asset.program;
}

@private
mesh_test :: proc(data: []byte, _: string, ext: string) -> bool
{
    switch ext
    {
        case "obj","fbx": return true; // @todo(Tyler): SUPPORT OTHER FORMATS
        case "": return false; // @todo(Tyler): Checks based on file contents
        case: return false;
    }
}

@private
load_mesh :: proc(data: []byte, filepath: string, ext: string) -> Asset
{
    mesh: render.Mesh;
    switch ext
    {
        case "obj": mesh = render.Mesh{model.load_obj_from_mem(data), {}};
        case "fbx": mesh = render.Mesh{model.load_fbx_from_mem(data).mesh, {}};
    }
    
    render.compute_tangent_basis(&mesh);
    render.index_mesh(&mesh);
    render.create_mesh_vbos(&mesh);
    mesh_asset := Asset{};
    mesh_asset.variant = Mesh{mesh};
    return mesh_asset;
}

get_mesh :: proc(using c: ^Catalog, path: string) -> ^render.Mesh
{
    asset := get(c, path);
    if asset == nil do return nil;
    
    mesh_asset := &asset.variant.(Mesh);
    if mesh_asset == nil
    {
        fmt.eprintf("Asset %q is not a mesh\n", path);
        return nil;
    }
    return &mesh_asset.mesh;
}

@private
texture_test :: proc(data: []byte, _: string, _: string) -> bool
{
    return image.get_type(data) != .Invalid;
}

@private
load_texture :: proc(data: []byte, filepath: string, ext: string) -> Asset
{
    tex := render.image_texture(data);
    
    tex_asset := Asset{};
    tex_asset.variant = Texture{tex};
    
    return tex_asset;
}

get_texture :: proc(using c: ^Catalog, path: string) -> ^render.Texture
{
    asset := get(c, path);
    if asset == nil do return nil;
    
    tex_asset := &asset.variant.(Texture);
    if tex_asset == nil
    {
        fmt.eprintf("Asset %q is not a texture\n", path);
        return nil;
    }
    return &tex_asset.texture;
}

get_material :: proc(using c: ^Catalog, name: string) -> ^render.Material
{
    asset := get(c, name);
    if asset == nil do return nil;
    
    mat_asset := &asset.variant.(Material);
    if mat_asset == nil
    {
        fmt.eprintf("Asset %q is not a material\n", name);
        return nil;
    }
    return &mat_asset.material;
}

register_material :: proc(using c: ^Catalog, material: render.Material, name: string) -> ^render.Material
{
    asset := new(Asset, c.allocator);
    asset.variant = Material{material};
    
    alloc_name := strings.clone(name, c.allocator);
    assets[alloc_name] = asset;
    
    mat_asset := &asset.variant.(Material);
    
    return &mat_asset.material;
}