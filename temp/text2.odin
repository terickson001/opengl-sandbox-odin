package rendering

import "core:fmt"
import "core:os"

import "shared:gl"
import "shared:image"
import "shared:stb/stbtt"

@private
FONT_ROOT :: "./res/font";

Glyph_Metric :: stbtt.Packed_Char;
Size_Metric :: struct
{
    size: f32,
    ascent, descent, linegap: f32,
}

Font :: struct
{
    name: string,
    
    metrics: []Glyph_Metric,
    sizes:   []Size_Metric,
    
    width, height: int,
    bitmap: []byte,
    
    oversample: [2]int,
}

load_font :: proc(font_name: string, sizes: []int, codepoints: []rune, width := 2048) -> (font: Font)
{
    using stbtt;
    
    over_sample := [2]int{2, 2};
    
    ttf, ok := os.read_entire_file(fmt.tprintf("%s/%s", FONT_ROOT, font_name));
    if !ok
    {
        fmt.eprintf("ERROR: Could not open file %q", font_name);
        return;
    }
    defer delete(ttf);
    
    size_est := 0;
    for s in sizes do
        size_est += s*s;
    size_est *= over_sample.x * over_sample.y * len(codepoints);
    
    height := size_est / width;
    bmp := make([]byte, width*height);
    defer delete(bmp);
    
    metrics := make([]Glyph_Metric, len(sizes)*len(codepoints));
    
    pack_ranges := make([]Pack_Range, len(sizes));
    for _, i in sizes do
        pack_ranges[i] = Pack_Range{
        cast(f32) sizes[i], 0,
        cast(^i32)&codepoints[0],
        cast(i32) len(codepoints),
        &metrics[i*len(codepoints)],
        0, 0};
    
    ctx, _ := pack_begin(bmp, width, height, 0, 1);
    pack_set_oversampling(&pc, oversample[0], oversample[1]);
    pack_font_ranges(&pc, ttf, 0, pack_ranges);
    pack_end(&pc);
    
    size_metrics := make([]Size_Metric, len(sizes));
    info: Font_Info;
    init_font(&info, ttf, get_font_offset_for_index(ttf, 0));
    for _, i in sizes
    {
        using size_metric := &size_metrics[i];
        
        scale := scale_for_pixel_height(&info, f32(sizes[i]));
        a, d, l := get_font_v_metrics(&info);
        
        ascent  = f32(a)*scale;
        descent = f32(d)*scale;
        linegap = f32(l)*scale;
        size    = f32(sizes[i]);
    }
    
    max_y := 0;
    for _, i in sizes do
        for _, j in codepoints do
        max_y = max(max_y, int(metrics[i*len(codepoints)+j].y1));
    
    max_y += 1;
    
    font: Font;
    font.width = width;
    font.height = max_y;
    font.glyph_metrics = metrics;
    font.size_metrics = size_metrics;
    font.oversample = oversample;
    
    font.name = strings.clone(identifier);
    
    font.codepoints = make([]rune, len(codepoints));
    font.codepoints_are_sorted = true;
    font.codepoints_are_dense = true;
    for _, i in codepoints {
		font.codepoints[i] = codepoints[i];
		if i > 0 && codepoints[i] < codepoints[i-1] do font.codepoints_are_sorted = false;
		if i > 0 && codepoints[i] != codepoints[i-1] + 1 do font.codepoints_are_dense = false;
	}
    
    font.bitmap = make([]byte, width*max_y);
    copy(font.bitmap, bmp);
    
    return font;
}
bisect :: proc(data: []rune, value: rune) -> int {
	start := 0;
	stop := len(data)-1;
	
	// test for invalid data
	if len(data) == 0 do return -1;
	if value < data[start] do return -1;      // out of bounds
	if value > data[stop] do return -1;       // out of bounds
	if data[stop] < data[start] do return -1; // definitely not sorted
    
	// special cases
	if value == data[start] do return start;
	if value == data[stop] do return stop;
    
	// iterate
	for start <= stop {
		mid := (start + stop)/2;
		if value == data[mid] {
			return mid;
		} else if value < data[mid] {
			stop = mid - 1;
		} else {
			start = mid + 1;
		}
	}
    
	// not found
	return -1;
}

draw_text :: proc(s: ^Shader, font: ^Font, text: string, pos: [2]f32, size: int)
{
    if len(text) == 0 do
        return;
    pos := pos;
    
    sidx := -1;
    size := Size_Metric(nil);
    for _, i in font.sizes do
    {
        if int(font.sizes[i].size+0.5) == size
        {
            sidx = i;
            size = &font.sizes[i];
            break;
        }
    }
    if size == nil do return;
    
    vertices := make([dynamic][2]f32);
    uvs      := make([dynamic][3]f32);
    defer
    {
        delete(vertices);
        delete(uvs);
    }
    
    min_x = pos.x;
    for c, i in text
    {
        if 32 > c || c > 128 do
            continue;
        
        if c == '\n'
        {
            pos.x = min_x;
            pos.y += size.ascent - size.descent + size.linegap;
            continue;
        }
        
        index = -1;
        switch
        {
            case font.codepoints_are_dense:
            if int(c - codepoints[0]) >= 0 && int(c - codepoints[0]) < len(codepoints) do
                index = sidx*len(codepoints) + int(c - codepoints[0]);
            
            case font.codepoints_are_sorted:
            if j := bisect(codepoints, c); j != -1 do
                index = sidx*len(codepoints) + j;
            
            case:
            for C, j in codepoints
            {
                if C == c
                {
                    index = sidx*len(codepoints) + j;
                    break;
                }
            }
        }
        
        if index == -1 do break;
        
        {
            g := &font.glyph_metrrics[index];
            x0 := pos.x + g.x0;
            x1 := pos.x + g.x1;
            y0 := pos.y + g.y0;
            y1 := pos.y + g.y1;
            
            ux0 := g.x0
        }
        pos.x += font.glyph_metrics[index].xadvance;
    }
}