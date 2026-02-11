package web

import rl "vendor:raylib"

import "core:math"
import "core:math/rand"
import "graph"
import res "resources"

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
    else if progress >= 0.25 && !state.playing_sound
    {
        if g.edges[state.edge_id].lethal || rand.float32() < 0.01
        {
            rl.PlaySound(res.sounds.spider_approach)
            state.playing_sound = true
        }
    }

    return nil
}