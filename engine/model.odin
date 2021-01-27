package engine

import "core:math"
import "core:math/linalg"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:mem"

import "shared:gl"
import "shared:compress/zlib"

import "util"

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
    using ctx: Render_Context,
}

@(private="file")
is_near :: inline proc(v1: f32, v2: f32) -> bool
{
    return abs(v1-v2) < 0.01;
}

@(private="file")
_get_similar_vertex :: proc(vert: [3]f32, norm: [3]f32, uv: [2]f32, verts: [][3]f32, norms: [][3]f32, uvs: [][2]f32) -> (u16, bool)
{
    for _, i in verts
    {
        if  is_near(vert.x, verts[i].x) &&
            is_near(vert.y, verts[i].y) &&
            is_near(vert.z, verts[i].z) &&
            is_near(norm.x, norms[i].x) &&
            is_near(norm.y, norms[i].y) &&
            is_near(norm.z, norms[i].z) &&
            is_near(uv.x,   uvs  [i].x) &&
            is_near(uv.y,   uvs  [i].y)
        {
            return u16(i), true;
        }
    }
    
    return 0, false;
}

index_mesh :: proc(m: ^Mesh)
{
    indices := make([dynamic]u16);
    
    temp_verts := make([dynamic][3]f32);
    temp_norms := make([dynamic][3]f32);
    temp_uvs   := make([dynamic][2]f32);
    
    temp_tangents   := make([dynamic][3]f32);
    temp_bitangents := make([dynamic][3]f32);
    
    for _, i in m.vertices
    {
        index, found := _get_similar_vertex(m.vertices[i], m.normals[i], m.uvs[i],
                                            temp_verts[:], temp_norms[:], temp_uvs[:]);
        
        if found
        {
            append(&indices, index);
            temp_tangents[index]   += m.tangents[i];
            temp_bitangents[index] += m.bitangents[i];
        }
        else
        {
            append(&temp_verts,      m.vertices[i]);
            append(&temp_norms,      m.normals[i]);
            append(&temp_uvs,        m.uvs[i]);
            append(&temp_tangents,   m.tangents[i]);
            append(&temp_bitangents, m.bitangents[i]);
            
            new_index := u16(len(temp_verts)-1);
            append(&indices, new_index);
        }
    }
    
    delete(m.vertices);
    delete(m.normals);
    delete(m.uvs);
    delete(m.tangents);
    delete(m.bitangents);
    
    m.vertices   = temp_verts[:];
    m.normals    = temp_norms[:];
    m.uvs        = temp_uvs[:];
    m.tangents   = temp_tangents[:];
    m.bitangents = temp_bitangents[:];
    m.indices    = indices[:];
    
    m.indexed = true;
}

@(private="file")
_compute_tangent_basis_indexed :: proc(m: ^Mesh)
{
    m.tangents = make([][3]f32, len(m.vertices));
    i := 0;
    for i < len(m.indices)
    {
        i0 := m.indices[i+0];
        i1 := m.indices[i+1];
        i2 := m.indices[i+2];
        
        v0 := m.vertices[i0];
        v1 := m.vertices[i1];
        v2 := m.vertices[i2];
        
        uv0 := m.uvs[i0];
        uv1 := m.uvs[i1];
        uv2 := m.uvs[i2];
        
        delta_pos0 := v1 - v0;
        delta_pos1 := v2 - v0;
        
        delta_uv0 := uv1 - uv0;
        delta_uv1 := uv2 - uv0;
        
        r: f32 = 1.0 / (delta_uv0.x*delta_uv1.y - delta_uv0.y*delta_uv1.x);
        
        tangent := (delta_pos0*delta_uv1.y - delta_pos1*delta_uv0.y) * r;
        
        m.tangents[i0] = tangent;
        m.tangents[i1] = tangent;
        m.tangents[i2] = tangent;
        
        i += 3;
    }
}

