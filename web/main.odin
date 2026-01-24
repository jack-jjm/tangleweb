package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math/rand"
import "core:math/linalg"

PixelCoordinate :: i32

ScreenArea :: struct {
    x, y, width, height : PixelCoordinate
}

NodeCoordinate :: f32

Node :: struct {
    using position : [2]NodeCoordinate,
    previous : union{int}
}

Graph :: struct {
    nodes : [dynamic]Node,
    edges : [dynamic][2]int,
    width : NodeCoordinate,
    height : NodeCoordinate,
    path : [dynamic]int
}

node_to_pixel :: proc(graph : Graph, window : ScreenArea, node : [2]NodeCoordinate) -> [2]i32
{
    x := window.x + PixelCoordinate(f32(window.width) * (node.x / graph.width))
    y := window.y + PixelCoordinate(f32(window.height) * (node.y / graph.height))
    return { x, y }
}

find_path :: proc(graph : Graph, i, j : int) -> [dynamic]int
{
    path := make([dynamic]int)
    frontier := new([dynamic]int)
    new_frontier := new([dynamic]int)

    append(frontier, i)
    for graph.nodes[j].previous == nil
    {
        for node in frontier
        {
            for edge, edge_index in graph.edges
            {
                if edge[0] != node && edge[1] != node do continue

                neighbor := edge[0] if edge[1] == node else edge[1]

                if neighbor == i
                {
                    continue
                }

                if graph.nodes[neighbor].previous != nil
                {
                    // fmt.println(graph.nodes[neighbor].previous)
                    continue
                }

                graph.nodes[neighbor].previous = edge_index
                append(new_frontier, neighbor)
            }
        }
        temp := frontier
        frontier = new_frontier
        new_frontier = temp
    }

    fmt.println("found path")

    current := j
    for graph.nodes[current].previous != nil
    {
        edge_index := graph.nodes[current].previous.(int)
        append(&path, edge_index)
        edge := graph.edges[edge_index]
        current = edge[0] if edge[1] == current else edge[1]
    }

    return path
}

generate_graph :: proc(graph : ^Graph)
{
    distance_sq :: proc(a, b : [2]NodeCoordinate) -> NodeCoordinate
    {
        return (a.x - b.x)*(a.x - b.x) + (a.y - b.y)*(a.y - b.y)
    }

    intersect :: proc(a, b, c, d : [2]NodeCoordinate) -> bool
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

    add_point :: proc(graph : ^Graph, r : NodeCoordinate, x_min, x_max, y_min, y_max : NodeCoordinate) -> bool
    {
        p : [2]NodeCoordinate
        accepted := false
        n_attempts := 0
        for !accepted
        {
            p = [2]f32{
                x_min + rand.float32() * (x_max - x_min),
                y_min + rand.float32() * (y_max - y_min)
            }

            accepted = true
            for node in graph.nodes
            {
                if distance_sq(node, p) <= r*r
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

        append(&graph.nodes, Node{position=p})
        for i in 0..<len(graph.nodes) - 1
        {
            if distance_sq(graph.nodes[i], p) < 200*200
            {
                edge : [2]int = { i, len(graph.nodes) - 1 }
                a := graph.nodes[i]
                b := p
                intersects := false
                for edge2 in graph.edges
                {
                    c := graph.nodes[edge2[0]]
                    d := graph.nodes[edge2[1]]

                    if edge2[0] == i do continue
                    if edge2[1] == i do continue
                    if edge2[0] == len(graph.nodes) - 1 do continue
                    if edge2[1] == len(graph.nodes) - 1 do continue

                    intersects = intersect(a, b, c, d)
                    if intersects
                    {
                        break
                    }
                }
                
                if !intersects do append(&graph.edges, edge)
            }
        }

        return true
    }

    r : NodeCoordinate = 200

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

    x_min : f32 = 100
    x_max : f32 = x_min + 200
    y_min : f32 = 0.1 * graph.height
    y_max : f32 = 0.9 * graph.height
    for x_max <= graph.width
    {
        saturated := false
        for !saturated
        {
            saturated = !add_point(graph, 100, x_min, x_max, y_min, y_max)
        }

        x_min += 200
        x_max += 200
    }
}

main :: proc()
{
    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    rl.InitWindow(1200, 600, "web")
    rl.SetTargetFPS(60)

    graph := Graph{ width = 1200, height = 600 }
    window := ScreenArea{ 0, 0, 1200, 600 }

    generate_graph(&graph)

    path : [dynamic]int

    path = find_path(graph, 4, 6)

    for !rl.WindowShouldClose()
    {
        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        for edge in graph.edges
        {
            a := graph.nodes[edge[0]]
            b := graph.nodes[edge[1]]
            a_screen := node_to_pixel(graph, window, a)
            b_screen := node_to_pixel(graph, window, b)
            rl.DrawLine(
                a_screen.x, a_screen.y,
                b_screen.x, b_screen.y,
                rl.WHITE
            )
        }

        for node, index in graph.nodes
        {
            p := node_to_pixel(graph, window, node)
            rl.DrawRectangle(
                p.x - 5, p.y - 5,
                10, 10,
                rl.WHITE
            )

            label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", index))
            defer delete(label)
            rl.DrawText(label, p.x + 10, p.y + 10, 15, rl.WHITE)

            for edge_index in path
            {
                edge := graph.edges[edge_index]
                a := graph.nodes[edge[0]]
                b := graph.nodes[edge[1]]
                a_screen := node_to_pixel(graph, window, a)
                b_screen := node_to_pixel(graph, window, b)
                rl.DrawLine(
                    a_screen.x, a_screen.y,
                    b_screen.x, b_screen.y,
                    rl.RED
                )
            }
        }

        rl.EndDrawing()
    }
}