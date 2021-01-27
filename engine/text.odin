package engine

import "core:fmt"
import "core:os"
import "core:strings"

import "shared:gl"
import "shared:image"

import "util"

Glyph_Metrics :: struct
{
    x0, y0  : f32,
    x1, y1  : f32,
    advance : f32,
}

Field_Info :: struct
{
    name        : [64]byte,
    glyph_count : int,
    size        : int,
    ascent      : f32,
    descent     : f32,
    
    metrics     : [96]Glyph_Metrics,
}

Font :: struct
{
    texture : Texture,
    ctx     : Render_Context,
    info    : Field_Info,
}

load_msdf_metrics :: proc(filepath: string) -> (info: Field_Info)
{
    file_buf, ok := os.read_entire_file(filepath);
    if !ok
    {
        fmt.eprintf("Could not open font file %q\n", filepath);
        os.exit(1);
    }
    file := string(file_buf);
    dir: string;
    if !util.read_fmt(&file, "%>%s%>", &dir)
    {
        fmt.eprintf("%s: Couldn't find font directory in metrics file\n", filepath);
        os.exit(1);
    }
    
    copy(info.name[:], dir);
    if !util.read_fmt(&file, "%d%>", &info.glyph_count)
    {
        fmt.eprintf("%s: Couldn't find glyph count in metrics file\n", filepath);
        os.exit(1);
    }
    if !util.read_fmt(&file, "%d%>", &info.size)
    {
        fmt.eprintf("%s: Couldn't find font size in metrics file\n", filepath);
        os.exit(1);
    }
    
    m: Glyph_Metrics;
    info.ascent  = f32(-info.size);
    info.descent = f32(+info.size);
    for i in 0..<(info.glyph_count)
    {
        m = Glyph_Metrics{};
        if !util.read_fmt(&file, "%f%_%f%_%f%_%f%_%f%>",
                          &m.x0, &m.y0, &m.x1, &m.y1, &m.advance)
        {
            fmt.eprintf("%s: Couldn't parse metrics for glyph '%c'\n", filepath, i+32);
            os.exit(1);
        }
        info.ascent  = max(info.ascent,  m.y1);
        info.descent = min(info.descent, m.y0);
        info.metrics[i] = m;
    }
    
    return info;
}

load_font :: proc(name: string) -> (font: Font)
{
    gl.ActiveTexture(gl.TEXTURE0);
    
    font.texture.info.width = 96;
    font.texture.info.height = 96;
    
    gl.GenTextures(1, &font.texture.id);
    gl.BindTexture(gl.TEXTURE_2D_ARRAY, font.texture.id);
    gl.TexStorage3D(gl.TEXTURE_2D_ARRAY, 1, gl.RGBA8, 96, 96, 96);
    
    for i in 32..<128
    {
        filepath := fmt.tprintf("%s_msdf/%d.png", name, i);
        img := image.load_from_file(filepath, .RGBA);
        
        if img.data == nil
        {
            fmt.eprintf("Could not open glyph for font %q\n", name);
            os.exit(1);
        }
        gl.TexSubImage3D(gl.TEXTURE_2D_ARRAY,
                         0, 0, 0, i32(i-32), 96, 96, 1, gl.RGBA, gl.UNSIGNED_BYTE, &img.data[0]);
        delete(img.data);
    }
    
    gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    
    font.ctx = make_render_context(2, 0);
    
    filepath := fmt.tprintf("%s_msdfmetrics", name);
    font.info = load_msdf_metrics(filepath);
    font.texture.info.type = gl.TEXTURE_2D_ARRAY;
    return font;
}

get_char_width :: proc(font: Font, c: byte, size: int) -> f32
{
    scale := f32(size) / (font.info.ascent - font.info.descent);
    if 32 <= c && c < 128 
    {
        return font.info.metrics[c-32].advance * scale;
    }
    return 0;
}

get_text_width :: proc(font: Font, text: string, size: int) -> (width: f32)
{
    if text == "" 
    {
        return;
    }
    
    scale := f32(size) / (font.info.ascent - font.info.descent);
    for c in text 
    {
        if 32 <= c && c < 128
        {
            width += font.info.metrics[c-32].advance * scale;
        }
    }
    
    return width;
}

draw_text :: proc(s: ^Shader, font: ^Font, text: string, pos: [2]f32, size: int)
{    
    if len(text) == 0 
    {
        return;
    }
    
    pos := pos;
    
    vertices := make([dynamic][2]f32);
    uvs      := make([dynamic][3]f32);
    
    defer
    {
        delete(vertices);
        delete(uvs);
    }
    
    scale := f32(size) / (font.info.ascent - font.info.descent);
    for c in text
    {
        if 32 > c || c > 128 
        {
            continue;
        }
        
        metrics := font.info.metrics[c-32];
        if c == 32
        {
            pos.x += metrics.advance * scale;
            continue;
        }
        
        x0 := pos.x + (metrics.x0 * scale);
        y0 := pos.y + (metrics.y0 * scale);
        x1 := pos.x + (metrics.x1 * scale);
        y1 := pos.y + (metrics.y1 * scale);
        
        ux0 := metrics.x0 / f32(font.info.size);
        uy0 := metrics.y0 / f32(font.info.size);
        ux1 := metrics.x1 / f32(font.info.size);
        uy1 := metrics.y1 / f32(font.info.size);
        
        
        append(&vertices, [2]f32{x0, y0});
        append(&vertices, [2]f32{x1, y0});
        append(&vertices, [2]f32{x0, y1});
        append(&vertices, [2]f32{x1, y1});
        append(&vertices, [2]f32{x0, y1});
        append(&vertices, [2]f32{x1, y0});
        
        append(&uvs, [3]f32{ux0, uy0, f32(c-32)});
        append(&uvs, [3]f32{ux1, uy0, f32(c-32)});
        append(&uvs, [3]f32{ux0, uy1, f32(c-32)});
        append(&uvs, [3]f32{ux1, uy1, f32(c-32)});
        append(&uvs, [3]f32{ux0, uy1, f32(c-32)});
        append(&uvs, [3]f32{ux1, uy0, f32(c-32)});
        
        pos.x += metrics.advance * scale;
    }
    
    gl.UseProgram(s.id);
    
    bind_render_context(&font.ctx);
    update_vbo(&font.ctx, 0, vertices[:]);
    update_vbo(&font.ctx, 1, uvs[:]);
    
    gl.Uniform2i(s.uniforms["resolution"], 1024, 768);
    
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D_ARRAY, font.texture.id);
    
    gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)));
}
