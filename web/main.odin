package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math/rand"

import "./graph"
import "./window"

girl_sprite_data := #load("../graphics/girl.png")
goal_sprite_data := #load("../graphics/goal.png")
bad_sprite_data := #load("../graphics/bad.png")

NodeButton :: struct {
    using box : Rectangle,
    node_id : int,
    sprite : Square
}

node_buttons : [dynamic]NodeButton
bad_nodes : [dynamic]Sprite
web_lines : [dynamic]Line
face_labels : [dynamic]Label
player : Sprite
goal : Sprite

dead_label : Label
win_label : Label
seconds_label : Label
centiseconds_label : Label
timer_decimal_point : Label

WEB_COLOR_DEFAULT : rl.Color = { 80, 103, 91, 255 }
WEB_COLOR_DEADLY  : rl.Color = { 181, 53, 61, 255 }
WEB_COLOR_SAFE    : rl.Color = { 223, 229, 233, 255 }

FACE_LABEL_COLOR := WEB_COLOR_SAFE

format :: proc(fstring : string, args : ..any) -> cstring
{
    text := fmt.aprintf(fstring, ..args, allocator=context.temp_allocator)
    return strings.clone_to_cstring(text, context.temp_allocator)
}

main :: proc()
{
    seed := rand.uint64()
    rand.reset(seed)
    fmt.println("seed:", seed)

    // difficult 10697038158871979521
    // rand.reset(14590908374776623767)

    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    rl.InitWindow(1200 + 100, 600 + 100, "web")
    rl.SetWindowState({ .WINDOW_RESIZABLE })
    rl.SetTargetFPS(60)

    girl_image := rl.LoadImageFromMemory(".png", raw_data(girl_sprite_data), cast(i32) len(girl_sprite_data))
    girl_texture := rl.LoadTextureFromImage(girl_image)

    goal_image := rl.LoadImageFromMemory(".png", raw_data(goal_sprite_data), cast(i32) len(goal_sprite_data))
    goal_texture := rl.LoadTextureFromImage(goal_image)

    bad_image := rl.LoadImageFromMemory(".png", raw_data(bad_sprite_data), cast(i32) len(bad_sprite_data))
    bad_texture := rl.LoadTextureFromImage(bad_image)

    TIME : f32 = 60
    time : f32
    current_node : int
    dead : bool
    win : bool
    paused : bool

    g : graph.Graph
    solver : graph.Solver

    texture := rl.LoadRenderTexture(600, 300)

    requires_initialization := true

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

        //

        if !paused
        {
            time += 1 / 60.
        }

        if rl.IsKeyPressed(rl.KeyboardKey.N)
        {
            graph.destroy(&g)
            delete(solver.edges)

            clear(&node_buttons)
            clear(&web_lines)
            clear(&face_labels)
            clear(&bad_nodes)

            requires_initialization = true
        }

        if requires_initialization
        {
            requires_initialization = false

            time = 0
            current_node = 0
            dead = false
            win = false
            paused = false

            g = graph.Graph{ x = 15, y = 10, width = 600 - 30, height = 300 - 20 }
            graph.generate_graph(&g)    
            solver = graph.init_solver(&g)

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
                    sag = 2,
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

                formatted := fmt.aprintf("%d", face.count, allocator=context.temp_allocator)
                text := strings.clone_to_cstring(formatted)

                label := Label{
                    text = text,
                    position = barycenter,
                    color = FACE_LABEL_COLOR,
                    font_height = 14
                }

                append(&face_labels, label)
            }

            start_and_end := [2]int{ 1, 2 }
            for node_id in start_and_end
            {
                sprite := Sprite{
                    center = g.nodes[node_id],
                    registration = { 0, 0 },
                    texture = bad_texture
                }
                append(&bad_nodes, sprite)
            }

            player = Sprite{
                center = g.nodes[0],
                registration = { 0, 1 },
                texture = girl_texture
            }

            goal = Sprite{
                center = g.nodes[3],
                registration = { 0, 0 },
                texture = goal_texture
            }

            dead_label = Label{
                position = {
                    i32(300),
                    i32(150),
                },
                text = "DEAD",
                color = rl.RED,
                hidden = true,
                font_height = 200
            }

            win_label = Label{
                position = {
                    i32(300),
                    i32(150),
                },
                text = "SAVED",
                color = rl.GREEN,
                hidden = true,
                font_height = 150
            }

            seconds_label = Label{
                position = { 50, 290 },
                color = WEB_COLOR_SAFE,
                align = .RIGHT,
                font_height = 20
            }

            centiseconds_label = Label{
                position = { 60, 290 },
                color = WEB_COLOR_SAFE,
                align = .LEFT,
                font_height = 20
            }

            timer_decimal_point = Label{
                position = { 55, 290 },
                color = WEB_COLOR_SAFE,
                align = .CENTER,
                text = ".",
                font_height = 20
            }
        }

        if rl.IsKeyPressed(rl.KeyboardKey.T)
        {
            paused = true
        }

        time_left := TIME - time
        seconds_label.text = format("%02d", int(time_left))
        centiseconds_label.text = format("%02d", int(time_left * 100) % 100)

        if time_left <= 0 && !win
        {
            dead = true
        }
        else if time_left <= 10
        {
            seconds_label.color = rl.RED
            centiseconds_label.color = rl.RED
            timer_decimal_point.color = rl.RED
        }

        if !dead && !win
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
                                graph.declare_safe(solver, edge_id)

                                web_lines[edge_id].sag = 10

                                if button.node_id == 3
                                {
                                    win = true
                                }
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
                time = 0
                
                player.hidden = false
                goal.hidden = false
                dead_label.hidden = true
                win_label.hidden = true
                seconds_label.hidden = false
                centiseconds_label.hidden = false
                timer_decimal_point.hidden = false

                for &sprite in bad_nodes
                {
                    sprite.hidden = false
                }

                for &label in face_labels
                {
                    label.color = FACE_LABEL_COLOR
                }

                graph.reset_solver(solver)
            }
        }

        if !dead && !win do for edge, edge_id in g.edges
        {
            line := &web_lines[edge_id]
            if !rl.IsKeyDown(rl.KeyboardKey.C) do switch solver.edges[edge_id]
            {
                case .UNKNOWN:
                    line.color = WEB_COLOR_DEFAULT
                
                case .SAFE:
                    line.color = WEB_COLOR_SAFE

                case .UNSAFE:
                    line.color = WEB_COLOR_DEADLY
            }
            else do switch edge.lethal
            {
                case true:
                    line.color = WEB_COLOR_DEADLY
                    
                case false:
                    line.color = WEB_COLOR_SAFE
            }
        }
        else
        {
            color : rl.Color
            if dead do color = rl.RED
            else do color = rl.GREEN

            if dead do dead_label.hidden = false
            else do win_label.hidden = false

            player.hidden = true
            seconds_label.hidden = true
            centiseconds_label.hidden = true
            timer_decimal_point.hidden = true

            goal.hidden = true
            for &sprite in bad_nodes do sprite.hidden = true
            
            for &button in node_buttons
            {
                button.sprite.hidden = true
            }

            for &line in web_lines
            {
                line.color = color
            }

            for &label in face_labels
            {
                label.color = color
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

        for sprite in bad_nodes
        {
            render_sprite(sprite)
        }

        for label in face_labels
        {
            render_label(label)
        }

        render_sprite(goal)
        
        render_sprite(player)        

        render_label(dead_label)
        
        render_label(win_label)
        
        render_label(seconds_label)
        render_label(centiseconds_label)
        render_label(timer_decimal_point)

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

        free_all(context.temp_allocator)
    }
}