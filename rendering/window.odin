package rendering

import "core:fmt"
import "core:os"

import "shared:glfw"

Window :: struct
{
    width, height : int,
    handle        : glfw.Window_Handle,
}

init_window :: proc(w, h : int, title : string) -> Window
{
    win: Window;
    win.width  = w;
    win.height = h;
    win.handle = glfw.create_window(w, h, title, nil, nil);
    if win.handle == nil
    {
        fmt.eprintf("Failed to open GLFW window\n");
        glfw.terminate();
        os.exit(1);
    }
    
    return win;
}
