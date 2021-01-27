package engine

import "core:fmt"
import "core:math/linalg"
import "core:math"
import "core:intrinsics"
import rt "core:runtime"
import "core:strings"
import "core:mem"
import "core:slice"

import "gui"
import "control"

import "core:os"
import "shared:gl"
import "shared:glfw"

Editor :: struct
{
    enabled: bool,
    
    spawn_menu: gui.Window,
    entity_window: gui.Window,
    settings_window: gui.Window,
    
    selected_entity: ^Entity,
    
    gizmo_mode: Gizmo_Mode,
    gizmo: Gizmo,
}

Gizmo_Mode :: enum u8
{
    Move, 
    Rotate, 
    Scale,
}

Gizmo :: struct
{
    parent: ^Entity,
    
    selected: ^Entity,
    offset: f32,
    start_pos: [3]f32,
    start_rot: quaternion128,
    
    shader: ^Shader,
    entities: [dynamic]Entity,
}

@static editor: Editor;

toggle_editor :: proc() { editor.enabled = !editor.enabled; }

init_editor :: proc(ctx: ^gui.Context)
{
    using editor;
    spawn_menu = gui.init_window(ctx, "Spawn Menu", {790, 34, 200, 700});
    spawn_menu.open = false;
    
    settings_window = gui.init_window(ctx, "Settings", {34, 34, 200, 700});
    init_gizmo();
}

open_spawn_menu :: proc(win: Window, ctx: ^gui.Context, scn: ^Scene)
{
    using editor;
    if !enabled do return;
    spawn_menu.open = true;
}

