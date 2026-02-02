package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math/rand"

import "./graph"

PixelCoordinate :: i32

ScreenArea :: struct {
    x, y, width, height : PixelCoordinate
}

node_to_pixel :: proc(graph : graph.Graph, window : ScreenArea, node : [2]f32) -> [2]i32
{
    x := window.x + PixelCoordinate(f32(window.width) * (node.x / graph.width))
    y := window.y + PixelCoordinate(f32(window.height) * (node.y / graph.height))
    return { x, y }
}

main :: proc()
{
    rand.reset(1)

    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    rl.InitWindow(1200 + 100, 600 + 100, "web")
    rl.SetTargetFPS(60)

    g := graph.Graph{ width = 1200, height = 600 }
    window := ScreenArea{ 50, 50, 1200, 600 }

    graph.generate_graph(&g)

    for !rl.WindowShouldClose()
    {
        show_path := false
        if rl.IsKeyDown(rl.KeyboardKey.R)
        {
            show_path = true
        }

        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        for edge, edge_index in g.edges
        {
            a := g.nodes[edge[0]]
            b := g.nodes[edge[1]]
            a_screen := node_to_pixel(g, window, a)
            b_screen := node_to_pixel(g, window, b)
            rl.DrawLine(
                a_screen.x, a_screen.y,
                b_screen.x, b_screen.y,
                rl.WHITE
            )

            when ODIN_DEBUG
            {
                label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", edge_index))
                defer delete(label)
                p := (a_screen + b_screen) / 2
                rl.DrawText(label, p.x + 3, p.y + 3, 12, rl.YELLOW)
            }
        }

        for node, index in g.nodes
        {
            p := node_to_pixel(g, window, node)
            rl.DrawRectangle(
                p.x - 5, p.y - 5,
                10, 10,
                rl.WHITE
            )

            when ODIN_DEBUG
            {
                label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", index))
                defer delete(label)
                rl.DrawText(label, p.x + 10, p.y + 10, 15, rl.WHITE)
            }
        }

        if show_path do for edge_index in g.path
        {
            edge := g.edges[edge_index]
            a := g.nodes[edge[0]]
            b := g.nodes[edge[1]]
            a_screen := node_to_pixel(g, window, a)
            b_screen := node_to_pixel(g, window, b)
            rl.DrawLine(
                a_screen.x, a_screen.y,
                b_screen.x, b_screen.y,
                rl.RED
            )
        }

        for face in g.faces
        {
            total : [2]f32
            bad_count := 0
            for edge_index in face.edges
            {
                edge := g.edges[edge_index]
                a := g.nodes[edge[0]].position
                b := g.nodes[edge[1]].position
                total += a + b

                if graph.contains(g.path[:], edge_index)
                {
                    bad_count += 1
                }
            }
            total /= f32(2 * len(face.edges))

            p := node_to_pixel(g, window, total)

            label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", bad_count))
            defer delete(label)
            size := rl.MeasureText(label, 25)
            rl.DrawText(label, p.x - size / 2, p.y - 12, 25, rl.WHITE)
        }

        rl.EndDrawing()
    }
}