package rendering
import "core:fmt"
import m "core:math"
import "shared:gl"
import "core:os"
import "core:mem"
import "core:strings"

load_bmp :: proc(filepath: string) -> (u32, Texture_Info)
{
    file, ok := os.read_entire_file(filepath);
    if !ok
    {
        fmt.eprintf("Image %q could not be opened\n", filepath);
        return 0, Texture_Info{};
    }
    
    if len(file) < 54 ||
        file[0] != 'B' || file[1] != 'M'
    {
        fmt.eprintf("Image %q is not a valid BMP\n", filepath);
        return 0, Texture_Info{};
    }

    data_pos   := (^i32)(&(file[0x0A]))^;
    image_size := (^i32)(&(file[0x22]))^;
    width      := (^i32)(&(file[0x12]))^;
    height     := (^i32)(&(file[0x16]))^;

    if image_size == 0 do image_size = width*height*3;
    if data_pos == 0   do data_pos = 54;

    data := file[data_pos:];
    // n_read, _ = os.read(file, data);
    // os.close(file);

    texture_id: u32;
    gl.GenTextures(1, &texture_id);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, i32(width), i32(height), 0, gl.BGR, gl.UNSIGNED_BYTE, &data[0]);
    // delete(data);
    delete(file);
    
    /* gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); */
    /* gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT); */
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    /* gl.GenerateMipmap(gl.TEXTURE_2D); */

    gl.BindTexture(gl.TEXTURE_2D, 0);

    info := Texture_Info{u32(width), u32(height)};

    return texture_id, info;
}

load_tga :: proc(filepath: string) -> (u32, Texture_Info)
{
    header: [18]byte;

    file, err := os.open(filepath);
    if err != 0
    {
        fmt.eprintf("Image %q could not be opened\n", filepath);
        return 0, Texture_Info{};
    }

    n_read, _ := os.read(file, header[:]);
    if n_read != 18
    {
        fmt.eprintf("Image %q is not a valid TGA\n", filepath);
        return 0, Texture_Info{};
    }

    id_length        := header[0x00];
    cmap_type        := header[0x01];
    image_type       := header[0x02];
    cmap_start       := (^u16)(&header[0x03])^;
    cmap_len         := (^u16)(&header[0x05])^;
    cmap_depth       := header[0x07];
    width            := (^u16)(&header[0x0C])^;
    height           := (^u16)(&header[0x0E])^;
    pixel_depth      := header[0x10];
    image_descriptor := header[0x11];

    RLE := bool(image_type & 0b1000);
    
    fmt.printf("======= Load TGA (%s) =======\n", filepath);
    fmt.printf("cmap_type: %d\n", cmap_type);
    fmt.printf("cmap_start: %d\n", cmap_start);
    fmt.printf("cmap_len: %d\n", cmap_len);
    fmt.printf("cmap_depth: %d\n", cmap_depth);

    fmt.printf("id_length: %d\n", id_length);
    fmt.printf("image_type: %d\n", image_type);
    fmt.printf("  RLE?: %s\n", RLE?"Yes":"No");
    fmt.printf("width: %d\n", width);
    fmt.printf("height: %d\n", height);
    fmt.printf("pixel_depth: %d\n", pixel_depth);
    fmt.printf("image_descriptor: %d\n", image_descriptor);
    fmt.printf("========================\n");

    pixel_depth_bytes := int(m.ceil(f32(pixel_depth)/8));
    cmap_depth_bytes  := int(m.ceil(f32(cmap_depth) /8));

    image_id := make([]byte, id_length);
    defer delete(image_id);
    if id_length > 0
    {
        n_read, _ = os.read(file, image_id);
        if n_read != int(id_length)
        {
            fmt.eprintf("Could not read image ID in TGA %q\n", filepath);
            return 0, Texture_Info{};
        }
    }

    cmap_data := make([]byte, int(cmap_len)*cmap_depth_bytes);
    defer delete(cmap_data);
    if cmap_type != 0
    {
        n_read, _ = os.read(file, cmap_data);
        if  n_read != len(cmap_data)
        {
            fmt.eprintf("Could not read colormap in TGA %q", filepath);
            return 0, Texture_Info{};
        }
    }

    raw_image_data := make([]byte, int(width)*int(height)*pixel_depth_bytes);
    image_size, _ := os.read(file, raw_image_data);
    if image_size == 0
    {
        fmt.eprintf("Could not read image data in TGA %q", filepath);
        return 0, Texture_Info{};
    }

    image_data := raw_image_data[:];
    defer delete(image_data);
    
    decoded_data_size := int(width*height)*pixel_depth_bytes;
    image_data_size: int;

    if cmap_type != 0 do
        image_data_size = int(width*height)*cmap_depth_bytes;
    else do
        image_data_size = int(decoded_data_size);

    texture_id: u32;
    gl.GenTextures(1, &texture_id);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    decoded_image_data: []byte;

    if RLE
    {
        decoded_image_data = make([]byte, decoded_data_size);
        pixel_count := 0;
        i := 0;
        decoded_index := 0;
        for pixel_count < int(width*height)
        {
            count := int(image_data[i]);
            i += 1;
            encoded := bool(count & 0x80);
            count &= 0x7F;
            if encoded
            {
                for j := 0; j < count + 1; j += 1
                {
                    mem.copy(&decoded_image_data[decoded_index], &image_data[i], int(pixel_depth_bytes));
                    decoded_index += int(pixel_depth_bytes);
                    pixel_count += 1;
                }
                i += int(pixel_depth_bytes);
            }
            else
            {
                for j in 0..count
                {
                    mem.copy(&decoded_image_data[decoded_index], &image_data[i], pixel_depth_bytes);
                    i += pixel_depth_bytes;
                    decoded_index += pixel_depth_bytes;
                    pixel_count += 1;
                }
            }
        }
        delete(image_data);
        image_data = decoded_image_data;
    }

    colormapped_image_data := make([]byte, image_data_size);
    result_depth := pixel_depth;
    if cmap_type != 0
    {
        colormapped_index := 0;
        for i in 0..<int(width*height)
        {
            mem.copy(&colormapped_image_data[colormapped_index],
                     &cmap_data[int(image_data[i*pixel_depth_bytes])*cmap_depth_bytes],
                     cmap_depth_bytes);
            colormapped_index += cmap_depth_bytes;
        }
        delete(image_data);
        image_data = colormapped_image_data;
        result_depth = cmap_depth;
    }

    fmt.printf("result_depth: %d\n",result_depth);
    switch result_depth
    {
        case 15: gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB5,
                               i32(width), i32(height), 0, gl.BGR,
                               gl.UNSIGNED_SHORT_1_5_5_5_REV, &image_data[0]);
        case 16: gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB5_A1,
                               i32(width), i32(height), 0, gl.BGRA,
                               gl.UNSIGNED_SHORT_1_5_5_5_REV, &image_data[0]);
        case 24: gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB8,
                               i32(width), i32(height), 0, gl.BGR,
                               gl.UNSIGNED_BYTE, &image_data[0]);
        case 32: gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8,
                               i32(width), i32(height), 0, gl.BGRA,
                               gl.UNSIGNED_BYTE, &image_data[0]);
        case: fmt.eprintf("Invalid color depth '%d' in TGA %q\n", result_depth, filepath);
        return 0, Texture_Info{};
    }
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
    gl.GenerateMipmap(gl.TEXTURE_2D);

    gl.BindTexture(gl.TEXTURE_2D, 0);

    info := Texture_Info{u32(width), u32(height)};

    return texture_id, info;
}

