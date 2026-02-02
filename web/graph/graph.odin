package graph

import "core:fmt"
import "core:math/rand"
import "core:math/linalg"

Node :: struct {
    using position : [2]f32,
    previous : union{int},
    on_path : bool
}

Graph :: struct {
    nodes : [dynamic]Node,
    edges : [dynamic][2]int,
    width : f32,
    height : f32,
    path : [dynamic]int
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

        n_attempts += 1

        if n_attempts > 100 do return false
    }

    unordered_remove(&graph.path, path_index)
    for x in new_segment do append(&graph.path, x)
    
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

    fmt.println()

    current := end
    for graph.nodes[current].previous != nil
    {
        graph.nodes[current].on_path = true
        edge_index := graph.nodes[current].previous.(int)
        append(&path, edge_index)
        edge := graph.edges[edge_index]
        current = edge[0] if edge[1] == current else edge[1]
    }

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
}

main :: proc()
{
    g : Graph

    nodes := []Node{
        Node{},
        Node{},
        Node{},
        Node{},
    }    

    edges := [][2]int{
        { 0, 1 },
        { 1, 2 },
        { 2, 3 },
        { 3, 0 },
        { 0, 2 },
    }

    for n in nodes { append(&g.nodes, n) }
    for e in edges { append(&g.edges, e) }

    it := Neighbors{ graph=g, source=0 }
    for x, y in neighbors(&it)
    {
        fmt.println(x, y)
    }
}