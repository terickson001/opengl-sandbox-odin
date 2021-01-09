package model

import "core:math"
import "core:math/linalg"
import "core:fmt"

import "core:os"
import "core:strings"
import "shared:gl"

import "../../util"

Model :: struct
{
    mesh: Mesh,
    animations: []Keyframed_Animation
}

Mesh :: struct
{
    vertices   : [][3]f32,
    uvs        : [][2]f32,
    normals    : [][3]f32,
    tangents   : [][3]f32,
    bitangents : [][3]f32,
    
    indexed    : bool,
    indices    : []u16,
}