load_dds :: proc(filepath: string) -> (u32, Texture_Info)
{
    file, err := os.open(filepath);
    if err != 0
    {
        fmt.eprintf("Could not open image %q\n", filepath);
        return 0, Texture_Info{};
    }

    filecode: [4]byte;
    os.read(file, filecode[:]);
    if strings.string_from_ptr(&filecode[0], 4) != "DDS\x00"
    {
        fmt.eprintf("Image %q is not a valid DDS\n", filepath);
        return 0, Texture_Info{};
    }

    
    header: [124]byte;
    os.read(file, header[:]);

    height       := (^u32)(&header[0x08])^;
    width        := (^u32)(&header[0x0C])^;
    linear_size  := (^u32)(&header[0x10])^;
    mipmap_count := (^u32)(&header[0x18])^;
    four_cc      := (^u32)(&header[0x50])^;

    bufsize := mipmap_count > 1 ? linear_size * 2 : linear_size;
    buf := make([]byte, bufsize);
    defer delete(buf);
    os.read(file, buf);
    os.close(file);

    FOURCC_DXT1 :: 0x31545844;
    FOURCC_DXT3 :: 0x33545844;
    FOURCC_DXT5 :: 0x35545844;

    format: u32;
    switch four_cc
    {
    case FOURCC_DXT1: format = gl.COMPRESSED_RGBA_S3TC_DXT1_EXT;
    case FOURCC_DXT3: format = gl.COMPRESSED_RGBA_S3TC_DXT3_EXT;
    case FOURCC_DXT5: format = gl.COMPRESSED_RGBA_S3TC_DXT5_EXT;
    case: return 0, Texture_Info{};
    }

    texture_id: u32;
    gl.GenTextures(1, &texture_id);

    gl.BindTexture(gl.TEXTURE_2D, texture_id);
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);

    block_size := u32(four_cc == FOURCC_DXT1 ? 8 : 16);
    offset := u32(0);

    for level in 0..<(mipmap_count)
    {
        if width == 0 && height == 0 do
            break;
        
        size := ((width+3)/4) * ((height+3)/4) * block_size;
        gl.CompressedTexImage2D(gl.TEXTURE_2D, i32(level), format,
                                i32(width), i32(height), 0, i32(size), &buf[offset]);
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

    info := Texture_Info{width, height};
    return texture_id, info;
}

PNG :: struct
{
    filepath      : string,
    width, height : u32,
    depth         : byte,
    color         : byte,
    palette       : [256][4]byte,
    pal_len       : u32,
    has_trans     : bool,
    comp, filter  : byte,
    components    : u32,
    out_components: u32,
    pal_components: u32,
    interlace     : byte,
    data          : [dynamic]byte,
    out           : []byte,
}