@(private="file")
_compute_tangent_basis_unindexed :: proc(m: ^Mesh)
{
    m.tangents = make([][3]f32, len(m.vertices));
    i := 0;
    for i < len(m.vertices)
    {
        v0 := m.vertices[i+0];
        v1 := m.vertices[i+1];
        v2 := m.vertices[i+2];
        
        uv0 := m.uvs[i+0];
        uv1 := m.uvs[i+1];
        uv2 := m.uvs[i+2];
        
        delta_pos0 := v1 - v0;
        delta_pos1 := v2 - v0;
        
        delta_uv0 := uv1 - uv0;
        delta_uv1 := uv2 - uv0;
        
        r: f32 = 1.0 / (delta_uv0.x*delta_uv1.y - delta_uv0.y*delta_uv1.x);
        
        tangent := (delta_pos0*delta_uv1.y - delta_pos1*delta_uv0.y) * r;
        
        m.tangents[i] = tangent;
        m.tangents[i+1] = tangent;
        m.tangents[i+2] = tangent;
        
        i += 3;
    }
}

compute_tangent_basis :: proc(m: ^Mesh)
{
    if m.indexed do _compute_tangent_basis_indexed(m);
    else do         _compute_tangent_basis_unindexed(m);
    
    m.bitangents = make([][3]f32, len(m.vertices));
    for _, i in m.vertices
    {
        t := &m.tangents[i];
        n := m.normals[i];
        
        t^ = linalg.normalize(t^ - n * linalg.dot(n, t^));
        m.bitangents[i] = linalg.cross(n, t^);
    }
}

create_mesh_vbos :: proc(using m: ^Mesh)
{
    ctx = make_render_context(5, 0, indexed);
    
    bind_render_context(&ctx);
    
    update_vbo(&ctx, 0, vertices[:]);
    update_vbo(&ctx, 1, uvs[:]);
    update_vbo(&ctx, 2, normals[:]);
    update_vbo(&ctx, 3, tangents[:]);
    update_vbo(&ctx, 4, bitangents[:]);
    
    if indexed 
    {
        update_ebo(&ctx, indices[:]);
    }
}

mesh_invert_uvs :: proc(m: ^Mesh)
{
    for _, i in m.uvs 
    {
        m.uvs[i].y = 1.0 - m.uvs[i].y;
    }
}

/*
make_mesh :: proc(filepath: string, normals: bool, invert_uv: bool) -> Mesh
{
    mesh := load_obj(filepath);
    if normals do compute_tangent_basis(&mesh);
    index_mesh(&mesh);
    if invert_uv do mesh_invert_uvs(&mesh);
    
    return mesh;
}
*/

draw_model :: proc(s: ^Shader, m: ^Mesh)
{
    bind_render_context(&m.ctx);
    
    if m.indexed 
    {
        gl.DrawElements(gl.TRIANGLES, i32(len(m.indices)), gl.UNSIGNED_SHORT, nil);
    }
    else 
    {
        gl.DrawArrays(gl.TRIANGLES, 0, i32(len(m.vertices)));
    }
}

delete_model :: proc (m: ^Mesh)
{
    delete_render_context(&m.ctx);
    
    delete(m.vertices);
    delete(m.uvs);
    delete(m.normals);
    delete(m.indices);
    delete(m.tangents);
    delete(m.bitangents);
    
    m.vertices   = nil;
    m.uvs        = nil;
    m.normals    = nil;
    m.indices    = nil;
    m.tangents   = nil;
    m.bitangents = nil;
}


