package graph

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg"

Safety :: enum { UNKNOWN, SAFE, UNSAFE }

Node :: struct {
    using position : [2]f32,
    previous : union{int},
    on_path : bool,
    faces_calculated : bool
}

Edge :: struct {
    using endpoints : [2]int,
    lethal : bool,
    protected : bool,
    safety : Safety
}

Face :: struct {
    edges : [dynamic]int,
    count : int
}

Graph :: struct {
    nodes : [dynamic]Node,
    edges : [dynamic]Edge,
    faces : [dynamic]Face,
    width : f32,
    height : f32
}

distance_sq :: proc(a, b : [2]f32) -> f32
{
    return (a.x - b.x)*(a.x - b.x) + (a.y - b.y)*(a.y - b.y)
}

intersect :: proc(a, b, c, d : [2]f32) -> bool
{
    u := a - c
    v := b - c
    M := linalg.Matrix2f32{
        u.x, v.x, u.y, v.y
    }
    iM := linalg.matrix2x2_inverse(M)
    g := d - c
    coordinates := [2]f32{
        iM[0, 0] * g.x + iM[0, 1] * g.y,
        iM[1, 0] * g.x + iM[1, 1] * g.y
    }
    return coordinates.x >= 0 && coordinates.y >= 0 && coordinates.x + coordinates.y >= 1
}

random_lethal_edge :: proc(graph : Graph) -> int
{
    choice : int
    for edge, edge_id in graph.edges
    {
        if edge.lethal do if rand.float32() < 1 / f32(edge_id + 1)
        {
            choice = edge_id
        }
    }

    return choice
}

atan3 :: proc(x, y, theta0 : f32) -> f32
{
    theta := math.atan2(y, x)
    if theta < 0 do theta += 2*math.PI
    if theta < theta0
    {
        theta = theta + 2*math.PI
    }
    return theta - theta0
}

deg :: proc(rad : f32) -> int
{
    return int(rad * 180/math.PI)
}

circular_walk :: proc(graph : Graph, current_node_index, last_edge_index : int) -> (next_node_index : int, next_edge_index : int)
{
    last_edge := graph.edges[last_edge_index].endpoints
    previous_node_index := last_edge[0] if last_edge[1] == current_node_index else last_edge[1]
    
    current_node := graph.nodes[current_node_index]
    previous_node := graph.nodes[previous_node_index]

    vector := previous_node.position - current_node.position
    theta0 := math.atan2(vector[1], vector[0])
    if theta0 < 0 do theta0 += 2*math.PI

    next_node_index = previous_node_index
    next_edge_index = last_edge_index
    best_angle : f32 = math.inf_f32(1)

    // fmt.println("   base", deg(theta0))

    iterator := Neighbors{ graph=graph, source=current_node_index }
    for neighbor_index, edge_index in neighbors(&iterator)
    {
        if edge_index == last_edge_index do continue
        
        neighbor := graph.nodes[neighbor_index]
        vector := neighbor.position - current_node.position
        angle := atan3(vector[0], vector[1], theta0)
        
        // fmt.println("  ", neighbor_index, deg(angle))

        if angle < best_angle
        {
            best_angle = angle
            next_node_index = neighbor_index
            next_edge_index = edge_index
        }
    }

    return
}

find_faces :: proc(graph : ^Graph)
{
    for node, node_index in graph.nodes
    {
        // fmt.println("from", node_index)

        iterator := Neighbors{ graph=graph^, source=node_index }
        for neighbor, edge_index in neighbors(&iterator)
        {
            face := Face{}
            append(&face.edges, edge_index)
            if graph.edges[edge_index].lethal
            {
                face.count += 1
            }

            is_face_valid := true

            current_node := neighbor
            last_edge := edge_index
            for current_node != node_index
            {
                // fmt.println(" go", current_node, last_edge)

                if graph.nodes[current_node].faces_calculated
                {
                    // we've already computed this face
                    delete(face.edges)
                    is_face_valid = false
                    break
                }

                current_node, last_edge = circular_walk(graph^, current_node, last_edge)                

                append(&face.edges, last_edge)
                if graph.edges[last_edge].lethal
                {
                    face.count += 1
                }
            }

            if is_face_valid do append(&graph.faces, face)
        }

        graph.nodes[node_index].faces_calculated = true
    }
}