_png_err :: proc(test: bool, file, message: string, loc := #caller_location) -> bool
{
    if test do
        fmt.eprintf("%#v: ERROR: %s: %s\n", loc, file, message);
    
    return test;
}

load_png :: proc(filepath: string) -> (texture_id: u32, info: Texture_Info)
{
    texture_id = 0;
    info = Texture_Info{};

    file, ok := os.read_entire_file(filepath);
    if _png_err(!ok, filepath, "Could not open file") ||
        _png_err(len(file) < 8, filepath, "Invalid PNG file")
    do return;

    signature := _read_sized(&file, u64);

    if _png_err(signature != 0xa1a0a0d474e5089, filepath, "Invalid PNG signature")
    do return;
    
    trns   := [3]byte{};
    trns16 := [3]u16{};

    p := PNG{};
    p.filepath = filepath;
    first := true;
    loop: for
    {
        chunk := _png_read_chunk(&file);
        chars := transmute([4]byte)chunk.type;
        fmt.printf("CHUNK: %c%c%c%c\n", chars[3], chars[2], chars[1], chars[0]);
        data_save := chunk.data;
        
        switch chunk.type
        {
        case PNG_IHDR:
            if _png_err(!first, filepath, "Multiple IHDR") ||
               _png_err(chunk.size != 13, filepath, "Invalid IHDR length")
            do return;

            p.width     = u32(_read_sized(&chunk.data, u32be));
            p.height    = u32(_read_sized(&chunk.data, u32be));
            p.depth     = _read_sized(&chunk.data, byte);
            p.color     = _read_sized(&chunk.data, byte);
            p.comp      = _read_sized(&chunk.data, byte);
            p.filter    = _read_sized(&chunk.data, byte);
            p.interlace = _read_sized(&chunk.data, byte);

            if _png_err(p.color > 6, filepath, "Invalid color type") ||
               _png_err(p.color == 1 || p.color == 5, filepath, "Invalid color type") ||
               _png_err(p.color == 3 && p.depth == 16, filepath, "Invalid color type")
            do return;

            if p.color == 3 do p.pal_components = 3;

            switch p.color
            {
            case 0: p.components = 1;
            case 2: p.components = 3;
            case 4: p.components = 2;
            case 6: p.components = 4;
            }
            
            if p.pal_components == 0
            {
                p.components = (p.color & 2 != 0 ? 3 : 1) + (p.color & 4 != 0 ? 1 : 0);
            }
            else
            {
                p.components = 1; // palette index
                
                if _png_err((1<<30) / p.width / 4 < p.height, filepath, "too large")
                do return;
            }

            fmt.printf("%#v\n", p);

        case PNG_PLTE:
            if _png_err(first, filepath, "First chunk not IHDR") ||
               _png_err(chunk.size > 256*3, filepath, "Invalid PLTE")
            do return;

            p.pal_len = chunk.size / 3;
            if _png_err(p.pal_len * 3 != chunk.size, filepath, "Invalid PLTE")
            do return;
            fmt.printf("pal_len: %d\n", p.pal_len);
            for i in 0..<(p.pal_len)
            {
                p.palette[i][0] = _read_sized(&chunk.data, byte);
                p.palette[i][1] = _read_sized(&chunk.data, byte);
                p.palette[i][2] = _read_sized(&chunk.data, byte);
                p.palette[i][3] = 255;
            }

        case PNG_tRNS:
            
            if _png_err(first, filepath, "First chunk not IHDR") ||
               _png_err(len(p.data) > 0, filepath, "tRNS after IDAT")
            do return;
            p.has_trans = true;
            if p.pal_components != 0
            {
                if _png_err(p.pal_len == 0, filepath, "tRNS before PLTE") ||
                   _png_err(chunk.size > p.pal_len, filepath, "Invalid tRNS")
                do return;

                p.pal_components = 4;
                for i in 0..<(chunk.size) do
                    p.palette[i][3] = _read_sized(&chunk.data, byte);
            }
            else
            {
                if _png_err(~p.components & 1 != 0, filepath, "tRNS with alpha channel") ||
                   _png_err(chunk.size != u32(p.components*2), filepath, "Invalid tRNS")
                do return;

                if p.depth == 16 do
                    for i in 0..<(p.components) do
                        trns16[i] = u16(_read_sized(&chunk.data, u16be));
                else do
                    for i in 0..<(p.components) do
                        trns[i] = byte(_read_sized(&chunk.data, u16be) & 255);
            }
            
        case PNG_IDAT:
            if _png_err(first, filepath, "First chunk not IHDR") do
                return;

            if p.data == nil do
                p.data = make([dynamic]byte);

            append(&p.data, ..chunk.data);
        

        case PNG_IEND:
            if _png_err(first, filepath, "First chunk not IHDR") ||
               _png_err(len(p.data) == 0, filepath, "No IDAT")
            do return;

            z_buff := _zlib_read_block(p.data[:]);
            _zlib_decompress(&z_buff);
            if _png_err(len(z_buff.out) == 0, filepath, "Error decompressing PNG")
            do return;
            
            delete(p.data);

            p.out_components = p.components;
            if p.has_trans do
                p.out_components += 1;
            
            p.out = _create_png(&p, z_buff.out[:], u32(len(z_buff.out)));
            delete(z_buff.out);

            if p.has_trans
            {
                if p.depth == 16 do
                    _png_compute_transparency16(&p, trns16);
                else do
                    _png_compute_transparency8(&p, trns);
            }

            if p.pal_components > 0 do
                _png_expand_palette(&p);

            break loop;

        case:
            if _png_err(first, filepath, "first not IHDR")
            do return;
            chars := transmute([4]byte)chunk.type;
            fmt.printf("Unsupported chunk type: %c%c%c%c\n", chars[3], chars[2], chars[1], chars[0]);
        }

        if first do first = false;
        
        delete(data_save);
    }

    // Flip Y-Axis
    pixel_depth := p.depth == 16 ? 2 : 1;
    row_size := u32(p.width) * u32(p.out_components) * u32(pixel_depth);
    end := row_size * p.height;
    swap := make([]byte, row_size);
    for row in 0..<(p.height/2)
    {
        a := p.out[row*row_size:(row+1)*row_size];
        b := p.out[end-(row+1)*row_size:end-row*row_size];
        copy(swap, a);
        copy(a, b);
        copy(b, swap);
    }
    fmt.printf("\np.out_components: %d\nrow_size: %d\nend: %d\n", p.out_components, row_size, end);
    
    format := u32(gl.RGBA);
    iformat := i32(gl.RGBA8);
    switch p.out_components
    {
    case 1:
        format = gl.RED;
        iformat = p.depth == 16 ? gl.R16 : gl.R8;
    case 2:
        format = gl.RG;
        iformat = p.depth == 16 ? gl.RG16 : gl.RG8;
    case 3:
        format = gl.RGB;
        iformat = p.depth == 16 ? gl.RGB16 : gl.RGB8;
    case 4:
        format = gl.RGBA;
        iformat = p.depth == 16 ? gl.RGBA16 : gl.RGBA8;
    }

    gl.GenTextures(1, &texture_id);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    type := u32(p.depth == 16 ? gl.UNSIGNED_SHORT : gl.UNSIGNED_BYTE);

    fmt.printf("p.out_components: %d\np.depth: %d\n", p.out_components, p.depth);

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.TexStorage2D(gl.TEXTURE_2D, 1, u32(iformat), i32(p.width), i32(p.height));
    gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, i32(p.width), i32(p.height), format, type, &p.out[0]);
    
    delete(p.out);
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.GenerateMipmap(gl.TEXTURE_2D);

    info.width = p.width;
    info.height = p.height;
    return texture_id, info;
}