load_obj_from_mem :: proc(data: []byte) -> Mesh
{
    file := string(data);
    m := Mesh{};
    
    vert_indices := make([dynamic]u16);
    norm_indices := make([dynamic]u16);
    uv_indices   := make([dynamic]u16);
    
    temp_verts := make([dynamic][3]f32);
    temp_norms := make([dynamic][3]f32);
    temp_uvs   := make([dynamic][2]f32);
    
    defer
    {
        delete(temp_verts);
        delete(temp_norms);
        delete(temp_uvs);
        
        delete(vert_indices);
        delete(norm_indices);
        delete(uv_indices);
    }
    
    for len(file) > 0
    {
        if file[0] == '#'
        {
            util.read_line(&file, nil);
            continue;
        }
        
        header: string;
        if !util.read_fmt(&file, "%s ", &header) 
        {
            break;
        }
        
        if header == "v"
        {
            vert := [3]f32{};
            util.read_fmt(&file, "%f %f %f%>", &vert.x, &vert.y, &vert.z);
            append(&temp_verts, vert);
        }
        else if header == "vn"
        {
            norm := [3]f32{};
            util.read_fmt(&file, "%f %f %f%>", &norm.x, &norm.y, &norm.z);
            
            append(&temp_norms, norm);
        }
        else if header == "vt"
        {
            uv := [2]f32{};
            util.read_fmt(&file, "%f %f%>", &uv.x, &uv.y);
            append(&temp_uvs, uv);
        }
        else if header == "f"
        {
            vi, ni, uvi : [3]u16;
            util.read_fmt(&file, "%d/%d/%d %d/%d/%d %d/%d/%d%>",
                          &vi[0], &uvi[0], &ni[0],
                          &vi[1], &uvi[1], &ni[1],
                          &vi[2], &uvi[2], &ni[2]
                          );
            append(&vert_indices, ..vi[:]);
            append(&norm_indices, ..ni[:]);
            append(&uv_indices,   ..uvi[:]);
        }
        else if header == "s" || header == "usemtl"
        {
            util.read_line(&file, nil);
        }
    }
    
    m.vertices = make([][3]f32, len(vert_indices));
    m.normals = make([][3]f32, len(norm_indices));
    m.uvs = make([][2]f32, len(uv_indices));
    
    for v, i in vert_indices 
    {
        m.vertices[i] = temp_verts[v-1];
    }
    for n, i in norm_indices 
    {
        m.normals[i] = temp_norms[n-1];
    }
    for uv, i in uv_indices 
    {
        m.uvs[i] = temp_uvs[uv-1];
    }
    
    return m;
}

load_obj :: proc(filepath : string) -> Mesh
{
    data, ok := os.read_entire_file(filepath);
    if !ok
    {
        fmt.eprintf("Couldn't open .obj %q for reading\n", filepath);
        return Mesh{};
    }
    
    return load_obj_from_mem(data);
}

@(private="file")
Fbx_Reader :: struct
{
    whole_file: []byte,
    data: []byte,
}

Fbx_Node :: struct
{
    end_offset: u64,
    name: string,
    properties: []Fbx_Property,
    children: map[string]Fbx_Node,
}

Fbx_Property :: union
{
    i16,
    
    i32,
    []i32,
    
    i64,
    []i64,
    
    b8,
    []b8,
    
    f32,
    []f32,
    
    f64,
    []f64,
    
    string,
    []byte,
}

load_fbx :: proc(filepath: string) -> Model
{
    file, ok := os.read_entire_file(filepath);
    if !ok
    {
        fmt.eprintf("Could not open file %q\n", filepath);
        return {};
    }
    return load_fbx_from_mem(file, filepath);
}

