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
    scream : rl.Sound,
    spider : [4]rl.Sound,
    spider_attack : rl.Sound,
    spider_approach : rl.Sound,
    heart_slow : rl.Music,
    heart_fast : rl.Music
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
    
    sounds.spider[0] = rl.LoadSound("graphics/spider1.wav")
    sounds.spider[1] = rl.LoadSound("graphics/spider2.wav")
    sounds.spider[2] = rl.LoadSound("graphics/spider3.wav")
    sounds.spider[3] = rl.LoadSound("graphics/spider4.wav")
    
    sounds.spider_attack = rl.LoadSound("graphics/spiderattack.wav")
    sounds.spider_approach = rl.LoadSound("graphics/spiderapproach.wav")

    sounds.heart_slow = rl.LoadMusicStream("graphics/heartslow.ogg")
    sounds.heart_fast = rl.LoadMusicStream("graphics/heartfast.mp3")
}