_png_read_chunk :: proc(file: ^[]u8) -> PNG_Chunk
{
    chunk := PNG_Chunk{};

    chunk.size = u32(_read_sized(file, u32be));
    chunk.type = u32(_read_sized(file, u32be));
    
    chunk.data = make([]byte, chunk.size);
    copy(chunk.data, file^);
    file^ = file[chunk.size:];

    chunk.crc32 = u32(_read_sized(file, u32be));

    return chunk;
}

_create_png :: proc(p: ^PNG, data: []byte, raw_len: u32) -> []byte
{
    image: []byte;
    if p.interlace != 0 do
        image = _png_deinterlace(p, data, raw_len);
    else do
        image = _png_defilter(p, data, p.width, p.height);

    return image;
}

PNG_IHDR :: 0x49484452;
PNG_PLTE :: 0x504c5445;
PNG_IDAT :: 0x49444154;
PNG_IEND :: 0x49454e44;

PNG_cHRM :: 0x6348524d;
PNG_gAMA :: 0x67414d41;
PNG_sBIT :: 0x73424954;
PNG_sRGB :: 0x73524742;
PNG_bKGD :: 0x624b4744;
PNG_hIST :: 0x68495354;
PNG_tRNS :: 0x74524e53;
PNG_pHYs :: 0x70485973;
PNG_sPLT :: 0x73504c54;
PNG_tIME :: 0x74494d45;
PNG_iTXt :: 0x69545874;
PNG_tEXt :: 0x74455874;
PNG_zTXt :: 0x7a545874;

PNG_Chunk :: struct
{
    size:  u32,
    type:  u32,
    data:  []byte,
    crc32: u32,
}

_read_sized :: proc (file: ^[]byte, $T: typeid) -> T
{
    if len(file^) < size_of(T)
    {
        fmt.eprintf("Expected %T, got EOF\n", typeid_of(T));
        return T(0);
    }
    
    ret := ((^T)(&file[0]))^;
    file^ = file[size_of(T):];

    return ret;
}

_png_paeth_predict :: proc(a, b, c: i32) -> i32
{
    p := a + b - c;
    pa := abs(p-a);
    pb := abs(p-b);
    pc := abs(p-c);

    if pa <= pb && pa <= pc do return a;
    if pb <= pc do return b;
    return c;
}
 
