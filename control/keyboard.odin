package control

import "core:fmt"
import "shared:glfw"
import "core:runtime"

Keyboard :: struct
{
     keys: [316]Button_State,
     text_buffer: ^[dynamic]byte,
}
@static KEYBOARD: Keyboard;

update_keystate :: proc "c" (window: glfw.Window_Handle,
keycode, scancode, action, mods: i32)
{
     context = runtime.default_context();
     
     code := keycode - 32;
     if code > 316
         {
         fmt.eprintf("Keycode '%d' out of range\n", keycode);
         return;
     }
     
     switch glfw.Key_State(action)
         {
         case glfw.PRESS:   KEYBOARD.keys[code] = .Pressed;
         case glfw.RELEASE: KEYBOARD.keys[code] = .Released;
         case glfw.REPEAT:  KEYBOARD.keys[code] = .Repeat;
     }
}

get_keystate :: proc(k: int) -> Button_State
{
     code := k - 32;
     if code > 316
         {
         fmt.eprintf("Keycode '%d' out of range\n", k);
         return .None;
     }
     
     ret := KEYBOARD.keys[code];
     #partial switch ret
         {
         case .Pressed, .Repeat: KEYBOARD.keys[code] = .Down;
         case .Released:         KEYBOARD.keys[code] = .Up;
     }
     
     return ret;
}

key_down :: proc(k: int) -> bool
{
     state := get_keystate(k);
     if Button_State.Pressed <= state && state <= .Repeat do
         return true;
     
     code := k - 32;
     KEYBOARD.keys[code] = state;
     return false;
}

key_pressed :: proc(k: int) -> bool
{
     state := get_keystate(k);
     if state == .Pressed do
         return true;
     
     code := k - 32;
     KEYBOARD.keys[code] = state;
     return false;
}

key_repeat :: proc(k: int) -> bool
{
     state := get_keystate(k);
     if state == .Pressed || state == .Released do
         return true;
     
     code := k - 32;
     KEYBOARD.keys[code] = state;
     return false;
}

key_released :: proc(k: int) -> bool
{
     state := get_keystate(k);
     if state == .Released do
         return true;
     
     code := k - 32;
     KEYBOARD.keys[code] = state;
     return false;
}

keyboard_text_hook :: proc(text_buffer: ^[dynamic]byte)
{
     KEYBOARD.text_buffer = text_buffer;
}

keyboard_text_unhook :: proc()
{
     KEYBOARD.text_buffer = nil;
}

keyboard_char_callback :: proc "c" (window: glfw.Window_Handle, codepoint: rune)
{
     if KEYBOARD.text_buffer != nil do
         append(KEYBOARD.text_buffer, byte(codepoint));
}
