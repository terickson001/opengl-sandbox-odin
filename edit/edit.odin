package edit

import "core:fmt"
import "core:math/linalg"
import "core:math"
import "core:intrinsics"
import rt "core:runtime"
import "core:strings"
import "core:mem"
import "core:slice"

import "../asset"
import "../gui"
import render "../rendering"
import "../scene"
import "../entity"
import "../control"

import "core:os"
import "shared:gl"
import "shared:glfw"

Editor :: struct
{
    enabled: bool,
    
    spawn_menu: gui.Window,
    entity_window: gui.Window,
    settings_window: gui.Window,
    
    selected_entity: ^entity.Entity,
    
    gizmo: Gizmo,
}

Gizmo :: struct
{
    parent: ^entity.Entity,
    mode: enum u8 {Move, Rotate, Scale},
    
    selected: ^entity.Entity,
    offset: f32,
    start: [3]f32,
    
    shader: ^render.Shader,
    entities: [dynamic]entity.Entity
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

open_spawn_menu :: proc(win: render.Window, ctx: ^gui.Context, scn: ^scene.Scene)
{
    using editor;
    if !enabled do return;
    spawn_menu.open = true;
}

update_editor :: proc(win: render.Window, ctx: ^gui.Context, scn: ^scene.Scene)
{
    using editor;
    
    if !enabled do return;
    
    if !ctx.capture_mouse && control.mouse_pressed(0)
    {
        view_mat := render.get_camera_view(scn.camera);
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
            gizmo.start = {};
            break GIZMO;
        }
        
        // Reset Changes
        if control.key_pressed(int(glfw.KEY_ESCAPE))
        {
            gizmo.selected = nil;
            gizmo.parent.pos = gizmo.start;
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
            ray := get_mouse_ray(win, scn.camera, scn.camera.view, scn.camera.projection);
            diff := ray.origin - gizmo.parent.pos;
            prod :=  linalg.dot(diff, normal);
            prod2 := linalg.dot(ray.dir, normal);
            prod3 := prod / prod2;
            intersect := ray.origin - ray.dir*prod3;
            
            delta := intersect - gizmo.parent.pos;
            gizmo.parent.pos += delta * DIRS[axis-'x']; 
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

draw_gizmo :: proc(shader: ^render.Shader)
{
    using editor;
    if gizmo.parent == nil do return;
    
    for e in &gizmo.entities
    {
        e.pos = gizmo.parent.pos;
        entity.draw_entity(shader, e);
    }
}

select_entity :: proc(e: ^entity.Entity)
{
    using editor;
    
    if selected_entity != nil 
    {
        selected_entity.wireframe = false;
    }
    
    selected_entity = e;
    if selected_entity != nil 
    {
        selected_entity.wireframe = true;
        gizmo.parent = selected_entity;
    }
}

get_mouse_clip :: proc(win: render.Window) -> [3]f32
{
    mouse := control.get_mouse_pos();
    clipspace := [3]f32{
        (2.0*mouse.x) / f32(win.width) - 1,
        1 - (2.0*mouse.y) / f32(win.height),
        -1,
    };
    return clipspace;
}

get_mouse_ray :: proc(win: render.Window, cam: render.Camera, view, projection: [4][4]f32) -> entity.Ray
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
    
    ray: entity.Ray;
    ray.origin = cam.pos;
    ray.dir = normalize(swizzle(worldspace, 0, 1, 2));
    
    return ray;
}

scene_test_ray :: proc(scn: ^scene.Scene, ray: entity.Ray) -> ^entity.Entity
{
    using editor;
    min_t := f32(math.F32_MAX);
    min_entity: ^entity.Entity;
    
    if gizmo.parent != nil
    {
        for e in &gizmo.entities
        {
            t, succ := entity.cast_ray_aabb(ray, entity.get_bounds(e));
            if !succ do continue;
            
            t, succ = entity.cast_ray_triangles(ray, e);
            if succ && t < min_t
            {
                min_t = t;
                min_entity = &e;
            }
            // @todo(Tyler): Find intersection offset for proper alignment
        }
        
        if min_entity != nil
        {
            gizmo.selected = min_entity;
            gizmo.start = min_entity.pos;
            return gizmo.parent;
        }
    }
    
    for e in &scn.entities
    {
        t, succ := entity.cast_ray_aabb(ray, entity.get_bounds(e));
        if !succ do continue;
        
        t, succ = entity.cast_ray_triangles(ray, e);
        if succ && t < min_t
        {
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

display_entity_data :: proc(ctx: ^gui.Context, e: ^entity.Entity)
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
    
    cone: ^render.Mesh;
    cylinder: ^render.Mesh;
    for dir, d in DIRS
    {
        rel_x := DIRS[(d+1)%3];
        rel_z := DIRS[(d+2)%3];
        
        cone     = new(render.Mesh);
        cylinder = new(render.Mesh);
        cone.vertices     = make([][3]f32, LOD*3);
        cylinder.vertices = make([][3]f32, LOD*6);
        
        
        for i in 0..<LOD
        {
            using math;
            // Translate Head
            cone.vertices[i*3+0] = rel_x * cos(INT*f32(i)) * R * 2
                + rel_z * sin(INT*f32(i)) * R * 2
                + dir * LEN * 0.8;
            
            cone.vertices[i*3+1] = rel_x * cos(INT*(f32(i)+1)) * R * 2
                + rel_z * sin(INT*(f32(i)+1)) * R * 2
                + dir * LEN * 0.8;
            
            cone.vertices[i*3+2] = dir * LEN;
            
            // Translate Stem
            c1 := rel_x * cos(INT*f32(i)) * R
                + rel_z * sin(INT*f32(i)) * R;
            c2 := rel_x * cos(INT*f32(i)+1) * R
                + rel_z * sin(INT*f32(i)+1) * R;
            c3 := rel_x * cos(INT*f32(i)+1) * R
                + rel_z * sin(INT*f32(i)+1) * R
                + dir * LEN * 0.8;
            c4 := rel_x * cos(INT*f32(i)) * R
                + rel_z * sin(INT*f32(i)) * R
                + dir * LEN * 0.8;
            cylinder.vertices[i*6+0] = c1;
            cylinder.vertices[i*6+1] = c2;
            cylinder.vertices[i*6+2] = c3;
            cylinder.vertices[i*6+3] = c3;
            cylinder.vertices[i*6+4] = c4;
            cylinder.vertices[i*6+5] = c1;
        }
        
        
        material := asset.register(&asset.global_catalog, render.make_material(albedo = dir, shaded = false), fmt.aprintf("gizmo_color_%c", 'x'+d));
        
        fmt.printf("MATERIAL: %#v\n", material);
        cone.ctx = render.make_context(1, 0);
        cylinder.ctx = render.make_context(1, 0);
        render.bind_context(&cone.ctx);
        render.update_vbo(&cone.ctx, 0, cone.vertices);
        render.bind_context(&cylinder.ctx);
        render.update_vbo(&cylinder.ctx, 0, cylinder.vertices);
        append(&gizmo.entities, entity.make_entity(fmt.aprintf("trn_%c_head_gizmo", 'x'+d), cone, material));
        append(&gizmo.entities, entity.make_entity(fmt.aprintf("trn_%c_stem_gizmo", 'x'+d), cylinder, material));
        
        gizmo.shader = asset.get_shader(&asset.global_catalog, "shader/3d.glsl");
    }
}