Zlib_Buffer :: struct
{
    cmf: byte,
    extra_flags: byte,
    check_value: u16,

    data: []byte,
    bit_buffer: u32,
    bits_remaining: u32,
    
    huff_lit: []u32,
    huff_dist: []u32,
    huff_lit_lens: []u8,
    huff_dist_lens: []u8,
    out: [dynamic]byte,
}

_zlib_read_block :: proc(data: []byte) -> Zlib_Buffer
{
    data := data;
    
    z_buff := Zlib_Buffer{};
    z_buff.cmf = _read_sized(&data, byte);
    z_buff.extra_flags = _read_sized(&data, byte);
 
    z_buff.data = make([]byte, len(data)-4);
    copy(z_buff.data, data);
    
    z_buff.check_value = u16(_read_sized(&data, u16be));

    z_buff.bit_buffer = 0;
    z_buff.bits_remaining = 0;

    return z_buff;
}

 
_zlib_load_bits :: proc(using z_buff: ^Zlib_Buffer, req: u32)
{
    bits_to_read := req - bits_remaining;
    bytes_to_read := bits_to_read/8;
    if bits_to_read%8 != 0 do
        bytes_to_read += 1;
 
    for i in 0..<(bytes_to_read)
    {
        new_byte := u32(_read_sized(&data, byte));
        bit_buffer |= new_byte << (i*8 + bits_remaining);
    }
 
    bits_remaining += bytes_to_read * 8;
}

_zlib_read_bits :: proc(using z_buff: ^Zlib_Buffer, size: u32) -> u32
{
    res := u32(0);
 
    if size > bits_remaining do
        _zlib_load_bits(z_buff, size);
 
    for i in 0..<(size)
    {
        bit := u32(bit_buffer & (1 << i));
        res |= bit;
    }
 
    bit_buffer >>= size;
    bits_remaining -= size;

    return res;
}
 
_get_max_bit_length :: proc(lengths: []byte) -> byte
{
    max_length := byte(0);
    for l in lengths do
        max_length = max(max_length, l);
    return max_length;
}
 
_get_bit_length_count :: proc(counts: []u32, lengths: []byte, max_length: byte)
{
    for l in lengths do
        counts[l] += 1;
    counts[0] = 0;

    for i in 1..<(max_length)
    {
        if _png_err(counts[i] > (1 << i), "", "Bad Sizes")
        do return;
    }
}
 
_first_code_for_bitlen :: proc(first_codes: []u32, counts: []u32, max_length: byte)
{
    code := u32(0);
    counts[0] = 0;
    for bits in 1 ..(max_length)
    {
        code = (code + counts[bits-1]) << 1;
        first_codes[bits] = code;
    }
}
 
_assign_huffman_codes :: proc(assigned_codes: []u32, first_codes: []u32, lengths: []byte)
{
    for _, i in assigned_codes
    {
        if lengths[i] > 0
        {
            assigned_codes[i] = first_codes[lengths[i]];
            first_codes[lengths[i]] += 1;
        }
    }
}

_build_huffman_code :: proc(lengths: []byte) -> []u32
{
    max_length := _get_max_bit_length(lengths);
 
    counts         := make([]u32, max_length+1);
    first_codes    := make([]u32, max_length+1);
    assigned_codes := make([]u32, len(lengths));
 
    _get_bit_length_count(counts, lengths, max_length);
    _first_code_for_bitlen(first_codes, counts, max_length);
    _assign_huffman_codes(assigned_codes, first_codes, lengths);

    return assigned_codes;
}
 
_peek_bits_reverse :: proc(using z_buff: ^Zlib_Buffer, size: u32) -> u32
{
    if size > bits_remaining do
        _zlib_load_bits(z_buff, size);
    res := u32(0);
    for i in 0..<(size)
    {
        res <<= 1;
        bit := u32(bit_buffer & (1 << i));
        res |= (bit > 0) ? 1 : 0;
    }

    return res;
}
 
_decode_huffman :: proc(using z_buff: ^Zlib_Buffer, codes: []u32, lengths: []byte) -> u32
{
    for _, i in codes
    {
        if lengths[i] == 0 do continue;
        code := _peek_bits_reverse(z_buff, u32(lengths[i]));
        if codes[i] == code
        {
            bit_buffer >>= lengths[i];
            bits_remaining -= u32(lengths[i]);
            return u32(i);
        }
    }
    return 0;
}
 
@static HUFFMAN_ALPHABET :=
    [?]u32{16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15};
 
@static base_length_extra_bit := [?]u8{
    0, 0, 0, 0, 0, 0, 0, 0, //257 - 264
    1, 1, 1, 1, //265 - 268
    2, 2, 2, 2, //269 - 273
    3, 3, 3, 3, //274 - 276
    4, 4, 4, 4, //278 - 280
    5, 5, 5, 5, //281 - 284
    0,          //285
};
 
@static base_lengths := [?]u32{
    3, 4, 5, 6, 7, 8, 9, 10, //257 - 264
    11, 13, 15, 17,          //265 - 268
    19, 23, 27, 31,          //269 - 273
    35, 43, 51, 59,          //274 - 276
    67, 83, 99, 115,         //278 - 280
    131, 163, 195, 227,      //281 - 284
    258                      //285
};
 
