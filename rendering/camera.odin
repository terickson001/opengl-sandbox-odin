package rendering

import "core:fmt"
import "core:math"
import "core:math/linalg"

import "shared:glfw"

import "../control"

Camera :: struct
{
    pos, dir        : [3]f32,
    up, right       : [3]f32,
    pitch, yaw      : f32,
    move_speed      : f32,
    rotate_speed    : f32,
    detached        : bool,
    detach_key_down : f32,
}

make_camera :: proc(pos, dir: [3]f32, move_speed, rotate_speed: f32) -> (cam: Camera)
{

    cam.pos = pos;
    cam.dir = linalg.normalize(dir);
    cam.up  = {0, 1, 0};

    cam.yaw   = math.PI;
    cam.pitch = 0;
    cam.move_speed   = move_speed;
    cam.rotate_speed = rotate_speed;
    
    return cam;
}

get_camera_view :: proc(using cam: Camera) -> [4][4]f32
{
    return cast([4][4]f32)linalg.matrix4_look_at(
        cast(linalg.Vector3)cam.pos,
        cast(linalg.Vector3)(cam.pos + cam.dir),
        cast(linalg.Vector3)cam.up,
    );
}

update_camera_angle :: proc(win: Window, using cam: ^Camera, dt: f32)
{
    if detached do return;

    mpos := [2]f64{};
    mpos.x, mpos.y = glfw.get_cursor_pos(win.handle);
    glfw.set_cursor_pos(win.handle, f64(win.width/2), f64(win.height/2));

    yaw   += rotate_speed * dt * (f32(win.width) /2 - f32(mpos.x));
    pitch += rotate_speed * dt * (f32(win.height)/2 - f32(mpos.y));

    for yaw < 0 do yaw += 2*math.PI;
    for yaw >= 2*math.PI do yaw -= 2*math.PI;
    pitch = min(max(pitch, -(math.PI/2)), math.PI/2);

    dir = {
        math.cos(pitch) * math.sin(yaw),
        math.sin(pitch),
        math.cos(pitch) * math.cos(yaw)
    };

    right = {
        -math.cos(yaw),
        0,
        math.sin(yaw)
    };

    up = linalg.cross(right, dir);
}

update_camera_position :: proc(win: Window, cam: ^Camera, dt: f32)
{
    if control.get_keystate('[') == .Pressed
    {
        cam.detached = !cam.detached;
        if cam.detached do
            glfw.set_input_mode(win.handle, glfw.CURSOR, int(glfw.CURSOR_NORMAL));
        else do
            glfw.set_input_mode(win.handle, glfw.CURSOR, int(glfw.CURSOR_DISABLED));
    }
    if cam.detached do return;

    if control.key_down('W') do
        cam.pos += cam.dir * (dt*cam.move_speed);
    if control.key_down('S') do
        cam.pos -= cam.dir * (dt*cam.move_speed);

    if control.key_down('D') do
        cam.pos += cam.right * (dt*cam.move_speed);
    if control.key_down('A') do
        cam.pos -= cam.right * (dt*cam.move_speed);

    if control.key_down(' ') do
        cam.pos += cam.up * (dt*cam.move_speed);
    if control.key_down(int(glfw.KEY_LEFT_SHIFT)) do
        cam.pos -= cam.up * (dt*cam.move_speed);
}

update_camera :: proc(win: Window, cam: ^Camera, dt: f32)
{
    update_camera_angle(win, cam, dt);
    update_camera_position(win, cam, dt);
}
