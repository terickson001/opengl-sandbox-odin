package rendering

import "core:fmt"
import "core:os"

import "shared:gl"
import "shared:image"
import "shared:stb/stbtt"

@private
FONT_ROOT :: "./res/font";

Glyph_Metric :: stbtt.Packed_Char;
Size_Metrics :: struct
{
    size: f32,
    ascent, descent, linegap: f32,
}

Font :: struct
{
    name: string,
    
    metrics: []Glyph_Metric,
    sizes:   []Size_Metrics,

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

    font.identifier = strings.clone(identifier);
    
    font.codepoints = make([]rune, len(codepoints));
    copy(font.codepoints, codepoints);

    font.bitmap = make([]byte, width*max_y);
    copy(font.bitmap, bmp);

    return font;
}
