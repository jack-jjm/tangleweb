package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math/rand"

import "./graph"
import "./window"
import r "./rendering"

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

    for n, n_id in g.nodes
    {
        square := r.Square{
            x = i32(n.x), y = i32(n.y),
            size = 8,
            color = rl.WHITE
        }
        entity_id := r.add(square)

        click_area := r.ClickArea{
            box = { x = i32(n.x - 4), y = i32(n.y - 4), w = 8, h = 8 },
            node_id = n_id,
            entity_id = entity_id
        }

        r.add_click_area(click_area)
    }

    for e in g.edges
    {
        a, b := e.endpoints[0], e.endpoints[1]
        line := r.Line{
            p1 = g.nodes[a],
            p2 = g.nodes[b],
            color = rl.WHITE
        }
        r.add(line)
    }

    for face in g.faces
    {
        barycenter : [2]i32
        for e in face.edges
        {
            a := g.nodes[g.edges[e].endpoints[0]]
            b := g.nodes[g.edges[e].endpoints[1]]
            barycenter += a
            barycenter += b
        }
        barycenter = barycenter / i32(2 * len(face.edges))

        formatted := fmt.aprintf("%d", face.count)
        defer delete(formatted)

        text := strings.clone_to_cstring(formatted)

        label := r.Label{
            text = text,
            center = barycenter,
            color = rl.WHITE,
            font_height = 11
        }
        r.add(label)
    }

    player_id := r.add(r.Square{ center = g.nodes[0], size = 15, color = rl.ORANGE })

    texture := rl.LoadRenderTexture(600, 300)

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
        mouse : [2]i32 = {
            i32(f32(screen_mouse.x - x) / scale),
            i32(f32(screen_mouse.y - y) / scale)
        }

        if !dead
        {
            for click_area in r.click_areas
            {
                entity := r.get_entity(click_area.entity_id)
                square := cast(^r.Square) entity
                square.color = rl.BLACK

                if r.collide(mouse, click_area)
                {
                    legal, edge_id := graph.adjacent(g, current_node, click_area.node_id)

                    if legal
                    {
                        square.color = rl.WHITE

                        if rl.IsMouseButtonPressed(.LEFT)
                        {
                            if g.edges[edge_id].lethal
                            {
                                dead = true
                                fmt.println("dead")
                            }
                            else
                            {
                                current_node = click_area.node_id
                                e := r.get_entity(player_id)
                                s := cast(^r.Square) e
                                s.x = cast(i32) g.nodes[current_node].x
                                s.y = cast(i32) g.nodes[current_node].y
                            }
                        }
                    }
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

        for e in r.entities
        {
            r.render(e)
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