mutate_path :: proc(graph : ^Graph) -> bool
{
    n_attempts := 0

    lethal_edges : [dynamic]int
    for edge, edge_id in graph.edges
    {
        if edge.lethal do append(&lethal_edges, edge_id)
    }
    rand.shuffle(lethal_edges[:])

    success := false
    for edge_id in lethal_edges
    {
        // pick a random edge on the path
        edge := graph.edges[edge_id].endpoints
        
        path := find_path(graph^, edge[0], edge[1])
        success = path.success

        when ODIN_DEBUG
        {
            if success do fmt.println("mutate", edge_id)
        }

        if success
        {
            graph.edges[edge_id].lethal = false

            for node_id, edge_id in iter_path(&path)
            {
                graph.nodes[node_id].on_path = true
                if edge_id != nil
                {
                    graph.edges[edge_id.(int)].lethal = true
                }
            }

            break
        }
    }

    return success
}

Neighbors :: struct {
    graph : Graph,
    index : int,
    source : int
}

neighbors :: proc(iterator : ^Neighbors) -> (neighbor : int, edge_index : int, count : int, more : bool)
{
    using iterator

    for index < len(graph.edges)
    {
        edge := graph.edges[index].endpoints
        edge_index = index

        iterator.index += 1
        count = index
        more = true

        if edge[0] == source
        {
            neighbor = edge[1]
            return
        }
        else if edge[1] == source
        {
            neighbor = edge[0]
            return
        }
    }

    more = false
    return
}

find_path :: proc(graph : Graph, start, end : int) -> Path
{
    frontier := new([dynamic]int)
    next_frontier := new([dynamic]int)

    for &node in graph.nodes do node.previous = nil

    append(frontier, start)
    for graph.nodes[end].previous == nil
    {
        if len(frontier) == 0
        {
            return Path{ success = false, finished = true }
        }

        for node_index in frontier
        {
            iterator := Neighbors{ graph=graph, source=node_index }
            for neighbor, edge_index in neighbors(&iterator)
            {
                if neighbor == start do continue

                if neighbor == 0 do continue

                if graph.edges[edge_index].lethal do continue

                if graph.edges[edge_index].protected do continue

                if graph.nodes[neighbor].on_path && neighbor != end do continue

                if graph.nodes[neighbor].previous != nil do continue

                graph.nodes[neighbor].previous = edge_index
                append(next_frontier, neighbor)
            }
        }

        rand.shuffle(next_frontier[:])
        frontier, next_frontier = next_frontier, frontier
        clear(next_frontier)
    }

    // fmt.println()

    return Path{ graph = graph, success = true, current_node_id = end }
}

Path :: struct {
    success : bool,
    current_node_id : int,
    graph : Graph,
    finished : bool
}

iter_path :: proc(path : ^Path) -> (node_id : int, edge_id : union{int}, index : int, more : bool)
{
    if path.finished do return 0, 0, 0, false

    more = true

    node_id = path.current_node_id
    edge_id = path.graph.nodes[node_id].previous

    if edge_id != nil
    {
        edge := path.graph.edges[edge_id.(int)]
        next_node_id := edge.endpoints[0] if edge.endpoints[1] == node_id else edge.endpoints[1]
        path.current_node_id = next_node_id
    }
    else
    {
        path.finished = true
    }

    return
}

add_point :: proc(graph : ^Graph, r : f32, x_min, x_max, y_min, y_max : f32) -> bool
{
    new_node_position : [2]f32
    accepted := false
    n_attempts := 0
    for !accepted
    {
        new_node_position = [2]f32{
            x_min + rand.float32() * (x_max - x_min),
            y_min + rand.float32() * (y_max - y_min)
        }

        accepted  = true
        for node in graph.nodes
        {
            if distance_sq(node, new_node_position) <= r*r
            {
                accepted = false
                break
            }
        }

        n_attempts += 1

        if n_attempts >= 30
        {
            return false
        }
    }    

    for i in 0..<len(graph.nodes)
    {
        if distance_sq(graph.nodes[i], new_node_position) < 200*200
        {
            edge : Edge = Edge{ endpoints = {i, len(graph.nodes)} }
            a := graph.nodes[i]
            b := new_node_position
            intersects := false
            for edge2 in graph.edges
            {
                if edge2.endpoints[0] == i do continue
                if edge2.endpoints[1] == i do continue
                if edge2.endpoints[0] == len(graph.nodes) do continue
                if edge2.endpoints[1] == len(graph.nodes) do continue

                c := graph.nodes[edge2.endpoints[0]]
                d := graph.nodes[edge2.endpoints[1]]

                intersects = intersect(a, b, c, d)
                if intersects
                {
                    break
                }
            }
            
            if !intersects do append(&graph.edges, edge)
        }
    }

    append(&graph.nodes, Node{position=new_node_position})

    return true
}

destroy :: proc(graph : ^Graph)
{
    clear(&graph.nodes)
    clear(&graph.edges)
    clear(&graph.faces)
}