@static dist_bases := [?]u32{
    /*0*/  1,     2, 3, 4, //0-3
    /*1*/  5,     7,       //4-5
    /*2*/  9,     13,      //6-7
    /*3*/  17,    25,      //8-9
    /*4*/  33,    49,      //10-11
    /*5*/  65,    97,      //12-13
    /*6*/  129,   193,     //14-15
    /*7*/  257,   385,     //16-17
    /*8*/  513,   769,     //18-19
    /*9*/  1025,  1537,    //20-21
    /*10*/ 2049,  3073,    //22-23
    /*11*/ 4097,  6145,    //24-25
    /*12*/ 8193,  12289,   //26-27
    /*13*/ 16385, 24577,   //28-29
           0,     0        //30-31, error, shouldn't occur
};
 
@static dist_extra_bits := [?]u32{
    /*0*/  0, 0, 0, 0, //0-3
    /*1*/  1, 1,       //4-5
    /*2*/  2, 2,       //6-7
    /*3*/  3, 3,       //8-9
    /*4*/  4, 4,       //10-11
    /*5*/  5, 5,       //12-13
    /*6*/  6, 6,       //14-15
    /*7*/  7, 7,       //16-17
    /*8*/  8, 8,       //18-19
    /*9*/  9, 9,       //20-21
    /*10*/ 10, 10,     //22-23
    /*11*/ 11, 11,     //24-25
    /*12*/ 12, 12,     //26-27
    /*13*/ 13, 13,     //28-29
           0,  0       //30-31 error, they shouldn't occur
};

@static _zlib_default_huff_len := [?]byte
{
   8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8, 8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
   8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8, 8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
   8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8, 8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
   8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8, 8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
   8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8, 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
   9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
   9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
   9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
   7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, 7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8
};

@static _zlib_default_huff_dist := [?]byte
{
   5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
};

_zlib_deflate :: proc(using z_buff: ^Zlib_Buffer)
{
    decompressed_data := make([]byte, 1024*1024); // 1MiB
    data_index := u32(0);
    for
    {
        decoded_value := _decode_huffman(z_buff, huff_lit, huff_lit_lens);

        if decoded_value == 256 do break;
        if decoded_value < 256
        {
            decompressed_data[data_index] = byte(decoded_value);
            data_index += 1;
            continue;
        }
 
        if 256 < decoded_value && decoded_value < 286
        {
            base_index := decoded_value - 257;
            duplicate_length := u32(base_lengths[base_index]) + _zlib_read_bits(z_buff, u32(base_length_extra_bit[base_index]));
 
            distance_index := _decode_huffman(z_buff, huff_dist, huff_dist_lens);
            distance_length := dist_bases[distance_index] + _zlib_read_bits(z_buff, dist_extra_bits[distance_index]);

            back_pointer_index := data_index - distance_length;
            /* fmt.printf("base_index: %d\nduplicate_length: %d\ndistance_index: %d\ndistance_length: %d\ndata_index: %d\nback_pointer_index: %d\n\n", */
            /*            base_index, duplicate_length, distance_index, distance_length, data_index, back_pointer_index); */
            for duplicate_length > 0
            {
                decompressed_data[data_index] = decompressed_data[back_pointer_index];
                data_index         += 1;
                back_pointer_index += 1;
                duplicate_length   -= 1;
            }
        }
    }
 
    bytes_read := data_index;
 
    append(&out, ..decompressed_data[:bytes_read]);
    delete(decompressed_data);
}

_zlib_compute_huffman :: proc(using z_buff: ^Zlib_Buffer)
{
    hlit  := u32(_zlib_read_bits(z_buff, 5)) + 257;
    hdist := u32(_zlib_read_bits(z_buff, 5)) + 1;
    hclen := u32(_zlib_read_bits(z_buff, 4)) + 4;
    
    huff_clen_lens := [19]byte{};
    
    for i in 0..<(hclen) do
        huff_clen_lens[HUFFMAN_ALPHABET[i]] = byte(_zlib_read_bits(z_buff, 3));
    
    huff_clen := _build_huffman_code(huff_clen_lens[:]);
    huff_lit_dist_lens := make([]byte, hlit+hdist);

    code_index := u32(0);
    for code_index < u32(len(huff_lit_dist_lens))
    {
        decoded_value := _decode_huffman(z_buff, huff_clen, huff_clen_lens[:]);
        if _png_err(decoded_value < 0 || decoded_value > 18, "", "Bad codelengths")
        do return;
        if decoded_value < 16
        {
            huff_lit_dist_lens[code_index] = byte(decoded_value);
            code_index += 1;
            continue;
        }
        
        repeat_count := u32(0);
        code_length_to_repeat := byte(0);
        
        switch decoded_value
        {
        case 16:
            repeat_count = _zlib_read_bits(z_buff, 2) + 3;
            if _png_err(code_index == 0, "", "Bad codelengths") do return;
            code_length_to_repeat = huff_lit_dist_lens[code_index - 1];
        case 17:
            repeat_count = _zlib_read_bits(z_buff, 3) + 3;
        case 18:
            repeat_count = _zlib_read_bits(z_buff, 7) + 11;
        }

        if _png_err(hlit+hdist - code_index < repeat_count, "", "Bad codelengths")
        do return;
        
        mem.set(&huff_lit_dist_lens[code_index], code_length_to_repeat, int(repeat_count));
        code_index += repeat_count;
    }

    if _png_err(code_index != hlit+hdist, "", "Bad codelengths")
    do return;

    huff_lit_lens = huff_lit_dist_lens[:hlit];
    huff_dist_lens = huff_lit_dist_lens[hlit:];
    
    huff_lit  = _build_huffman_code(huff_lit_lens);
    huff_dist = _build_huffman_code(huff_dist_lens);


}

