package web

import rl "vendor:raylib"

import res "resources"

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
    if ok && animation.current == 3
    {
        rl.PlaySound(res.sounds.spider_attack)
    }

    if ok && animation.current == 5
    {
        rl.PlaySound(res.sounds.scream)
    }

    // if player animation is done, display game over screen
    if player.animation == nil
    {
        rl.StopMusicStream(res.sounds.heart_fast)
        rl.StopMusicStream(res.sounds.heart_slow)

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