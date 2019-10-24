package util

using import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:os"

_read_byte :: proc(file: os.Handle) -> u8
{
    c: []u8;
    os.read(file, c);

    return c[0];
}

read_string :: proc(file: os.Handle, allocator := context.allocator) -> (string, bool)
{
    save: [dynamic]u8;

    for c := _read_byte(file); !strings.is_space(rune(c)); do
        append(&save, c);

    os.seek(file, -1, os.SEEK_END);

    str := strings.clone(strings.string_from_ptr(&save[0], len(save)), allocator);
    delete(save);
    
    return str, true;
}

read_float :: proc(file: os.Handle, ret: $T/^$E) -> bool
{
    val: E = 0;
    return false;
}

read_types :: proc(file: os.Handle, args: ..any) -> bool
{
    for v in args
    {
        switch kind in v
        {
            case ^f32: read_float(file, kind);
            case ^f64: read_float(file, kind);
            case ^i32: printf("Reading %t\n",  typeid_of(type_of(kind)));
            case ^i64: printf("Reading %t\n",  typeid_of(type_of(kind)));
            case: eprintf("Invalid type %v\n", typeid_of(type_of(kind)));
        }
    }
    return true;
}