_zlib_decompress :: proc(using z_buff: ^Zlib_Buffer)
{
    final := false;
    type: u32;
    out = make([dynamic]byte);

    for !final
    {
        final = bool(_zlib_read_bits(z_buff, 1));
        type  = _zlib_read_bits(z_buff, 2);
        fmt.printf("ZLIB_TYPE: %d\n", type);

        if type == 0
        {
            _zlib_uncompressed(z_buff);
        }
        else
        {
            if type == 1 // Fixed Huffman
            {
                z_buff.huff_lit_lens  = _zlib_default_huff_len[:];
                z_buff.huff_dist_lens = _zlib_default_huff_dist[:];
                z_buff.huff_lit = _build_huffman_code(z_buff.huff_lit_lens);
                z_buff.huff_dist = _build_huffman_code(z_buff.huff_dist_lens);
            }
            else // Computed Huffman
            {
                _zlib_compute_huffman(z_buff);
            }
            _zlib_deflate(z_buff);
        }
    }
}

_zlib_uncompressed :: proc(using z_buff: ^Zlib_Buffer)
{
    header := [4]byte{};
    if bits_remaining & 7 > 0 do
        _zlib_read_bits(z_buff, bits_remaining & 7); // Discard

    for _, i in header do
        header[i] = u8(_zlib_read_bits(z_buff, 8));
    assert(bits_remaining == 0);

    length  := u32(header[1]) * 256 + u32(header[0]);
    nlength := u32(header[3]) * 256 + u32(header[2]);
    if _png_err(nlength != (length ~ 0xffff), "", "Corrupt Zlib") ||
        _png_err(length > u32(len(data)), "",  "Read past buffer")
    do return;

    append(&out, ..data[:length]);
    data = data[length:];
}

PNG_Filter :: enum
{
    None,
    Sub,
    Up,
    Avg,
    Paeth,
}

_png_deinterlace :: proc(p: ^PNG, data: []byte, size: u32) -> []byte
{
    data := data;
    
    bytes := u32(p.depth == 16 ? 2 : 1);
    out_bytes := p.out_components * bytes;
    deinterlaced := make([]byte, p.width*p.height*out_bytes);
    
    origin := [7][2]u32{
        {0, 0},
        {4, 0},
        {0, 4},
        {2, 0},
        {0, 2},
        {1, 0},
        {0, 1},
    };

    spacing := [7][2]u32{
        {8, 8},
        {8, 8},
        {4, 8},
        {4, 4},
        {2, 4},
        {2, 2},
        {1, 2},
    };
    
    for pass in 0..<(7)
    {
        // Number of pixels per-axis in this pass
        count_x := (p.width  - origin[pass].x + spacing[pass].x-1) / spacing[pass].x;
        count_y := (p.height - origin[pass].y + spacing[pass].y-1) / spacing[pass].y;

        if count_x != 0 && count_y != 0
        {
            sub_image_len := ((((u32(p.components) * count_x * u32(p.depth)) + 7) >> 3) + 1) * count_y;
            sub_image := _png_defilter(p, data, count_x, count_y);
            
            for y in 0..<(count_y)
            {
                for x in 0..<(count_x)
                {
                    out_y := y * spacing[pass].y + origin[pass].y;
                    out_x := x * spacing[pass].x + origin[pass].x;
                    mem.copy(&deinterlaced[out_y*p.width*out_bytes + out_x*out_bytes],
                             &sub_image[(y*count_x + x)*out_bytes], int(out_bytes));
                }
            }
            
            data = data[sub_image_len:];
        }
    }

    return deinterlaced;
}