generate_graph :: proc(graph : ^Graph)
{
    r : f32 = 200

    for
    {
        // left
        add_point(graph, r, 0, 0, 0, graph.height) // 0
        add_point(graph, r, 0, 0, 0, graph.height) // 1

        // right
        add_point(graph, r, graph.width, graph.width, 0, graph.height) // 2
        add_point(graph, r, graph.width, graph.width, 0, graph.height) // 3
        
        // top
        add_point(graph, r, 0, graph.width, 0, 0) // 4
        add_point(graph, r, 0, graph.width, 0, 0) // 5
        
        // bottom
        add_point(graph, r, 0, graph.width, graph.height, graph.height) // 6
        add_point(graph, r, 0, graph.width, graph.height, graph.height) // 7

        elbow_room : f32 = 100
        x_min : f32 = 100
        x_max : f32 = x_min + 2 * elbow_room
        y_min : f32 = 0.1 * graph.height
        y_max : f32 = 0.9 * graph.height
        for x_max <= graph.width
        {
            saturated := false
            for !saturated
            {
                saturated = !add_point(graph, elbow_room, x_min, x_max, y_min, y_max)
            }

            x_min += elbow_room
            x_max += elbow_room
        }

        path := find_path(graph^, 1, 2)

        if !path.success
        {
            destroy(graph)
            continue
        }

        for node_id, edge_id in iter_path(&path)
        {
            graph.nodes[node_id].on_path = true
            if edge_id != nil
            {
                graph.edges[edge_id.(int)].lethal = true
            }
        }

        failed := false
        for !failed
        {
            failed = !mutate_path(graph)
        }

        find_faces(graph)

        return
    }
}

hit :: proc(graph : Graph, x, y : f32) -> union{int}
{
    for node, node_index in graph.nodes
    {
        if distance_sq({x, y}, node) <= 15*15
        {
            return node_index
        }
    }
    return nil
}

adjacent :: proc(graph : Graph, a, b : int) -> (bool, int)
{
    iterator := Neighbors{ graph = graph, source = a }
    for neighbor_index, edge_id in neighbors(&iterator)
    {
        if neighbor_index == b do return true, edge_id
    }
    return false, 0
}

declare_safe :: proc(graph : Graph, safe_edge_id : int)
{
    graph.edges[safe_edge_id].safety = .SAFE
    
    for &face in graph.faces
    {
        count_unsafe := 0
        count_safe := 0
        apply := false
        for edge_id in face.edges
        {
            if graph.edges[edge_id].safety == .SAFE do count_safe += 1
            if graph.edges[edge_id].safety == .UNSAFE do count_unsafe += 1

            if edge_id == safe_edge_id do apply = true
        }

        if apply
        {
            // if count_unsafe == face.count do for edge_id in face.edges
            // {
            //     if graph.edges[edge_id].safety == .UNKNOWN do graph.edges[edge_id].safety = .SAFE
            // }

            if count_safe == len(face.edges) - face.count do for edge_id in face.edges
            {
                if graph.edges[edge_id].safety == .UNKNOWN do graph.edges[edge_id].safety = .UNSAFE
            }
        }
    }
}

main :: proc()
{
    // theta0 : f32 = 1*math.PI / 6

    // for k in 0..<12
    // {
    //     theta := f32(k) * (2*math.PI / 12)
    //     x := math.cos(theta)
    //     y := math.sin(theta)
    //     base_angle := int(math.atan2(y, x) * (180 / math.PI))
    //     angle := int(atan3(x, y, theta0) * (180 / math.PI))
    //     fmt.println(k, angle)
    // }

    graph : Graph

    append(&graph.nodes, Node{ position={0, 0} })
    append(&graph.nodes, Node{ position={0, 1} })
    append(&graph.nodes, Node{ position={1, 1} })
    append(&graph.nodes, Node{ position={1, 0} })
    
    append(&graph.edges, Edge{endpoints=[2]int{0, 1}})
    append(&graph.edges, Edge{endpoints=[2]int{1, 2}})
    append(&graph.edges, Edge{endpoints=[2]int{2, 3}})
    append(&graph.edges, Edge{endpoints=[2]int{3, 0}})
    append(&graph.edges, Edge{endpoints=[2]int{2, 0}})

    // n, e := circular_walk(graph, 2, 4)
    // fmt.println(n, e)

    // next_node_index, next_edge_index := 1, 0
    // for next_node_index != 0
    // {
    //     fmt.println(next_node_index, next_edge_index)
    //     next_node_index, next_edge_index = circular_walk(graph, next_node_index, next_edge_index)
    // }

    find_faces(&graph)

    for face in graph.faces
    {
        fmt.println(face)
    }
}