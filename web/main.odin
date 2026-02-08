package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math/rand"

import "./graph"
import "./window"

NodeButton :: struct {
    using box : Rectangle,
    node_id : int,
    sprite : Square
}

node_buttons : [dynamic]NodeButton
web_lines : [dynamic]Line
face_labels : [dynamic]Label
player : Square

WEB_COLOR_DEFAULT : rl.Color = { 80, 103, 91, 255 }
WEB_COLOR_DEADLY  : rl.Color = { 131, 53, 61, 255 }
WEB_COLOR_SAFE    : rl.Color = { 223, 229, 233, 255 }

FACE_LABEL_COLOR := WEB_COLOR_SAFE

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
        button := NodeButton{
            box = { x = i32(n.x - 4), y = i32(n.y - 4), w = 8, h = 8 },
            node_id = n_id,
            sprite = Square{
                x = i32(n.x), y = i32(n.y),
                size = 8,
                color = rl.WHITE,
                hidden = true
            }
        }

        append(&node_buttons, button)
    }

    for e in g.edges
    {
        a, b := e.endpoints[0], e.endpoints[1]
        line := Line{
            p1 = g.nodes[a],
            p2 = g.nodes[b],
            color = rl.WHITE
        }

        append(&web_lines, line)
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

        label := Label{
            text = text,
            center = barycenter,
            color = FACE_LABEL_COLOR,
            font_height = 14
        }

        append(&face_labels, label)
    }

    player = Square{
        center = g.nodes[0],
        size = 15,
        color = rl.ORANGE
    }

    dead_label := Label{
        center = {
            i32(300),
            i32(150),
        },
        text = "DEAD",
        color = rl.RED,
        hidden = true,
        font_height = 200
    }

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
            for &button in node_buttons
            {
                button.sprite.hidden = true

                if collide(mouse, button)
                {
                    legal, edge_id := graph.adjacent(g, current_node, button.node_id)

                    if legal
                    {
                        button.sprite.hidden = false

                        if rl.IsMouseButtonPressed(.LEFT)
                        {
                            if g.edges[edge_id].lethal
                            {
                                dead = true
                                break
                            }
                            else
                            {
                                current_node = button.node_id                                
                                graph.declare_safe(g, edge_id)
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

                player.hidden = false
                dead_label.hidden = true

                for &button in node_buttons
                {
                    button.sprite.hidden = false
                }

                for &label in face_labels
                {
                    label.color = FACE_LABEL_COLOR
                }

                graph.reset_solver(g)
            }
        }

        if !dead do for edge, edge_id in g.edges
        {
            line := &web_lines[edge_id]
            switch edge.safety
            {
                case .UNKNOWN:
                    line.color = WEB_COLOR_DEFAULT
                
                case .SAFE:
                    line.color = WEB_COLOR_SAFE

                case .UNSAFE:
                    line.color = WEB_COLOR_DEADLY
            }
        }
        else
        {
            player.hidden = true
            dead_label.hidden = false
            
            for &button in node_buttons
            {
                button.sprite.hidden = true
            }

            for &line in web_lines
            {
                line.color = rl.RED
            }

            for &label in face_labels
            {
                label.color = rl.RED
            }
        }

        player.center = g.nodes[current_node].position

        rl.BeginDrawing()

        rl.BeginTextureMode(texture)

        rl.ClearBackground(rl.BLACK)
        
        for line in web_lines
        {
            render_line(line)
        }

        for button in node_buttons
        {
            render_square(button.sprite)
        }

        for label in face_labels
        {
            render_label(label)
        }

        render_square(player)

        render_label(dead_label)

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