load_fbx_from_mem :: proc(in_data: []byte, file := "<MEM>") -> Model
{
    using reader := Fbx_Reader{in_data, in_data};
    
    magic := _read_string(&data, 21);
    sig := _read_type(&data, u16);
    if fbx_err(magic != "Kaydara FBX Binary  \x00", "Invalid Magic", file) ||
        fbx_err(sig != 0x001A, "Invalid Signature", file) 
    {
        return {};
    }
    
    
    version := _read_type(&data, u32);
    if fbx_err(version > 7400, "Unsupported FBX version %0.1f\n", file) 
    {
        return {};
    }
    
    nodes := make(map[string]Fbx_Node);
    
    for len(data) > 176
    {
        node := read_node(&reader);
        if node.name != "" 
        {
            nodes[node.name] = node;
        }
    }
    
    model := Model{};
    
    geom := nodes["Objects"].children["Geometry"];
    // fmt.println(nodes);
    // print_node(&nodes["Objects"]);
    {
        using model;
        polygon_indices := geom.children["PolygonVertexIndex"].properties[0].([]i32);
        poly_size := 1;
        for polygon_indices[poly_size-1] >= 0 do poly_size += 1;
        
        vertices := mem.slice_data_cast([][3]f64, geom.children["Vertices"].properties[0].([]f64));
        
        normals: []f64;
        normal_indices: []i32;
        normal_mapping: Fbx_Mapping;
        {
            normal := geom.children["LayerElementNormal"];
            normals = normal.children["Normals"].properties[0].([]f64);
            ref_type := normal.children["ReferenceInformationType"].properties[0].(string);
            if ref_type == "IndexToDirect" 
            {
                normal_indices = normal.children["NormalsIndex"].properties[0].([]i32);
            }
            normal_mapping = fbx_mapping_string(normal.children["MappingInformationType"].properties[0].(string));
        }
        
        uvs: []f64;
        uv_indices: []i32;
        uv_mapping: Fbx_Mapping;
        {
            uv := geom.children["LayerElementUV"];
            uvs = uv.children["UV"].properties[0].([]f64);
            ref_type := uv.children["ReferenceInformationType"].properties[0].(string);
            if ref_type == "IndexToDirect" 
            {
                uv_indices = uv.children["UVIndex"].properties[0].([]i32);
            }
            uv_mapping = fbx_mapping_string(uv.children["MappingInformationType"].properties[0].(string));
        }
        
        switch poly_size
        {
            case 4: {
                quad_indices := mem.slice_data_cast([][4]i32, polygon_indices);
                mesh.vertices = make([][3]f32, len(quad_indices) * 6);
                for poly, i in quad_indices
                {
                    mesh.vertices[6*i + 0] = cast_vertex(vertices[ poly[0]]);
                    mesh.vertices[6*i + 1] = cast_vertex(vertices[ poly[1]]);
                    mesh.vertices[6*i + 2] = cast_vertex(vertices[ poly[2]]);
                    
                    mesh.vertices[6*i + 3] = cast_vertex(vertices[~poly[3]]);
                    mesh.vertices[6*i + 4] = cast_vertex(vertices[ poly[0]]);
                    mesh.vertices[6*i + 5] = cast_vertex(vertices[ poly[2]]);
                }
                
                // Normals
                {
                    mapped_normals: []f32;
                    if normal_indices != nil 
                    {
                        mapped_normals = map_layer_element_indexed(normals, normal_indices, normal_mapping, quad_indices, nil);
                    }
                    else 
                    {
                        mapped_normals = map_layer_element_direct(normals, normal_mapping, quad_indices, nil);
                    }
                    mesh.normals = mem.slice_data_cast([][3]f32, mapped_normals);
                }
                
                // UVs
                {
                    mapped_uvs: []f32;
                    if uv_indices != nil 
                    {
                        mapped_uvs = map_layer_element_indexed(uvs, uv_indices, uv_mapping, quad_indices, nil);
                    }
                    else 
                    {
                        mapped_uvs = map_layer_element_direct(uvs, uv_mapping, quad_indices, nil);
                    }
                    mesh.uvs = mem.slice_data_cast([][2]f32, mapped_uvs);
                }
            }
            
            case 3: {
                tri_indices := mem.slice_data_cast([][4]i32, polygon_indices);
                mesh.vertices = make([][3]f32, len(tri_indices)*3);
                for poly, i in tri_indices
                {
                    mesh.vertices[3*i + 0] = cast_vertex(vertices[ poly[0]]);
                    mesh.vertices[3*i + 1] = cast_vertex(vertices[ poly[1]]);
                    mesh.vertices[3*i + 2] = cast_vertex(vertices[~poly[2]]);
                }
                
                // Normals
                {
                    mapped_normals: []f32;
                    if normal_indices != nil 
                    {
                        mapped_normals = map_layer_element_indexed(normals, normal_indices, normal_mapping, tri_indices, nil);
                    }
                    else 
                    {
                        mapped_normals = map_layer_element_direct(normals, normal_mapping, tri_indices, nil);
                    }
                    mesh.normals = mem.slice_data_cast([][3]f32, mapped_normals);
                }
                
                // UVs
                {
                    mapped_uvs: []f32;
                    if uv_indices != nil 
                    {
                        mapped_uvs = map_layer_element_indexed(uvs, uv_indices, uv_mapping, tri_indices, nil);
                    }
                    else 
                    {
                        mapped_uvs = map_layer_element_direct(uvs, uv_mapping, tri_indices, nil);
                    }
                    mesh.uvs = mem.slice_data_cast([][2]f32, mapped_uvs);
                }
            }
        }
    }
    
    return model;
    
    cast_vertex :: proc(vert: [$N]f64) -> (ret: [N]f32)
    {
        for i in 0..<N do ret[i] = f32(vert[i]);
        return ret;
    }
}

