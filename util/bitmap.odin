package util

Bitmap :: struct
{
    bits: u64,
    chunks: []u64,
}

make_bitmap :: proc(size: u64) -> Bitmap
{
    bmp: Bitmap;
    bmp.bits = size;
    num_chunks := size+size_of(bmp.chunks[0])-1 / size_of(bmp.chunks[0]);
    bmp.chunks = make([]u64, num_chunks);
    return bmp;
}

bitmap_set :: proc(using bmp: ^Bitmap, bit: u64)
{
    assert(bit < bits);
    chunk_idx := bit / size_of(chunks[0]);
    bit_idx   := bit % size_of(chunks[0]);
    chunks[chunk_idx] |= 1 << bit_idx;
}

bitmap_clear :: proc(using bmp: ^Bitmap, bit: u64, loc:=#caller_location)
{
    assert(condition=bit < bits, loc=loc);
    chunk_idx := bit / size_of(chunks[0]);
    bit_idx   := bit % size_of(chunks[0]);
    chunks[chunk_idx] &= ~(1 << bit_idx);
}

bitmap_get :: proc(using bmp: ^Bitmap, bit: u64) -> bool
{
    assert(bit < bits);
    chunk_idx := bit / size_of(chunks[0]);
    bit_idx   := bit % size_of(chunks[0]);
    return bool((chunks[chunk_idx] >> bit_idx) & 0b1);
}

bitmap_clone :: proc(using bmp: ^Bitmap) -> Bitmap
{
    nw := make_bitmap(bits);
    copy(nw.chunks, chunks);
    return nw;
}

bitmap_find_first :: proc(using bmp: ^Bitmap, invert := false) -> (u64, bool)
{
    for chunk in chunks
    {
        bite := invert ? ~chunk : chunk;
        if bite & max(u64) == 0 do continue;
        mask := u64(max(u32));
        bits := u64(32);
        idx  := u64(0);
        for bits != 0
        {
            if bite & mask != 0
            {
                bite = bite & mask;
            }
            else
            {
                idx += bits;
                bite = (bite >> bits) & mask;
            }
            bits >>= 1;
            mask >>= bits;
        }
        assert(bite == 1);
        return idx, true;
    }
    return 0, false;
}

bitmap_delete :: proc(using bmp: ^Bitmap)
{
    if bits != 0 do delete(chunks);
}