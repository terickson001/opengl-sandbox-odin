package rendering

import "core:fmt"
import "core:os"
import "../util"

Keyframed_Animation :: struct
{
    name: string,
    
    frame_rate: int,
    duration: f64,
    
    nodes: []Node,
}

Node :: struct
{
    
}

Transform :: struct
{
    translation: [3]f32,
    rotation: quaternion128,
    scale: [3]f32,
}