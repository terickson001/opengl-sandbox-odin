package engine_profile

import "core:mem"
import "core:strings"

import "shared:gl"

GL_Timer :: struct
{
    name: string,
    ids: [2]u32,
    latest: u64,
    updated: [2]b8,
}
GL_Profiler :: struct
{
    timers:   map[string]GL_Timer,
    curr_set: int,
}
GL_PROFILER: GL_Profiler;

gl_make_timer :: proc(name: string) -> GL_Timer
{
    using GL_PROFILER;
    t: GL_Timer;
    t.name = strings.clone(name);
    gl.GenQueries(2, &t.ids[0]);
    return t;
}

gl_end_frame :: proc()
{
    using GL_PROFILER;
    curr_set = int(!bool(curr_set));
    for n, t in &timers
    {
        if !t.updated[curr_set] do t.latest = 0;
        else
        {
            gl.GetQueryObjectui64v(t.ids[curr_set], gl.QUERY_RESULT, &t.latest);
        }
        t.updated[curr_set] = false;
    }
}

gl_start_timer :: #force_inline proc(name: string)
{
    using GL_PROFILER;
    t := &timers[name];
    if t == nil
    {
        timers[name] = gl_make_timer(name);
        t = &timers[name];
    }
    
    gl.BeginQuery(gl.TIME_ELAPSED, t.ids[curr_set]);
    t.updated[curr_set] = true;
}

gl_end_timer :: #force_inline proc()
{
    gl.EndQuery(gl.TIME_ELAPSED);
}

gl_get_result :: #force_inline proc(name: string) -> u64
{
    return GL_PROFILER.timers[name].latest;
}
