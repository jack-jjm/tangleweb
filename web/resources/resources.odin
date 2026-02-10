package resources

import rl "vendor:raylib"

girl_sprite_data := #load("../../graphics/girl.png")
goal_sprite_data := #load("../../graphics/goal.png")
bad_sprite_data  := #load("../../graphics/bad.png")

sheets : struct {
    girl,
    goal,
    bad : rl.Texture
}

sounds : struct {
    scream : rl.Sound
}

init :: proc()
{
    girl_image := rl.LoadImageFromMemory(".png", raw_data(girl_sprite_data), cast(i32) len(girl_sprite_data))
    goal_image := rl.LoadImageFromMemory(".png", raw_data(goal_sprite_data), cast(i32) len(goal_sprite_data))
    bad_image := rl.LoadImageFromMemory(".png", raw_data(bad_sprite_data), cast(i32) len(bad_sprite_data))

    sheets.girl = rl.LoadTextureFromImage(girl_image)
    sheets.goal = rl.LoadTextureFromImage(goal_image)
    sheets.bad  = rl.LoadTextureFromImage(bad_image)

    sounds.scream = rl.LoadSound("graphics/scream.wav")
}