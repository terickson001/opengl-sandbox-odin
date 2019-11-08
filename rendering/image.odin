package rendering

using import "core:fmt"
using import "core:math"

import "shared:gl"
import "core:os"
import "core:mem"
import "core:strings"

load_bmp :: proc(filepath: string) -> (u32, Texture_Info)
{
    header: [54]byte;

    file, err := os.open(filepath);
    if err != 0
    {
        eprintf("Image %q could not be opened\n", filepath);
        return 0, Texture_Info{};
    }

    n_read, _ := os.read(file, header[:]);
    if n_read != 54 ||
        header[0] != 'B' || header[1] != 'M'
    {
        eprintf("Image %q is not a valid BMP\n", filepath);
        return 0, Texture_Info{};
    }

    data_pos   := (^u32)(&(header[0x0A]))^;
    image_size := (^u32)(&(header[0x22]))^;
    width      := (^u32)(&(header[0x12]))^;
    height     := (^u32)(&(header[0x16]))^;

    if image_size == 0 do image_size = width*height*3;
    if data_pos == 0   do data_pos = 54;

    data := make([]byte, image_size);
    n_read, _ = os.read(file, data);
    os.close(file);

    texture_id: u32;
    gl.GenTextures(1, &texture_id);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, i32(width), i32(height), 0, gl.BGR, gl.UNSIGNED_BYTE, &data[0]);
    delete(data);
    
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_LINEAR);
    gl.GenerateMipmap(gl.TEXTURE_2D);

    gl.BindTexture(gl.TEXTURE_2D, 0);

    info := Texture_Info{width, height};

    return texture_id, info;
}

