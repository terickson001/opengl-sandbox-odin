package rendering

import "core:fmt"
import "core:math"
import "core:math/linalg"

Camera :: struct
{
    pos, dir        : [3]f32,
    up, right       : [3]f32,
    pitch, yaw      : f32,
    moved_speed     : f32,
    rotate_speed    : f32,
    detach          : bool,
    detach_key_down : f32,
}
