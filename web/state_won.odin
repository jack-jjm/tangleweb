package web

import rl "vendor:raylib"

import res "resources"

init_won :: proc(state : ^Won)
{
    rl.StopMusicStream(res.sounds.heart_fast)
    rl.StopMusicStream(res.sounds.heart_slow)
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