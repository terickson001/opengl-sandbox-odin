package engine_profile

import "../gui"
import "core:fmt"

Profiler :: struct
{
    enabled: bool,
    
    window: gui.Window,
}

PROFILER: Profiler;

toggle_window :: proc() { PROFILER.enabled = !PROFILER.enabled; }
init_window :: proc(ctx: ^gui.Context)
{
    using PROFILER;
    window = gui.init_window(ctx, "Profiler", {1024-200-34, 34, 200, 700});
}

do_window :: proc(ctx: ^gui.Context)
{
    using PROFILER;
    if !enabled do return;
    
    if .Active in gui.window(ctx, &window, {})
    {
        gui.row(ctx, 1, {0}, 0);
        for name, timer in GL_PROFILER.timers
        {
            gui.label(ctx, fmt.tprintf("%s: %.2fms", name, f64(timer.latest)/1000000.0), {.Left});
        }
        gui.window_end(ctx);
    }
}