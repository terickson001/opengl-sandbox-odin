package util

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:os"

char_is_alpha :: proc(c: u8) -> bool
{
    return ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z');
}

char_is_num :: proc(c: u8) -> bool
{
    return '0' <= c && c <= '9';
}

char_is_alphanum :: proc(c: u8) -> bool
{
    return char_is_alpha(c) || char_is_num(c);
}

char_is_ident :: proc(c: u8) -> bool
{
    return char_is_alphanum(c) || c == '_';
}

read_char :: proc(str: ^string, c: ^byte) -> bool
{
    c^ = 0;
    if len(str) == 0 do return false;

    c^ = str[0];
    str^ = str[1:];
    return true;
}

read_line :: proc(str: ^string, ret: ^string) -> bool
{
    line := string{};
    defer if ret != nil do ret^ = line;

    idx := 0;
    for idx < len(str) && str[idx] != '\n' do
        idx += 1;

    line = str[:idx];
    if str[idx] == '\n'
    {
        str^ = str[idx+1:];
        return true;
    }
    else
    {
        str^ = string{};
        return false;
    }
}

read_ident :: proc(str: ^string, ret: ^string) -> bool
{
    ret^ = string{};
    idx := 0;

    if !(char_is_alpha(str[idx]) || str[idx] == '_') do
        return false;
    
    for char_is_ident(str[idx]) do
        idx += 1;

    if idx == 0 do
        return false;

    ret^ = str[:idx];
    str^ = str[idx:];
    return true;
}

read_string :: proc(str: ^string, ret: ^string) -> bool
{
    ret^ = string{};
    idx := 0;

    if str[idx] != '"' && str[idx] != '\'' do
        return false;

    quote := str[idx];
    idx += 1;

    for str[idx] != quote
    {
        if str[idx] == '\\' do
            idx += 1;
        idx += 1;
    }

    ret^ = str[1:idx];
    str^ = str[idx+1:];
    
    return true;
}

read_int :: proc(str: ^string, ret: $T/^$E) -> bool
{
    ret^ = 0;

    if len(str) == 0 do
        return false;
    
    sign := int(1);
    idx := 0;
    
    if str[idx] == '-'
    {
        sign = -1;
        idx += 1;
    }
    

    for idx < len(str) && '0' <= str[idx] && str[idx] <= '9'
    {
        ret^ *= 10;
        ret^ += E(str[idx] - '0');
        idx += 1;
    }

    ret^ *= E(sign);

    if idx == 0 do
        return false;
    
    str^ = str[idx:];
    return true;
}

read_float :: proc(str: ^string, ret: $T/^$E) -> bool
{
    ret^ = 0;

    if len(str) == 0 do
        return false;

    integer : i64 = 0;
    ok := read_int(str, &integer);
    if !ok do return false;

    sign: E = integer < 0 ? -1 : 1;
    ret^ = E(integer);

    idx := 0;
    if idx < len(str) && str[idx] == '.'
    {
        frac: E = 0;
        div:  E = 10.0;
        idx += 1;
        for idx < len(str) && char_is_num(str[idx])
        {
            frac += E(str[idx] - '0') / div;
            div *= 10;
            idx += 1;
        }
        ret^ += frac * sign;
    }

    str^ = str[idx:];
    return true;
}

read_any :: proc(str: ^string, arg: any, verb: u8 = 'v') -> bool
{
    ok := false;
    
    switch verb
    {
        case 'v':
        switch kind in arg
        {
            case ^f32:  ok = read_float(str, kind);
            case ^f64:  ok = read_float(str, kind);
            
            case ^i8:   ok = read_int(str, kind);
            case ^i16:  ok = read_int(str, kind);
            case ^i32:  ok = read_int(str, kind);
            case ^i64:  ok = read_int(str, kind);
            case ^i128: ok = read_int(str, kind);
            case ^u8:   ok = read_int(str, kind);
            case ^u16:  ok = read_int(str, kind);
            case ^u32:  ok = read_int(str, kind);
            case ^u64:  ok = read_int(str, kind);
            case ^u128: ok = read_int(str, kind);
            
            case ^string:
            if str[0] == '"' || str[0] == '\'' do ok = read_string(str, kind);
            else do ok = read_ident(str, kind);
            
            case: fmt.eprintf("Invalid type %T\n", kind);
        }

        case 'f':
        switch kind in arg
        {
            case ^f32:  ok = read_float(str, kind);
            case ^f64:  ok = read_float(str, kind);
            case: fmt.eprintf("Invalid type %T for specifier %%%c\n", kind, verb);
        }

        case 'd':
        switch kind in arg
        {
            case ^i8:   ok = read_int(str, kind);
            case ^i16:  ok = read_int(str, kind);
            case ^i32:  ok = read_int(str, kind);
            case ^i64:  ok = read_int(str, kind);
            case ^i128: ok = read_int(str, kind);

            case ^u8:   ok = read_int(str, kind);
            case ^u16:  ok = read_int(str, kind);
            case ^u32:  ok = read_int(str, kind);
            case ^u64:  ok = read_int(str, kind);
            case ^u128: ok = read_int(str, kind);
            
            case: fmt.eprintf("Invalid type %T for specifier %%%c\n", kind, verb);
        }
        
        case 'q':
        switch kind in arg
        {
            case ^string: ok = read_string(str, kind);

            case: fmt.eprintf("Invalid type %T for specifier %%%c\n", kind, verb);
        }

        case 's':
        switch kind in arg
        {
            case ^string: ok = read_ident(str, kind);

            case: fmt.eprintf("Invalid type %T for specifier %%%c\n", kind, verb);
        }
     
        case: fmt.eprintf("Invalid specifier %%%c\n", verb);
    }
    
    return ok;
}

read_types :: proc(str: ^string, args: ..any) -> bool
{
    ok: bool;
    for v in args
    {
        ok = read_any(str, v);
        if len(str) > 0 do
            str^ = strings.trim_left_space(str^);
        if !ok do return false;
    }
    return true;
}

read_fmt :: proc(str: ^string, fmt_str: string, args: ..any) -> bool
{
    ok: bool;

    sidx := 0;
    fidx := 0;
    aidx := 0;
    
    for fidx < len(fmt_str)
    {
        if fmt_str[fidx] != '%'
        {
            
            if str[sidx] == fmt_str[fidx]
            {
                sidx += 1;
                fidx += 1;
                continue;
            }
            else if fmt_str[fidx] == '\n' && strings.has_prefix(str[sidx:], "\r\n")
            {
                sidx += 2;
                fidx += 1;
                continue;
            }
            else
            {
                if sidx > 0 do
                    str^ = str[sidx:];
                return false;
            }
        }

        if aidx >= len(args) do
            return false;

        str^ = str[sidx:];
        sidx = 0;
        fidx += 1; // %
        switch fmt_str[fidx]
        {
            case 'd': fallthrough;
            case 'f': fallthrough;
            case 'q': fallthrough;
            case 's': fallthrough;
            case 'v': ok = read_any(str, args[aidx], fmt_str[fidx]);
            case:
                fmt.eprintf("Invalid format specifier '%%%c'\n", fmt_str[fidx]);
                return false;
        }
        fidx += 1;
        aidx += 1;
        if !ok do return false;
    }
    str^ = str[sidx:];
    return true;
}
