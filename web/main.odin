package web

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:math"
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

init_new :: proc(state : ^New)
{
    time = 0
    current_node = 0
    paused = false

    g = graph.Graph{ x = 15, y = 10, width = 600 - 30, height = 300 - 20 }
    graph.generate_graph(&g)    
    solver = graph.init_solver(&g)

    for n, n_id in g.nodes
    {
        button := NodeButton{
            box = { x = i32(n.x - 8), y = i32(n.y - 8), w = 16, h = 16 },
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
            color = WEB_COLOR_DEFAULT
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
            center = float(g.nodes[node_id]),
            registration = { 0, 0 },
            sheet = bad_texture,
            size = { 12, 12 }
        }
        append(&bad_nodes, sprite)
    }

    player = Sprite{
        center = float(g.nodes[0]),
        registration = { 0, 1 },
        sheet = girl_texture,
        size = { 26, 26 },
        target = float(g.nodes[0]),
        animation = nil,
        frame = 0
    }

    goal = Sprite{
        center = float(g.nodes[3]),
        registration = { 0, 0 },
        sheet = goal_texture,
        size = { 24, 24 }
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

update_new :: proc(state : ^New) -> union{State}
{
    return Playing{}
}

init_playing :: proc(state : ^Playing)
{
    player.animation = nil
    player.frame = 0

    state.counter = 300
}

update_playing :: proc(state : ^Playing) -> union{State}
{
    // wait for new game input
    check_new_game_input() or_return

    // wait for generic input (R, C, T)
    check_default_keys() or_return

    // update timer and check for time up
    update_timer() or_return

    if state.counter < 300
    {
        state.counter += 1
    }
    else if rand.float32() < 0.005
    {
        player.animation = GIRL_IDLE
        state.counter = 0
    }

    // wait for mouse/click input
    for &button in node_buttons
    {
        button.sprite.hidden = true

        if collide(mouse, button)
        {
            legal, edge_id := graph.adjacent(g, current_node, button.node_id)

            if legal
            {
                button.sprite.hidden = false

                if rl.IsMouseButtonDown(.LEFT)
                {
                    button.sprite.hidden = true

                    return Moving{
                        edge_id = edge_id,
                        start_id = current_node,
                        end_id = button.node_id
                    }
                }
            }
        }
    }

    return nil
}

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

init_moving :: proc(state : ^Moving)
{
    // start animation
    current_node = state.end_id

    web_lines[state.edge_id].sag = 10

    player.target.x = f32(g.nodes[current_node].x)
    player.target.y = f32(g.nodes[current_node].y)

    player.animation = GIRL_RUN

    player.flip = false
    if player.target.x < player.center.x
    {
        player.flip = true
    }

    x1 := f32(g.nodes[state.start_id].x)
    y1 := f32(g.nodes[state.start_id].y)
    x2 := f32(g.nodes[state.end_id].x)
    y2 := f32(g.nodes[state.end_id].y)

    state.distance = math.sqrt(
        (x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2)
    )

    state.distance_moved = 0
}

update_moving :: proc(state : ^Moving) -> union{State}
{
    // wait for new game input
    check_new_game_input() or_return

    // wait for generic input (R, C, T)
    check_default_keys() or_return

    // update timer and check for time up
    update_timer() or_return

    // move forward, calculate new position
    state.distance_moved += 1.5
    if state.distance_moved >= state.distance
    {
        x2 := f32(g.nodes[state.end_id].x)
        y2 := f32(g.nodes[state.end_id].y)

        player.center.x = x2
        player.center.y = y2

        graph.declare_safe(solver, state.edge_id)
        for _, edge_id in g.edges
        {
            if solver.edges[edge_id] == .SAFE do web_lines[edge_id].color = WEB_COLOR_SAFE
            else if solver.edges[edge_id] == .UNSAFE do web_lines[edge_id].color = WEB_COLOR_DEADLY
        }

        if state.end_id == 3
        {
            return Won{}
        }
        else
        {
            return Playing{}
        }
    }

    x1 := f32(g.nodes[state.start_id].x)
    y1 := f32(g.nodes[state.start_id].y)
    x2 := f32(g.nodes[state.end_id].x)
    y2 := f32(g.nodes[state.end_id].y)

    progress := state.distance_moved / state.distance

    player.x = x1 + progress * (x2 - x1)
    player.y = y1 + progress * (y2 - y1)

    player.y += line_height_delta(web_lines[state.edge_id], player.x, player.y)

    // if position > 50%, check for death
    if progress >= 0.5
    {
        if g.edges[state.edge_id].lethal
        {
            return Dead{}
        }
    }

    return nil
}

init_dead :: proc(state : ^Dead)
{
    // update timer
    update_timer()

    // start animation
    player.animation = GIRL_DIE
}

update_dead :: proc(state : ^Dead) -> union{State}
{
    // wait for new game input
    check_new_game_input() or_return

    // wait for generic input (R, C, T)
    check_default_keys() or_return

    animation, ok := player.animation.(Animation)
    if ok && animation.current == 5
    {
        rl.PlaySound(scream)
    }

    // if player animation is done, display game over screen
    if player.animation == nil
    {
        color := rl.RED
        dead_label.hidden = false

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

    return nil
}

init_won :: proc(state : ^Won)
{
    
}

update_won :: proc(state : ^Won) -> union{State}
{
    // wait for new game input
    check_new_game_input() or_return

    color := rl.GREEN
    win_label.hidden = false

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

    return nil
}

scream : rl.Sound

TIME : f32 = 60
time : f32
current_node : int
paused : bool
requires_initialization := true
g : graph.Graph
solver : graph.Solver

substate : State

girl_texture : rl.Texture
goal_texture : rl.Texture
bad_texture : rl.Texture

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

    scream = rl.LoadSound("graphics/scream.wav")

    girl_image := rl.LoadImageFromMemory(".png", raw_data(girl_sprite_data), cast(i32) len(girl_sprite_data))
    goal_image := rl.LoadImageFromMemory(".png", raw_data(goal_sprite_data), cast(i32) len(goal_sprite_data))
    bad_image := rl.LoadImageFromMemory(".png", raw_data(bad_sprite_data), cast(i32) len(bad_sprite_data))
    
    girl_texture = rl.LoadTextureFromImage(girl_image)
    goal_texture = rl.LoadTextureFromImage(goal_image)
    bad_texture = rl.LoadTextureFromImage(bad_image)

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