load_tga :: proc(filepath: string) -> (u32, Texture_Info)
{
    header: [18]byte;

    file, err := os.open(filepath);
    if err != 0
    {
        eprintf("Image %q could not be opened\n", filepath);
        return 0, Texture_Info{};
    }

    n_read, _ := os.read(file, header[:]);
    if n_read != 18
    {
        eprintf("Image %q is not a valid TGA\n", filepath);
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

    printf("======= Load TGA (%s) =======\n", filepath);
    printf("cmap_type: %hhu\n", cmap_type);
    printf("cmap_start: %hu\n", cmap_start);
    printf("cmap_len: %hu\n", cmap_len);
    printf("cmap_depth: %hhu\n", cmap_depth);

    printf("id_length: %hhu\n", id_length);
    printf("image_type: %hhu\n", image_type);
    printf("  RLE?: %s\n", RLE?"Yes":"No");
    printf("width: %hu\n", width);
    printf("height: %hu\n", height);
    printf("pixel_depth: %hhu\n", pixel_depth);
    printf("image_descriptor: %hhu\n", image_descriptor);
    printf("========================\n");

    pixel_depth_bytes := int(ceil(f32(pixel_depth)/8));
    cmap_depth_bytes  := int(ceil(f32(cmap_depth) /8));

    image_id := make([]byte, id_length);
    defer delete(image_id);
    if id_length > 0
    {
        n_read, _ = os.read(file, image_id);
        if n_read != int(id_length)
        {
            eprintf("Could not read image ID in TGA %q\n", filepath);
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
            eprintf("Could not read colormap in TGa %q", filepath);
            return 0, Texture_Info{};
        }
    }

    raw_image_data := make([]byte, int(width*height)*pixel_depth_bytes);
    image_size, _ := os.read(file, raw_image_data);
    if image_size == 0
    {
        eprintf("Could not read image data in TGA %q", filepath);
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
        case: eprintf("Invalid color depth '%d' in TGA %q\n", result_depth, filepath);
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
        eprintf("Could not open image %q\n", filepath);
        return 0, Texture_Info{};
    }

    filecode: [4]byte;
    os.read(file, filecode[:]);
    if strings.string_from_ptr(&filecode[0], 4) != "DDS\x00"
    {
        eprintf("Image %q is not a valid DDS\n", filepath);
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

load_png :: proc(filepath: string) -> (u32, Texture_Info)
{
    
    return 0, Texture_Info{};
}

PNG_Chunk :: struct
{
    size:  u32,
    type:  [4]byte,
    data:  []byte,
    crc32: u32,
}

_read_sized :: proc (file: ^[]byte, $T: typeid) -> T
{
    if len(file^) < size_of(T)
    {
        eprintf("Expected %T, got EOF\n", typeid_of(T));
        return T(0);
    }

    ret := (^T)(&file[0])^;
    file^ = file[size_of(T):];

    return ret;
}

_png_read_chunk :: proc(file: ^[]byte) -> PNG_Chunk
{
    chunk := PNG_Chunk{};
    chunk.size = u32(_read_sized(file, u32be));
    chunk.type = _read_sized(file, [4]byte);

    chunk.data = make([]byte, chunk.size);
    copy(chunk.data, file^);
    file^ = file[chunk.size:];

    chunk.crc32 = u32(_read_sized(file, u32be));

    return chunk;
}

Zlib_Block :: struct
{
    cmf: byte,
    extra_flags: byte,
    data: []byte,
    check_value: u16,
}

_zlib_read_block :: proc(file: ^[]byte, size: u32) -> Zlib_Block
{
    block := Zlib_Block{};
    block.cmf = _read_sized(file, byte);
    block.extra_flags = _read_sized(file, byte);

    block.data = make([]byte, size-4);
    copy(block.data, file^);
    file^ = file[len(block.data):];

    block.check_value = u16(_read_sized(file, u16be));

    return block;
}

PNG_Bit_Stream :: struct
{
    data: []byte,
    buffer: u32,
    remaining: u32,
}

_png_load_bits :: proc(bits: ^PNG_Bit_Stream, req: u32)
{
    bits_to_read := req - bits.remaining;
    bytes_to_read := bits_to_read/8;
    if bits_to_read%8 != 0 do
        bytes_to_read += 1;

    for i in 0..<(bytes_to_read)
    {
        new_byte := u32(_read_sized(&bits.data, byte));
        bits.buffer |= new_byte << (i*8 + bits.remaining);
    }

    bits.remaining += bytes_to_read * 8;
}

_png_read_bits :: proc(bits: ^PNG_Bit_Stream, size: u32) -> u32
{
    res := u32(0);

    if size > bits.remaining do
        _png_load_bits(bits, size);

    for i in 0..<(size)
    {
        bit := u32(bits.buffer & (1 << i));
        res |= bit;
    }

    bits.buffer >>= size;
    bits.remaining -= size;

    return res;
}

_get_max_bit_length :: proc(lengths: []byte) -> byte
{
    max_length := byte(0);
    for l in lengths do
        max_length = max(max_length, l);
    return max_length;
}

_get_bit_length_count :: proc(counts: []u32, lengths: []byte)
{
    for l in lengths do
        counts[l] += 1;
}

_first_code_for_bitlen :: proc(first_codes: []u32, counts: []u32, max_length: byte)
{
    code := u32(0);
    for i in 1..<(max_length)
    {
        code = (code + counts[i-1]) << 1;
        if counts[i] > 0 do
            first_codes[i] = code;
    }
}

_assign_huffman_codes :: proc(assigned_codes: []u32, first_codes: []u32, lengths: []byte)
{
    for _, i in assigned_codes
    {
        if lengths[i] > 0
        {
            first_codes[lengths[i]] += 1;
            assigned_codes[i] = first_codes[lengths[i]];
        }
    }
}

_build_huffman_code :: proc(lengths: []byte) -> []u32
{
    max_length := _get_max_bit_length(lengths);

    counts         := make([]u32, max_length+1);
    first_codes    := make([]u32, max_length+1);
    assigned_codes := make([]u32, len(lengths));

    _get_bit_length_count(counts, lengths);
    counts[0] = 0;

    _first_code_for_bitlen(first_codes, counts, max_length);
    _assign_huffman_codes(assigned_codes, first_codes, lengths);

    return assigned_codes;
}

_peek_bits_reverse :: proc(bits: ^PNG_Bit_Stream, size: u32) -> u32
{
    if size > bits.remaining do
        _png_load_bits(bits, size);
    
    res := u32(0);
    for i in 0..<(size)
    {
        res <<= 1;
        bit := u32(bits.buffer & (1 << i));
        res |= (bit != 0) ? 1 : 0;
    }

    return res;
}

_decode_huffman :: proc(bits: ^PNG_Bit_Stream, codes: []u32, lengths: []byte) -> u32
{
    for _, i in codes
    {
        code := _peek_bits_reverse(bits, u32(lengths[i]));
        if codes[i] == code
        {
            bits.buffer >>= lengths[i];
            bits.remaining -= u32(lengths[i]);
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
    0           //285
};

@static base_lengths := [?]u8{
    3, 4, 5, 6, 7, 8, 9, 10, //257 - 264
    11, 13, 15, 17,          //265 - 268
    19, 23, 27, 31,          //269 - 273 
    35, 43, 51, 59,          //274 - 276
    67, 83, 99, 115,         //278 - 280
    131, 163, 195, 227,      //281 - 284
    0                        //285
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
    /*13*/ 16385, 24577,    //28-29
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

_zlib_deflate :: proc(
    bits: ^PNG_Bit_Stream,
    literal_tree: []u32, lit_bit_len: []byte,
    distance_tree: []u32, dist_bit_len: []byte) -> ([]byte, u32)
{
    decompressed_data := make([]byte, 1024*1024); // 1MiB
    data_index := u32(0);
    for
    {
        decoded_value := _decode_huffman(bits, literal_tree, lit_bit_len);

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
            duplicate_length := u32(base_lengths[base_index]) + _png_read_bits(bits, u32(base_length_extra_bit[base_index]));

            distance_index := _decode_huffman(bits, distance_tree, dist_bit_len);
            distance_length := dist_bases[distance_index] + _png_read_bits(bits, dist_extra_bits[distance_index]);

            back_pointer_index := data_index - distance_length;
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
    
    fit_image := make([]byte, bytes_read);
    copy(fit_image, decompressed_data);
    delete(decompressed_data);

    return fit_image, bytes_read;
}

_zlib_decompress :: proc(data: []byte) -> (dec_data: []byte, data_read: u32)
{
    decompressed_data := make([]byte, 1024*1024*4); // 4MiB
    data_read = 0;
    final := false;
    type: u32;

    bits := PNG_Bit_Stream{data, 0, 0};
    for !final
    {
        final = bool(_png_read_bits(&bits, 1));
        type  = _png_read_bits(&bits, 2);

        hlit  := u32(_png_read_bits(&bits, 5)) + 257;
        hdist := u32(_png_read_bits(&bits, 5)) + 1;
        hclen := u32(_png_read_bits(&bits, 4)) + 4;

        code_length_of_code_length: [19]byte;

        for i in 0..<(hclen) do
            code_length_of_code_length[HUFFMAN_ALPHABET[i]] = byte(_png_read_bits(&bits, 3));

        huffman_codes_of_tree_of_trees := _build_huffman_code(code_length_of_code_length[:]);
        two_trees_code_bit_lengths := make([]byte, hlit+hdist);

        code_index := u32(0);
        for code_index < u32(len(two_trees_code_bit_lengths))
        {
            decoded_value := _decode_huffman(&bits, huffman_codes_of_tree_of_trees, code_length_of_code_length[:]);
            if decoded_value < 16
            {
                two_trees_code_bit_lengths[code_index] = byte(decoded_value);
                code_index += 1;
                continue;
            }

            repeat_count := u32(0);
            code_length_to_repeat := byte(0);

            switch decoded_value
            {
            case 16:
                repeat_count = _png_read_bits(&bits, 2) + 3;
                code_length_to_repeat = two_trees_code_bit_lengths[code_index - 1];
            case 17:
                repeat_count = _png_read_bits(&bits, 3) + 3;
            case 18:
                repeat_count = _png_read_bits(&bits, 7) + 11;
            }

            mem.set(&two_trees_code_bit_lengths[code_index], code_length_to_repeat, int(repeat_count));
            code_index += repeat_count;
        }

        literal_length_huff_tree := _build_huffman_code(two_trees_code_bit_lengths[:hlit]);
        distance_huff_tree       := _build_huffman_code(two_trees_code_bit_lengths[hlit:]);

        decompressed_block, block_size := _zlib_deflate(
            &bits,
            literal_length_huff_tree, two_trees_code_bit_lengths[:hlit],
            distance_huff_tree, two_trees_code_bit_lengths[hlit:]);

        copy(decompressed_data[data_read:], decompressed_block);
        data_read += block_size;
        delete(decompressed_block);
    }

    dec_data = make([]byte, data_read);
    copy(dec_data, decompressed_data);
    delete(decompressed_data);
    
    return dec_data, data_read;
}

_png_paeth_predict :: prc(a, b, c: i32) -> i32
{
    p := a + b - c;
    pa := abs(p-a);
    pb := abs(p-b);
    pc := abs(p-c);

    if pa <= pb && pa <= pc do return a;
    if pb <= pc do return b;
    return c;
}

PNG_Filter :: enum
{
    None,
    Sub,
    Up,
    Avg,
    Paeth,
}

_png_defilter :: proc(data: []byte, size: u32, ihdr: ^PNG_Chunk)
{

}
