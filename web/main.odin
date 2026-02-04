package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math/rand"

import "./graph"
import "./window"

PixelCoordinate :: i32

Node :: struct
{
    using position : [2]i32,
    active : bool
}

create_node_sprite :: proc(g : graph.Graph, node : graph.Node) -> Node
{
    return {
        x = i32(node.x),
        y = i32(node.y),
        active = false
    }
}

main :: proc()
{
    seed := rand.uint64()
    rand.reset(seed)
    fmt.println("seed:", seed)

    // rand.reset(2818313247485133324)

    // 600x300

    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    rl.InitWindow(1200 + 100, 600 + 100, "web")
    rl.SetWindowState({ .WINDOW_RESIZABLE })
    rl.SetTargetFPS(60)

    g := graph.Graph{ x = 15, y = 10, width = 600 - 30, height = 300 - 20 }

    graph.generate_graph(&g)

    current_node := 0
    dead := false

    texture := rl.LoadRenderTexture(600, 300)

    node_sprites := make([dynamic]Node)
    for node in g.nodes do append(&node_sprites, create_node_sprite(g, node))

    for !rl.WindowShouldClose()
    {
        window.step()

        show_path := false
        if rl.IsKeyDown(rl.KeyboardKey.C)
        {
            show_path = true
        }

        h_scale := f32(window.w) / f32(texture.texture.width)
        v_scale := f32(window.h) / f32(texture.texture.height)
        scale := min(h_scale, v_scale)

        scaled_width  := f32(texture.texture.width) * scale
        scaled_height := f32(texture.texture.height) * scale

        x := (f32(window.w) - scaled_width) / 2
        y := (f32(window.h) - scaled_height) / 2

        screen_mouse := rl.GetMousePosition()
        mouse : [2]f32 = { f32(screen_mouse.x - x) / scale, f32(screen_mouse.y - y) / scale }

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

        rl.BeginTextureMode(texture)

        rl.ClearBackground(rl.BLACK)

        for edge, edge_index in g.edges
        {
            a := g.nodes[edge.endpoints[0]].position
            b := g.nodes[edge.endpoints[1]].position
            
            color : rl.Color
            switch edge.safety
            {
                case .UNKNOWN: color = rl.WHITE
                case .SAFE: color = rl.GREEN
                case .UNSAFE: color = rl.RED
            }

            if show_path
            {
                color = rl.RED if edge.lethal else rl.GREEN if edge.protected else rl.WHITE
            }
            
            rl.DrawLine(
                i32(a.x), i32(a.y),
                i32(b.x), i32(b.y),
                color
            )

            when ODIN_DEBUG
            {
                label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", edge_index))
                defer delete(label)
                p := (a + b) / 2
                rl.DrawText(label, i32(p.x) + 3, i32(p.y) + 3, 12, rl.YELLOW)
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
            rl.DrawCircle(
                i32(p.x), i32(p.y), 10, rl.YELLOW
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

            label := strings.unsafe_string_to_cstring(fmt.aprintf("%d", face.count))
            defer delete(label)
            size := rl.MeasureText(label, 25)
            rl.DrawText(label, i32(total.x) - size / 2, i32(total.y) - 12, 25, rl.WHITE)
        }

        if dead
        {
            width := rl.MeasureText("DEAD", 200)
            rl.DrawText("DEAD", (600 - width) / 2, 50, 200, rl.RED)
        }

        rl.EndTextureMode()

        rl.ClearBackground(rl.BLACK)

        rl.DrawTexturePro(
            texture.texture,
            { x=0, y=0, width=600, height=-300 },
            { x=x, y=y, width=scaled_width, height=scaled_height },
            { 0, 0 },
            0,
            rl.WHITE
        )

        rl.EndDrawing()
    }
}