update_editor :: proc(win: Window, ctx: ^gui.Context, scn: ^Scene)
{
    using editor;
    
    if !enabled do return;
    
    if !ctx.capture_mouse && control.mouse_pressed(0)
    {
        view_mat := get_camera_view(scn.camera);
        mouse_ray := get_mouse_ray(win, scn.camera, view_mat, scn.camera.projection);
        select_entity(scene_test_ray(scn, mouse_ray));
    }
    
    if .Active in gui.window(ctx, &settings_window, {})
    {
        
        display_entity_data(ctx, selected_entity);
        gui.window_end(ctx);
    }
    
    if .Active in gui.window(ctx, &spawn_menu, {})
    {
        gui.row(ctx, 2, {100, 0}, 0);
        
        for name, entity in scn.base_entities
        {
            if .Submit in gui.button(ctx, name, 0, {})
            {
                append(&scn.entities, entity);
                select_entity(&scn.entities[len(scn.entities)-1]);
            }
        }
        
        gui.window_end(ctx);
    }
    
    // Update Gizmo
    GIZMO: if gizmo.selected != nil
    {
        if !control.mouse_down(0)
        {
            gizmo.selected = nil;
            gizmo.start_pos = {};
            break GIZMO;
        }
        
        // Reset Changes
        if control.mouse_pressed(1)
        {
            gizmo.selected = nil;
            gizmo.parent.pos = gizmo.start_pos;
            gizmo.parent.rot = gizmo.start_rot;
            break GIZMO;
        }
        
        // Manipulate
        part_name := gizmo.selected.name;
        action := part_name[:3];
        axis := part_name[4];
        DIRS := [3][3]f32{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
        switch action
        {
            case "trn":
            normal: [3]f32;
            
            switch axis
            {
                case 'x': normal = {0, 0, 1};
                case 'y': normal = {0, 0, 1};
                case 'z': normal = {1, 0, 0};
            }
            point := gizmo.parent.pos + DIRS[axis-'x']*gizmo.offset;
            ray := get_mouse_ray(win, scn.camera, scn.camera.view, scn.camera.projection);
            plane := Plane{point, normal};
            t, ok := cast_ray_plane(ray, plane);
            if !ok do break;
            
            intersect := ray.origin + ray.dir*t;
            
            delta := intersect - point;
            gizmo.parent.pos += delta * DIRS[axis-'x'];
            
            case "rot":
            normal := DIRS[axis-'x'];
            rel_x := DIRS[(axis-'x'+1)%3];
            ray := get_mouse_ray(win, scn.camera, scn.camera.view, scn.camera.projection);
            
            plane := Plane{gizmo.parent.pos, normal};
            t, ok := cast_ray_plane(ray, plane);
            if !ok do break;
            intersect := ray.origin + ray.dir*t;
            delta := intersect - gizmo.parent.pos;
            
            v1 := [2]f32{1, 0};
            v2 := [2]f32{delta[(axis-'x'+1)%3], delta[(axis-'x'+2)%3]};
            v3 := [2]f32{-v2.y, v2.x};
            v4 := [2]f32{linalg.dot(v1, v3), linalg.dot(v1, v2)};
            
            angle := math.atan2(v4.x, v4.y);
            q := cast(quaternion128)linalg.quaternion_angle_axis(gizmo.offset - angle, cast(linalg.Vector3)DIRS[axis-'x']);
            gizmo.parent.rot = q * gizmo.start_rot;
        }
    }
}

closest_point :: proc(a, b: [3]f32, p: [3]f32) -> [3]f32
{
    dir  := b - a;
    mag2 := linalg.dot(dir, dir);
    dot  := clamp(linalg.dot(p-a, dir) / mag2, 0, 1);
    proj := a + dot * dir;
    return proj;
}

draw_gizmo :: proc(shader: ^Shader)
{
    using editor;
    if gizmo.parent == nil do return;
    
    for e in &gizmo.entities
    {
        e.pos = gizmo.parent.pos;
        draw_entity(shader, e);
    }
}

select_entity :: proc(e: ^Entity)
{
    using editor;
    
    if selected_entity != nil 
    {
        selected_entity.wireframe = false;
    }
    
    selected_entity = e;
    gizmo.parent = selected_entity;
    if selected_entity != nil 
    {
        selected_entity.wireframe = true;
    }
}

get_mouse_clip :: proc(win: Window) -> [3]f32
{
    mouse := control.get_mouse_pos();
    clipspace := [3]f32{
        (2.0*mouse.x) / f32(win.width) - 1,
        1 - (2.0*mouse.y) / f32(win.height),
        -1,
    };
    return clipspace;
}

get_mouse_ray :: proc(win: Window, cam: Camera, view, projection: [4][4]f32) -> Ray
{
    mouse := control.get_mouse_pos();
    clipspace := [4]f32{
        (2.0*mouse.x) / f32(win.width) - 1,
        1 - (2.0*mouse.y) / f32(win.height),
        -1, 1
    };
    proj := projection;
    
    using linalg;
    cameraspace := mul(matrix4_inverse(cast(Matrix4)proj), clipspace);
    cameraspace = {cameraspace.x, cameraspace.y, -1, 0};
    worldspace := mul(matrix4_inverse(cast(Matrix4)view), cameraspace);
    
    ray: Ray;
    ray.origin = cam.pos;
    ray.dir = normalize(swizzle(worldspace, 0, 1, 2));
    
    return ray;
}

scene_test_ray :: proc(scn: ^Scene, ray: Ray) -> ^Entity
{
    using editor;
    min_t := f32(math.F32_MAX);
    min_entity: ^Entity;
    
    if gizmo.parent != nil
    {
        for e in &gizmo.entities
        {
            t, succ := cast_ray_aabb(ray, entity_get_bounds(e));
            if !succ do continue;
            
            t, succ = cast_ray_triangles(ray, e);
            if succ && t < min_t
            {
                min_t = t;
                min_entity = &e;
            }
        }
        
        if min_entity != nil
        {
            gizmo.selected = min_entity;
            
            part_name := gizmo.selected.name;
            action := part_name[:3];
            axis := part_name[4];
            DIRS := [3][3]f32{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
            switch action
            {
                case "trn":
                normal: [3]f32;
                
                switch axis
                {
                    case 'x': normal = {0, 0, 1};
                    case 'y': normal = {0, 0, 1};
                    case 'z': normal = {1, 0, 0};
                }
                plane := Plane{gizmo.parent.pos, normal};
                t, ok := cast_ray_plane(ray, plane);
                if !ok do break;
                intersect := ray.origin + ray.dir*t;
                
                delta := intersect - gizmo.parent.pos;
                gizmo.offset = delta[axis-'x'];
                
                case "rot":
                normal := DIRS[axis-'x'];
                rel_x := DIRS[(axis-'x'+1)%3];
                
                plane := Plane{gizmo.parent.pos, normal};
                t, ok := cast_ray_plane(ray, plane);
                if !ok do break;
                intersect := ray.origin + ray.dir*t;
                delta := intersect - gizmo.parent.pos;
                
                
                v1 := [2]f32{1, 0};
                v2 := [2]f32{delta[(axis-'x'+1)%3], delta[(axis-'x'+2)%3]};
                v3 := [2]f32{-v2.y, v2.x};
                v4 := [2]f32{linalg.dot(v1, v3), linalg.dot(v1, v2)};
                angle := math.atan2(v4.x, v4.y);
                gizmo.offset = angle;
            }
            gizmo.start_pos = gizmo.parent.pos;
            gizmo.start_rot = gizmo.parent.rot;
            return gizmo.parent;
        }
    }
    
    for e in &scn.entities
    {
        t, succ := cast_ray_aabb(ray, entity_get_bounds(e));
        if !succ do continue;
        
        if e.name == "wall_back" do fmt.printf("HIT AABB\n %v\n %v\n", e.bounds, entity_get_bounds(e));
        t, succ = cast_ray_triangles(ray, e);
        if succ && t < min_t
        {
            if e.name == "wall_back" do fmt.printf("HIT MESH\n");
            min_t = t;
            min_entity = &e;
        }
    }
    
    return min_entity;
}

display_type :: proc(ctx: ^gui.Context, label: string, data: rawptr, ti: ^rt.Type_Info)
{
    using rt;
    
    gui.SCOPE_ID(ctx, label);
    #partial switch kind in ti.variant
    {
        case Type_Info_Float:
        gui.row(ctx, 2, {0.2, 0}, 0);
        gui.label(ctx, fmt.tprintf("%s: ", label), {.Left});
        gui.number_input(ctx, fmt.tprintf("%s.num_input", label), cast(^f32)(data), "%.2f", 0,0,0, {.Left});
        
        case Type_Info_Integer:
        case Type_Info_String:
        gui.row(ctx, 2, {0.2, 0}, 0);
        gui.label(ctx, fmt.tprintf("%s: ", label), {.Left});
        buf: [256]byte;
        copy(buf[:], (cast(^string)(data))^);
        gui.text_input(ctx, fmt.tprintf("%s.text_input", label), buf[:], {.Left});
        
        case Type_Info_Array:
        if .Active in gui.section(ctx, label)
        {
            field_names := [?]string{"x", "y", "z", "w"};
            for i in 0..<(kind.count)
            {
                display_type(ctx, field_names[i], cast(rawptr)(uintptr(data) + uintptr(kind.elem_size*i)), kind.elem);
            }
        }
    }
}

display_entity_data :: proc(ctx: ^gui.Context, e: ^Entity)
{
    if e == nil do return;
    using rt;
    ti := type_info_base(type_info_of(type_of(e^))).variant.(Type_Info_Struct);
    
    gui.SCOPE_ID(ctx, e.name);
    
    data := cast(uintptr)e;
    for name, i in ti.names
    {
        if strings.contains(ti.tags[i], "noinspect") do continue;
        display_type(ctx, name, rawptr(data + ti.offsets[i]), ti.types[i]);
    }
}

init_gizmo :: proc()
{
    using editor;
    // if selected_entity == nil do return;
    
    LOD :: 10;
    R   :: 0.040;
    LEN :: 1;
    INT  :: math.TAU / LOD;
    DIRS := [3][3]f32{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
    
    cone:     ^Mesh;
    cylinder: ^Mesh;
    ring:     ^Mesh;
    for dir, d in DIRS
    {
        rel_x := DIRS[(d+1)%3];
        rel_y := DIRS[(d+2)%3];
        rel_z := DIRS[d];
        
        cone     = new(Mesh);
        cylinder = new(Mesh);
        ring     = new(Mesh);
        cone.vertices     = make([][3]f32, LOD*3);
        cylinder.vertices = make([][3]f32, LOD*6);
        ring.vertices     = make([][3]f32, LOD*6 * LOD*5);
        
        for i in 0..<LOD
        {
            using math;
            // Translate Head
            cone.vertices[i*3+0] = rel_x * cos(INT*f32(i)) * R * 2
                + rel_y * sin(INT*f32(i)) * R * 2
                + dir * LEN * 0.8;
            
            cone.vertices[i*3+1] = rel_x * cos(INT*(f32(i)+1)) * R * 2
                + rel_y * sin(INT*(f32(i)+1)) * R * 2
                + dir * LEN * 0.8;
            
            cone.vertices[i*3+2] = dir * LEN;
            
            // Translate Stem
            c1 := rel_x * cos(INT*f32(i)) * R
                + rel_y * sin(INT*f32(i)) * R;
            c2 := rel_x * cos(INT*f32(i)+1) * R
                + rel_y * sin(INT*f32(i)+1) * R;
            c3 := rel_x * cos(INT*f32(i)+1) * R
                + rel_y * sin(INT*f32(i)+1) * R
                + dir * LEN * 0.8;
            c4 := rel_x * cos(INT*f32(i)) * R
                + rel_y * sin(INT*f32(i)) * R
                + dir * LEN * 0.8;
            cylinder.vertices[i*6+0] = c1;
            cylinder.vertices[i*6+1] = c2;
            cylinder.vertices[i*6+2] = c3;
            cylinder.vertices[i*6+3] = c3;
            cylinder.vertices[i*6+4] = c4;
            cylinder.vertices[i*6+5] = c1;
            
            // Rotate Ring
            R_INT :: INT / 5;
            OR :: 1;
            IR :: R/2;
            for j in 0..<5
            {
                seg := i*5 + j;
                a1 := R_INT*f32(seg);
                a2 := R_INT*f32(seg+1);
                ca1 := cos(a1); ca2 := cos(a2);
                sa1 := sin(a1); sa2 := sin(a2);
                for k in 0..<LOD
                {
                    b1 := INT*f32(k);
                    b2 := INT*f32(k+1);
                    cb1 := cos(b1); cb2 := cos(b2);
                    sb1 := sin(b1); sb2 := sin(b2);
                    c1 := point((OR + IR*cb1) * ca1,
                                (OR + IR*cb1) * sa1,
                                IR * sb1,
                                rel_x, rel_y, rel_z
                                );
                    c2 := point((OR + IR*cb2) * ca1,
                                (OR + IR*cb2) * sa1,
                                IR * sb2,
                                rel_x, rel_y, rel_z
                                );
                    c3 := point((OR + IR*cb1) * ca2,
                                (OR + IR*cb1) * sa2,
                                IR * sb1,
                                rel_x, rel_y, rel_z
                                );
                    c4 := point((OR + IR*cb2) * ca2,
                                (OR + IR*cb2) * sa2,
                                IR * sb2,
                                rel_x, rel_y, rel_z
                                );
                    
                    ring.vertices[seg*LOD*6 + k*6 + 0] = c1;
                    ring.vertices[seg*LOD*6 + k*6 + 1] = c2;
                    ring.vertices[seg*LOD*6 + k*6 + 2] = c3;
                    ring.vertices[seg*LOD*6 + k*6 + 3] = c4;
                    ring.vertices[seg*LOD*6 + k*6 + 4] = c3;
                    ring.vertices[seg*LOD*6 + k*6 + 5] = c2;
                }
            }
            point :: proc(x, y, z: f32, dx, dy, dz: [3]f32) -> [3]f32
            {
                p := x * dx;
                p += y * dy;
                p += z * dz;
                return p;
            }
        }
        
        material := register_asset(&global_catalog, make_material(albedo = dir, shaded = false), fmt.aprintf("gizmo_color_%c", 'x'+d));
        
        cone.ctx = make_render_context(1, 0);
        cylinder.ctx = make_render_context(1, 0);
        ring.ctx = make_render_context(1, 0);
        bind_render_context(&cone.ctx);
        update_vbo(&cone.ctx, 0, cone.vertices);
        bind_render_context(&cylinder.ctx);
        update_vbo(&cylinder.ctx, 0, cylinder.vertices);
        bind_render_context(&ring.ctx);
        update_vbo(&ring.ctx, 0, ring.vertices);
        append(&gizmo.entities, make_entity(fmt.aprintf("trn_%c_head_gizmo", 'x'+d), cone, material));
        append(&gizmo.entities, make_entity(fmt.aprintf("trn_%c_stem_gizmo", 'x'+d), cylinder, material));
        append(&gizmo.entities, make_entity(fmt.aprintf("rot_%c_stem_gizmo", 'x'+d), ring, material));
        
        gizmo.shader = catalog_get_shader(&global_catalog, "shader/3d.glsl");
    }
    
}