Fbx_Mapping :: enum u8
{
    Vertex,
    Polygon,
    Polygon_Vertex,
    Edge,
    Edge_Vertex,
    All_Same,
}

fbx_mapping_string :: proc(name: string) -> Fbx_Mapping
{
    switch name
    {
        case "ByVertex":        return .Vertex;
        case "ByPolygonVertex": return .Polygon_Vertex;
        case "ByPolygon":       return .Polygon;
        case "ByEdge":          return .Edge;
        case "ByEdgeVertex":    return .Edge_Vertex;
        case "AllSame":         return .All_Same;
    }
    return nil;
}

map_layer_element_direct :: proc(values: []f64, by: Fbx_Mapping, poly_indices: [][$N]i32, edge_indices: []i32) -> []f32
{
    dims := len(values) / (len(poly_indices)*N);
    when N == 3
    {
        out := make([]f32, len(poly_indices)*3*dims);
        #partial switch by
        {
            case .Polygon_Vertex: {
                for v, i in values do out[i] = f32(v);
                return out;
            }
            case: fmt.eprintf("ERROR: Unsupported FBX mapping type\n");
        }
    }
    else when N == 4
    {
        
        ORDERING :: [6]int{0, 1, 2, 3, 0, 2};
        out := make([]f32, len(poly_indices)*3*2*dims);
        #partial switch by
        {
            case .Polygon_Vertex: {
                for poly, i in poly_indices
                {
                    for ord, j in ORDERING 
                    {
                        for k in 0..<dims
                        {
                            out[(dims*3*2*i) + (j*dims) + k] = f32(values[(dims*4*i) + (ord*dims) + k]);
                        }
                    }
                }
                return out;
            }
            case: fmt.eprintf("ERROR: Unsupported FBX mapping type\n");
        }
    }
    return nil;
}

map_layer_element_indexed :: proc(values: []f64, indices: []i32, by: Fbx_Mapping, poly_indices: [][$N]i32, edge_indices: []i32) -> []f32
{
    max_index := 0;
    for i in indices 
    {
        max_index = max(max_index, int(i));
    }
    dims := len(values)/(max_index+1);
    when N == 3
    {
        out := make([]f32, len(poly_indices)*3*dims);
        #partial switch by
        {
            case .Polygon_Vertex: {
                for idx, i in indices do out[i] = f32(values[idx]);
                return out;
            }
            case: fmt.eprintf("ERROR: Unsupported FBX mapping type\n");
        }
    }
    else when N == 4
    {
        ORDERING :: [6]int{0, 1, 2, 3, 0, 2};
        out := make([]f32, len(poly_indices)*3*2*dims);
        #partial switch by
        {
            case .Polygon_Vertex: {
                for poly, i in poly_indices
                {
                    for ord, j in ORDERING 
                    {
                        for k in 0..<dims
                        {
                            out[(dims*3*2*i) + (j*dims) + k] = f32(values[dims * int(indices[(4*i) + ord]) + k]);
                        }
                    }
                }
                return out;
            }
            case: fmt.eprintf("ERROR: Unsupported FBX mapping type\n");
        }
    }
    return nil;
}

print_node :: proc(node: ^Fbx_Node, level := 0)
{
    indent := "";
    for i in 0..<level 
    {
        indent = fmt.tprintf("%s    ", indent);
    }
    
    fmt.printf("%s%s: %v {{\n", indent, node.name, node.properties);
    
    for k, v in &node.children
    {
        print_node(&v, level+1);
        fmt.printf(",\n");
    }
    fmt.printf("%s}}", indent);
    if level == 0 
    {
        fmt.printf("\n");
    }
    
}

