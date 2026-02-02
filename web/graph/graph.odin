package graph

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg"

Node :: struct {
    using position : [2]f32,
    previous : union{int},
    on_path : bool,
    faces_calculated : bool
}

Edge :: [2]int

Face :: struct {
    edges : [dynamic]int
}

Graph :: struct {
    nodes : [dynamic]Node,
    edges : [dynamic][2]int,
    width : f32,
    height : f32,
    path : [dynamic]int,
    faces : [dynamic]Face
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

contains :: proc(values : []$T, x : T) -> bool
{
    for y in values
    {
        if y == x do return true
    }
    return false
}

random_choice :: proc(values : []$T) -> (T, int)
{
    choice : int
    for _, index in values
    {
        if rand.float32() < 1 / f32(index + 1)
        {
            choice = index
        }
    }

    return values[choice], choice
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
    last_edge := graph.edges[last_edge_index]
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
            }

            if is_face_valid do append(&graph.faces, face)
        }

        graph.nodes[node_index].faces_calculated = true
    }
}

mutate_path :: proc(graph : ^Graph) -> bool
{
    edge_index, path_index : int
    new_segment : [dynamic]int = nil
    n_attempts := 0
    for new_segment == nil
    {
        // pick a random edge on the path
        edge_index, path_index = random_choice(graph.path[:])
        edge := graph.edges[edge_index]
        
        new_segment = find_path(graph^, edge[0], edge[1])

        when ODIN_DEBUG
        {
            if new_segment != nil do fmt.println("mutate", edge_index)
        }

        n_attempts += 1

        if n_attempts > 100 do return false
    }

    unordered_remove(&graph.path, path_index)
    for x in new_segment
    {
        when ODIN_DEBUG do fmt.println("  add", x)
        append(&graph.path, x)
    }
    
    delete(new_segment)

    return true
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
        edge := graph.edges[index]
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

find_path :: proc(graph : Graph, start, end : int) -> [dynamic]int
{
    path := make([dynamic]int)
    frontier := new([dynamic]int)
    next_frontier := new([dynamic]int)

    for &node in graph.nodes do node.previous = nil

    append(frontier, start)
    for graph.nodes[end].previous == nil
    {
        if len(frontier) == 0
        {
            return nil
        }

        for node_index in frontier
        {
            iterator := Neighbors{ graph=graph, source=node_index }
            for neighbor, edge_index in neighbors(&iterator)
            {
                if neighbor == start do continue

                if contains(graph.path[:], edge_index) do continue

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

    current := end
    for graph.nodes[current].previous != nil
    {
        graph.nodes[current].on_path = true
        edge_index := graph.nodes[current].previous.(int)
        append(&path, edge_index)
        edge := graph.edges[edge_index]
        current = edge[0] if edge[1] == current else edge[1]
    }

    graph.nodes[current].on_path = true

    return path
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
            edge : [2]int = { i, len(graph.nodes) }
            a := graph.nodes[i]
            b := new_node_position
            intersects := false
            for edge2 in graph.edges
            {
                if edge2[0] == i do continue
                if edge2[1] == i do continue
                if edge2[0] == len(graph.nodes) do continue
                if edge2[1] == len(graph.nodes) do continue

                c := graph.nodes[edge2[0]]
                d := graph.nodes[edge2[1]]

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

generate_graph :: proc(graph : ^Graph)
{
    r : f32 = 200

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

    graph.path = find_path(graph^, 4, 6)

    failed := false
    for !failed
    {
        failed = !mutate_path(graph)
    }

    find_faces(graph)
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
    
    append(&graph.edges, [2]int{0, 1})
    append(&graph.edges, [2]int{1, 2})
    append(&graph.edges, [2]int{2, 3})
    append(&graph.edges, [2]int{3, 0})
    append(&graph.edges, [2]int{2, 0})

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