package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/rand"

import "graph"
import "window"
import res "resources"

NodeButton :: struct {
    using box : Rectangle,
    node_id : int,
    sprite : Square
}

State :: union { New, Playing, Moving, Dead, Won }

New :: struct {}

Playing :: struct {
    counter : int
}

Moving :: struct {
    start_id, end_id, edge_id : int,
    distance, distance_moved : f32
}

Dead :: struct {}

Won :: struct {}

check_new_game_input :: proc() -> union{State}
{
    if rl.IsKeyPressed(rl.KeyboardKey.N)
    {
        graph.destroy(&g)
        delete(solver.edges)

        clear(&node_buttons)
        clear(&web_lines)
        clear(&face_labels)
        clear(&bad_nodes)

        return New{}
    }

    return nil
}

check_default_keys :: proc() -> union{State}
{
    if rl.IsKeyPressed(rl.KeyboardKey.T)
    {
        paused = true
    }

    if rl.IsKeyReleased(rl.KeyboardKey.R)
    {
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

        return New{}
    }

    return nil
}

update_timer :: proc() -> union{State}
{
    if !paused
    {
        time += 1 / 60.
    }

    time_left := max(0, TIME - time)
    seconds_label.text = format("%02d", int(time_left))
    centiseconds_label.text = format("%02d", int(time_left * 100) % 100)

    if time_left <= 10
    {
        seconds_label.color = rl.RED
        centiseconds_label.color = rl.RED
        timer_decimal_point.color = rl.RED
    }

    if time_left <= 0
    {
        return Dead{}
    }

    return nil
}

TIME : f32 = 60
time : f32
current_node : int
paused : bool
requires_initialization := true
g : graph.Graph
solver : graph.Solver

substate : State

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

mouse : [2]i32

WEB_COLOR_DEFAULT : rl.Color = { 80, 103, 91, 255 }
WEB_COLOR_DEADLY  : rl.Color = { 181, 53, 61, 255 }
WEB_COLOR_SAFE    : rl.Color = { 223, 229, 233, 255 }

FACE_LABEL_COLOR := WEB_COLOR_SAFE

float :: proc(v : [2]i32) -> [2]f32
{
    return {
        cast(f32) v.x,
        cast(f32) v.y
    }
}

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
    rl.InitAudioDevice()
    rl.SetTargetFPS(60)

    res.init()

    animation_tick := 0

    texture := rl.LoadRenderTexture(600, 300)

    substate = nil

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
        mouse = {
            i32(f32(screen_mouse.x - x) / scale),
            i32(f32(screen_mouse.y - y) / scale)
        }

        //

        transition : union{ State }

        switch &state in substate
        {
            case New:
                transition = update_new(&state)
            case Playing:
                transition = update_playing(&state)
            case Moving:
                transition = update_moving(&state)
            case Dead:
                transition = update_dead(&state)
            case Won:
                transition = update_won(&state)
            case:
                transition = New{}
        }

        if transition != nil
        {
            substate = transition.(State)

            switch &state in substate
            {
                case New:
                    init_new(&state)
                case Playing:
                    init_playing(&state)
                case Moving:
                    init_moving(&state)
                case Dead:
                    init_dead(&state)
                case Won:
                    init_won(&state)
            }
        }

        //

        animation_tick += 1
        if (animation_tick*9 >= 60)
        {
            animation_tick = 0

            update_animation(&player)
        }

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