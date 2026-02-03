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

pixel_to_node :: proc(graph : graph.Graph, window : ScreenArea, point : [2]f32) -> [2]f32
{
    relative := point - [2]f32{ f32(window.x), f32(window.y) }
    x := f32(relative.x) * (graph.width / f32(window.width))
    y := f32(relative.y) * (graph.height / f32(window.height))
    return { x, y }
}

Node :: struct
{
    using position : [2]i32,
    active : bool
}

create_node_sprite :: proc(g : graph.Graph, window : ScreenArea, node : graph.Node) -> Node
{
    p := node_to_pixel(g, window, node)
    return {
        x = p.x,
        y = p.y,
        active = false
    }
}

main :: proc()
{
    seed := rand.uint64()
    rand.reset(seed)
    fmt.println("seed:", seed)

    // rand.reset(7877500187719467802)

    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    rl.InitWindow(1200 + 100, 600 + 100, "web")
    rl.SetTargetFPS(60)

    g := graph.Graph{ width = 1200, height = 600 }
    window := ScreenArea{ 50, 50, 1200, 600 }

    graph.generate_graph(&g)

    current_node := 0
    dead := false

    node_sprites := make([dynamic]Node)
    for node in g.nodes do append(&node_sprites, create_node_sprite(g, window, node))

    for !rl.WindowShouldClose()
    {
        show_path := false
        if rl.IsKeyDown(rl.KeyboardKey.C)
        {
            show_path = true
        }

        mouse := pixel_to_node(g, window, rl.GetMousePosition())

        for &sprite in node_sprites do sprite.active = false

        if !dead
        {
            hit := graph.hit(g, mouse.x, mouse.y)
            if hit != nil
            {
                hit := hit.(int)

                node_sprites[hit].active = true
                
                yes, edge_id := graph.adjacent(g, hit, current_node)
                if yes && rl.IsMouseButtonReleased(rl.MouseButton.LEFT)
                {
                    if g.edges[edge_id].lethal
                    {
                        fmt.println("dead")
                        dead = true
                    }
                    else
                    {
                        graph.declare_safe(g, edge_id)
                    }

                    current_node = hit
                }
            }
        }
        else
        {
            if rl.IsKeyReleased(rl.KeyboardKey.R)
            {
                dead = false
                current_node = 0
            }
        }

        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        for edge, edge_index in g.edges
        {
            a := g.nodes[edge.endpoints[0]]
            b := g.nodes[edge.endpoints[1]]
            a_screen := node_to_pixel(g, window, a)
            b_screen := node_to_pixel(g, window, b)
            
            color : rl.Color
            switch edge.safety
            {
                case .UNKNOWN: color = rl.WHITE
                case .SAFE: color = rl.GREEN
                case .UNSAFE: color = rl.RED
            }

            if show_path
            {
                color = rl.RED if edge.lethal else rl.WHITE
            }
            
            rl.DrawLine(
                a_screen.x, a_screen.y,
                b_screen.x, b_screen.y,
                color
            )

            when ODIN_DEBUG
            {
                label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", edge_index))
                defer delete(label)
                p := (a_screen + b_screen) / 2
                rl.DrawText(label, p.x + 3, p.y + 3, 12, rl.YELLOW)
            }
        }

        for p, index in node_sprites
        {
            if p.active do rl.DrawRectangle(
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

        if !dead
        {
            p := g.nodes[current_node]
            screen := node_to_pixel(g, window, p)
            rl.DrawCircle(
                screen.x, screen.y, 10, rl.YELLOW
            )
        }

        for face in g.faces
        {
            total : [2]f32
            for edge_index in face.edges
            {
                edge := g.edges[edge_index].endpoints
                a := g.nodes[edge[0]].position
                b := g.nodes[edge[1]].position
                total += a + b
            }
            total /= f32(2 * len(face.edges))

            p := node_to_pixel(g, window, total)

            label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", face.count))
            defer delete(label)
            size := rl.MeasureText(label, 25)
            rl.DrawText(label, p.x - size / 2, p.y - 12, 25, rl.WHITE)
        }

        if dead
        {
            rl.DrawText("DEAD", 110, 160, 400, rl.WHITE)
        }

        rl.EndDrawing()
    }
}