_png_defilter :: proc(p: ^PNG, data: []byte, x, y: u32) -> []byte
{
    x := x;
    y := y;
    
    bytes := u32(p.depth == 16 ? 2 : 1);
    bit_depth := u32(p.depth);
    pixel_depth := (bit_depth+7) >> 3;
    
    img_width_bytes := ((u32(p.components) * x * bit_depth) + 7) >> 3;
    img_len := (img_width_bytes + 1) * y;
    
    output_bytes := u32(p.out_components) * bytes;
    filter_bytes := p.components * bytes;

    fmt.printf("output_bytes: %d\nfilter_bytes: %d\n\n", output_bytes, filter_bytes);
    prev_row: []byte;
    row := data;
    stride := x * filter_bytes;
    
    image := make([]byte, x*y*u32(output_bytes));
    working := image;
    for i in 0..<(y)
    {
        filter := PNG_Filter(row[0]);
        row = row[1:];
        off := i*x*output_bytes;
        
        if _png_err(filter > .Paeth, p.filepath, "Invalid filter")
        {
            delete(image);
            return nil;
        }

        /* if bit_depth < 8 */
        /* { */
        /*     assert(img_width_bytes <= p.width); */
        /*     off += p.width * p.out_components - img_width_bytes; */
        /*     filter_bytes = 1; */
        /*     x = img_width_bytes; */
        /* } */
        working = image[off:];

        switch filter
        {
        case .None:
            for j in 0..<(x) do
                for k in 0..<(filter_bytes)
                {
                    ri := j*filter_bytes+k;
                    oi := j*output_bytes+k;
                    
                    working[oi] = row[ri];
                }    
            
        case .Sub:
            for j in 0..<(x)
            {
                for k in 0..<(filter_bytes)
                {
                    ri := j*filter_bytes+k;
                    oi := j*output_bytes+k;
                    
                    a := u16(0);
                    if j != 0 do
                        a = u16(working[oi - output_bytes]);
                    working[oi] = byte(u16(row[ri]) + a);
                }
            }

        case .Up:
            for j in 0..<(x)
            {
                for k in 0..<(filter_bytes)
                {
                    ri := j*filter_bytes+k;
                    oi := j*output_bytes+k;
                    
                    b := u16(0);
                    if y != 0 do
                        b = u16(prev_row[oi]);
                    working[oi] = byte(u16(row[ri]) + b);
                }
            }

        case .Avg:
            for j in 0..<(x)
            {
                for k in 0..<(filter_bytes)
                {
                    ri := j*filter_bytes+k;
                    oi := j*output_bytes+k;
                    
                    a := u16(0);
                    b := u16(0);
                    if j != 0 do
                        a = u16(working[oi - output_bytes]);
                    if y != 0 do
                        b = u16(prev_row[oi]);

                    working[oi] = byte(u16(row[ri]) + (a+b)/2);
                }
            }

        case .Paeth:
            for j in 0..<(x)
            {
                for k in 0..<(filter_bytes)
               {
                    ri := j*filter_bytes+k;
                    oi := j*output_bytes+k;
                    
                    a := u16(0);
                    b := u16(0);
                    c := u16(0);

                    if j != 0
                    {
                        a = u16(working[oi - output_bytes]);
                        if y != 0 do
                            c = u16(prev_row[oi - output_bytes]);
                    }

                    if y != 0 do
                        b = u16(prev_row[oi]);
                    
                   paeth := _png_paeth_predict(i32(a), i32(b), i32(c));
                   working[oi] = byte(u16(row[ri]) + u16(paeth));
                }
            }
        }

        if p.components != p.out_components
        {
            for j in 0..<(x)
            {
                working[j*output_bytes+filter_bytes] = 255;
                if p.depth == 16 do
                    working[j*output_bytes+filter_bytes+1] = 255;
            }
        }
        
        prev_row = working;
        row = row[x*filter_bytes:];
    }

    // @TODO(Tyler): Support for 1/2/4 bit color depth

    // @NOTE(Tyler): Swap endianness to platform native
    if p.depth == 16
    {
        working = image;
        working_be := mem.slice_data_cast([]u16be, working);
        working_16 := mem.slice_data_cast([]u16,   working);

        for _, i in working_16 do
            working_16[i] = u16(working_be[i]);
    }

    return image;
}

_png_compute_transparency8 :: proc(p: ^PNG, trans: [3]u8)
{
    assert(p.out_components == 2 || p.out_components == 4);

    if p.out_components == 2
    {
        data := mem.slice_data_cast([][2]u8, p.out);
        for _, i in data
        {
            pixel := &data[i];
            pixel[1] = pixel[0] == trans[0] ? 0 : 255;
        }
    }
    else
    {
        data := mem.slice_data_cast([][4]u8, p.out);
        for _, i in data
        {
            pixel := &data[i];
            if pixel[0] == trans[0]
            && pixel[1] == trans[1]
            && pixel[2] == trans[2] do
            pixel[3] = 0;
        }
    }
}

_png_compute_transparency16 :: proc(p: ^PNG, trans: [3]u16)
{
    assert(p.out_components == 2 || p.out_components == 4);

    if p.out_components == 2
    {
        data := mem.slice_data_cast([][2]u16, p.out);
        for _, i in data
        {
            pixel := data[i];
            pixel[1] = pixel[0] == trans[0] ? 0 : 255;
        }
    }
    else
    {
        data := mem.slice_data_cast([][4]u16, p.out);
        for _, i in data
        {
            pixel := data[i];
            if pixel[0] == trans[0]
            && pixel[1] == trans[1]
            && pixel[2] == trans[2] do
                pixel[3] = 0;
        }
    }
}

_png_expand_palette :: proc(p: ^PNG)
{
    p.components = p.pal_components;
    p.out_components = p.pal_components;

    expanded := make([]byte, p.width*p.height*p.pal_components);
    for i in 0..<(p.width*p.height) do
        mem.copy(&expanded[i*p.pal_components], &p.palette[u32(p.out[i])][0], int(p.pal_components));
    delete(p.out);
    p.out = expanded;
}
