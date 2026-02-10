package web

import "core:math/rand"
import rl "vendor:raylib"

import "graph"

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