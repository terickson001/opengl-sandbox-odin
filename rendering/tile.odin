package rendering

import "core:fmt"
import "core:os"
import "core:math/rand"

import "shared:gl"
import "../util"

Tile_Descriptor :: struct
{
    tile: u8,
    variant: u8,
}

Tile_Map :: struct
{
    set: ^Tile_Set,
    tiles: [][]Tile_Descriptor,
}

Tile_Set :: struct
{
    atlas: Texture,
    tiles: []Tile,
}

Tile :: struct
{
    dims: [2]f32,
    name: string,
    
    variants: []Tile_Variant,
    variant_cdf: []f32,
}

Tile_Variant :: struct
{
    uv: [2]f32,
    weight: f32,
}

load_tileset :: proc(filepath: string) -> (tileset: Tile_Set)
{
    filebuf, ok := os.read_entire_file(filepath);
    file := string(filebuf);
    if !ok
    {
        fmt.eprintf("Could not open tileset %q\n", filepath);
        os.exit(1);
    }
    
    atlas_file: string;
    if !util.read_fmt(&file, "%F%>", &atlas_file)
    {
        fmt.eprintf("Failed to load tileset atlas for '%s'(%s)\n", filepath, atlas_file);
        os.exit(1);
    }
    tileset.atlas = image_texture(atlas_file);
    
    num_tiles: int;
    if !util.read_fmt(&file, "%d%>", &num_tiles)
    {
        fmt.eprintf("Could not get tile count in tileset %q\n", filepath);
        os.exit(1);
    }
    
    tileset.tiles = make([]Tile, num_tiles);
    
    for t, idx in &tileset.tiles
    {
        if !util.read_fmt(&file, "%s%>", &t.name)
        {
            fmt.eprintf("Could not get tile name for tile #%d in tileset %q\n", idx, filepath);
            os.exit(1);
        }
        
        if !util.read_fmt(&file, "%f%_%f%>", &t.dims.x, &t.dims.y)
        {
            fmt.eprintf("Could not get tile dimensions for tile %q in tileset %q\n", t.name, filepath);
            os.exit(1);
        }
        
        num_variants: int;
        if !util.read_fmt(&file, "%d%>", &num_variants)
        {
            fmt.eprintf("Couldn't get number of tile variants for tile %q in tileset %q\n", t.name, filepath);
            os.exit(1);
        }
        
        t.variants = make([]Tile_Variant, num_variants);
        t.variant_cdf = make([]f32, num_variants);
        weight_total: f32;
        for v, vidx in &t.variants
        {
            if !util.read_fmt(&file, "%f%_%f%_%f%>", &v.uv.x, &v.uv.y, &v.weight)
            {
                fmt.eprintf("Could not get tile variant #%d for tile %q in tileset %q\n", vidx, t.name, filepath);
                os.exit(1);
            }
            v.uv = v.uv / [2]f32{f32(tileset.atlas.width), f32(tileset.atlas.height)};
            weight_total += v.weight;
            t.variant_cdf[vidx] = v.weight;
            if vidx > 0
            {
                t.variant_cdf[vidx] += t.variant_cdf[vidx-1];
            }
        }
        
        if weight_total-0.0001 > 1.0
        {
            fmt.eprintf("Variant weights for tile %q exceed 1.0(%f) in tileset %q\n", t.name, weight_total, filepath);
            os.exit(1);
        }
    }
    
    return tileset;
}

load_tilemap :: proc(filepath: string) -> (tilemap: Tile_Map)
{
    filebuf, ok := os.read_entire_file(filepath);
    file := string(filebuf);
    if !ok
    {
        fmt.eprintf("Could not open tilemap %q\n", filepath);
        os.exit(1);
    }
    
    w, h: int;
    if !util.read_fmt(&file, "%d%_%d%>", &w, &h)
    {
        fmt.eprintf("%s: Could not get tilemap dimensions\n", filepath);
        os.exit(1);
    }
    
    tilemap.tiles = make([][]Tile_Descriptor, h);
    for y in 0..<h
    {
        tilemap.tiles[y] = make([]Tile_Descriptor, w);
        for x in 0..<w
        {
            if !util.read_fmt(&file, "%d%_", &tilemap.tiles[y][x].tile)
            {
                fmt.eprintf("%s:, Could not get tile (%d, %d)\n", filepath, x, y);
                os.exit(1);
            }
            
        }
        util.read_fmt(&file, "%>");
    }
    
    return tilemap;
}

init_variants :: proc(tilemap: ^Tile_Map, tileset: ^Tile_Set)
{
    tilemap.set = tileset;
    for row in &tilemap.tiles
    {
        for col in &row
        {
            if len(tileset.tiles[col.tile].variants) > 1
            {
                choice := rand.float32_range(0, 1);
                vidx := 0;
                for choice > tileset.tiles[col.tile].variant_cdf[vidx] 
                {
                    vidx += 1;
                }
                col.variant = u8(vidx);
            }
        }
    }
}

draw_tilemap :: proc(shader: ^Shader, ctx: ^Context, tilemap: ^Tile_Map, origin: [2]f32, scale: [2]f32)
{
    vertices := make([dynamic][3]f32);
    uvs := make([dynamic][2]f32);
    
    atlas_dimensions := [2]f32{f32(tilemap.set.atlas.width), f32(tilemap.set.atlas.height)};
    pos := origin;
    for row in tilemap.tiles
    {
        for col in row
        {
            append(&vertices, [3]f32{pos.x,         pos.y,         0});
            append(&vertices, [3]f32{pos.x+scale.x, pos.y+scale.y, 0});
            append(&vertices, [3]f32{pos.x,         pos.y+scale.y, 0});
            
            append(&vertices, [3]f32{pos.x,         pos.y,         0});
            append(&vertices, [3]f32{pos.x+scale.x, pos.y,         0});
            append(&vertices, [3]f32{pos.x+scale.x, pos.y+scale.y, 0});
            
            tile := &tilemap.set.tiles[col.tile];
            uv_origin := tile.variants[col.variant].uv;
            uv_max := uv_origin + ([2]f32{f32(tile.dims.x), f32(tile.dims.y)} / atlas_dimensions);
            
            append(&uvs, [2]f32{uv_origin.x, uv_origin.y});
            append(&uvs, [2]f32{uv_max.x,    uv_max.y   });
            append(&uvs, [2]f32{uv_origin.x, uv_max.y   });
            
            append(&uvs, [2]f32{uv_origin.x, uv_origin.y});
            append(&uvs, [2]f32{uv_max.x,    uv_origin.y});
            append(&uvs, [2]f32{uv_max.x,    uv_max.y   });
            pos.x += scale.x;
        }
        pos.x = origin.x;
        pos.y += scale.y;
    }
    
    bind_context(ctx);
    update_vbo(ctx, 0, vertices[:]);
    update_vbo(ctx, 1, uvs[:]);
    
    // gl.UseProgram(shader.id);
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, tilemap.set.atlas.id);
    
    set_uniform(shader, "diffuse_sampler", 0);
    
    gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)));
    
    delete(vertices);
    delete(uvs);
}

Voxel_Descriptor :: struct
{
    pos: [2]u32,
    face: Tile_Descriptor,
}

Voxel_Cluster :: struct
{
    set: ^Tile_Set,
    tiles: []Voxel_Descriptor,
}

Baked_Voxel_Cluster :: struct
{
    set: ^Tile_Set,
    mesh: Mesh,
}