read_node :: proc(using reader: ^Fbx_Reader) -> Fbx_Node
{
    node := Fbx_Node{};
    
    node.end_offset = u64(_read_type(&data, u32));
    num_properties := _read_type(&data, u32);
    properties_len := _read_type(&data, u32);
    name_len := _read_type(&data, u8);
    node.name = _read_string(&data, int(name_len));
    
    node.properties = make([]Fbx_Property, num_properties);
    for p in &node.properties 
    {
        p = read_property(&data);
    }
    
    offset := len(whole_file)-len(data);
    
    if offset < int(node.end_offset)
    {
        node.children = make(map[string]Fbx_Node);
        for offset != int(node.end_offset)-13
        {
            child := read_node(reader);
            node.children[child.name] = child;
            offset = len(whole_file)-len(data);
        }
        reader.data = reader.data[13:]; // skip null record
    }
    
    offset = len(whole_file)-len(data);
    
    return node;
}

read_property :: proc(data: ^[]byte) -> Fbx_Property
{
    type_code := _read_type(data, u8);
    prop := Fbx_Property{};
    
    switch type_code
    {
        case 'Y': prop = _read_type(data, i16);
        
        case 'i': prop = read_array_property(data, i32);
        case 'I': prop = _read_type(data, i32);
        
        case 'l': prop = read_array_property(data, i64);
        case 'L': prop = _read_type(data, i64);
        
        case 'b': prop = read_array_property(data, b8);
        case 'C': prop = _read_type(data, b8);
        
        case 'f': prop = read_array_property(data, f32);
        case 'F': prop = _read_type(data, f32);
        
        case 'd': prop = read_array_property(data, f64);
        case 'D': prop = _read_type(data, f64);
        
        case 'S', 'R':
        length := _read_type(data, u32);
        str := _read_string(data, int(length));
        if type_code == 'R' 
        {
            prop = transmute([]byte)(str);
        }
        else 
        {
            prop = str;
        }
        
        case:
        fmt.eprintf("INVALID PROPERTY TYPE: %x\n", type_code);
    }
    
    return prop;
}

read_array_property :: proc(data: ^[]byte, $T: typeid) -> Fbx_Property
{
    count := _read_type(data, i32);
    encoding := _read_type(data, u32);
    compressed_size := _read_type(data, u32);
    compressed := transmute([]byte)_read_string(data, int(compressed_size));
    
    array := make([]T, count);
    
    if encoding == 0 // raw data
    {
        for a in &array 
        {
            a = _read_type(&compressed, T);
        }
    }
    else // deflate/zip
    {
        z_buff := zlib.read_block(compressed);
        zlib.decompress(&z_buff);
        decompressed := z_buff.out[:];
        
        for a in &array 
        {
            a = _read_type(&decompressed, T);
        }
    }
    
    return array;
}

@private
fbx_err :: proc(test: bool, message: string, file: string, loc := #caller_location) -> bool
{
    if test 
    {
        fmt.eprintf("%#v: ERROR: %s: %s\n", loc, file, message);
    }
    
    return test;
}

@(private="file")
_read_type :: proc(file: ^[]byte, $T: typeid, loc := #caller_location) -> T
{
    if len(file^) < size_of(T)
    {
        fmt.eprintf("%#v: Expected %v, got EOF\n", loc, typeid_of(T));
        return T{};
    }
    
    ret := ((^T)(&file[0]))^;
    file^ = file[size_of(T):];
    
    return ret;
}

@(private="file")
_read_sized :: proc(data :^[]byte, size: int, loc := #caller_location) -> rawptr
{
    if len(data^) < size
    {
        fmt.eprintf("%#v: Expected %d bytes, got %d\n", loc, size, len(data^));
        return nil;
    }
    
    ret := &data[0];
    data^ = data[size:];
    
    return ret;
}

@(private="file")
_read_string :: proc(data: ^[]byte, size := -1, skip_null := false, loc := #caller_location) -> string
{
    if size >= 0 && len(data^) < size
    {
        fmt.eprintf("%#v: Expected string, got EOF\n", loc, );
        return string{};
    }
    
    if size >= 0
    {
        str := string(data[:size]);
        if skip_null && data[size+1] == 0 
        {
            data^ = data[size+1:];
        }
        else 
        {
            data^ = data[size:];
        }
        return str;
    }
    
    size := 0;
    for size < len(data^)
    {
        if data[size] == 0
        {
            str := string(data[:size]);
            data^ = data[size+1:];
            return str;
        }
        size += 1;
    }
    
    return string{};
}