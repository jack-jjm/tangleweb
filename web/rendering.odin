package web

import rl "vendor:raylib"
import "core:math"

Animation :: struct {
    frames : []i32,
    next : enum { Loop, Stop },
    current : int
}

Square :: struct {
    using center : [2]i32,
    hidden : bool,
    size : i32,
    color : rl.Color
}

Sprite :: struct {
    using center : [2]f32,
    registration : [2]i32,
    hidden : bool,
    sheet : rl.Texture,
    size : [2]i32,
    frame : i32,
    animation : union { Animation },
    flip : bool,
    target : [2]f32
}

GIRL_RUN := Animation{
    frames = { 4, 5 },
    next = .Loop
}

GIRL_IDLE := Animation{
    frames = { 1, 2, 3, 3, 3, 3, 3, 3, 3, 1, 0 },
    next = .Stop
}

GIRL_DIE := Animation{
    frames = { 6, 7, 7, 7, 8, 9, 10 },
    next = .Stop
}

update_position :: proc(sprite : ^Sprite) -> bool
{
    if sprite.center == sprite.target do return false

    vector := sprite.target - sprite.center
    fvector := [2]f32{ f32(vector.x), f32(vector.y) }
    distance := math.sqrt(fvector.x * fvector.x + fvector.y * fvector.y)

    step : f32 : 3

    if distance < step
    {
        sprite.center = sprite.target
        return false
    }

    fdelta := fvector / distance

    sprite.center.x = sprite.center.x + step * fdelta.x
    sprite.center.y = sprite.center.y + step * fdelta.y

    return true
}

update_animation :: proc(sprite : ^Sprite)
{
    if sprite.animation == nil do return
    animation := &sprite.animation.(Animation)

    sprite.frame = animation.frames[animation.current]

    animation.current += 1
    if animation.current == len(animation.frames)
    {
        switch animation.next
        {
            case .Loop:
                animation.current = 0

            case .Stop:
                sprite.animation = nil
        }
    }
}

Line :: struct {
    p1 : [2]i32,
    p2 : [2]i32,
    sag : i32,
    color : rl.Color
}

Label :: struct {
    position : [2]i32,
    font_height : i32,
    text : cstring,
    color : rl.Color,
    align : enum { CENTER, LEFT, RIGHT },
    hidden : bool
}

Rectangle :: struct { x, y, w, h : i32 }

collide :: proc(p : [2]i32, area : Rectangle) -> bool
{
    return \
        p.x >= area.x &&
        p.x <= area.x + area.w &&
        p.y >= area.y &&
        p.y <= area.y + area.h
}

render_sprite :: proc(sprite : Sprite)
{
    if sprite.hidden do return

    origin := [2]f32{
        f32(sprite.size.x / 2 + sprite.registration[0] * sprite.size.y / 2),
        f32(sprite.size.y / 2 + sprite.registration[1] * sprite.size.y / 2)
    }

    flip : f32 = sprite.flip ? -1 : 1

    source := rl.Rectangle{
        x = f32(sprite.frame * sprite.size.x),
        y = 0,
        width = flip * f32(sprite.size.x),
        height = f32(sprite.size.y)
    }

    target := rl.Rectangle{
        x = f32(sprite.x - origin.x),
        y = f32(sprite.y - origin.y),
        width  = f32(sprite.size.x),
        height = f32(sprite.size.y)
    }

    rl.DrawTexturePro(
        sprite.sheet,
        source,
        target,
        { 0, 0 },
        0,
        rl.WHITE
    )
}

render_square :: proc(square : Square)
{
    if square.hidden do return

    rl.DrawRectangle(
        square.x - square.size / 2, square.y - square.size / 2, square.size, square.size, square.color
    )
}

render_line :: proc(line : Line)
{
    p1 := line.p1
    p2 := line.p2

    u := p2 - p1

    d1 : [2]i32
    d2 : [2]i32

    if abs(u.x) > abs(u.y)
    {
        d1 = [2]i32{ 0, 1 }
        d2 = [2]i32{ 0, -1 }
    }
    else
    {
        d1 = [2]i32{ 1, 0 }
        d2 = [2]i32{ -1, 0 }
    }

    if line.sag == 0 || line.p1.x == line.p2.x
    {

        rl.DrawLine(
            p1.x + d1.x, p1.y + d1.y, p2.x + d1.x, p2.y + d1.y, line.color
        )

        rl.DrawLine(
            p1.x + d2.x, p1.y + d2.y, p2.x + d2.x, p2.y + d2.y, line.color
        )
    }
    else
    {
        x1 := p1.x
        x2 := p2.x
        y1 := p1.y
        y2 := p2.y

        a := f32(x1 - x2) / 2
        a = a * a
        a = -f32(line.sag) / a

        dx : i32 = +1 if x2 > x1 else -1

        slope := f32(y2 - y1) / f32(x2 - x1)
        previous := p1
        for x := x1; x != x2 + dx; x += dx
        {
            y := f32(y1)
            y += f32(x - x1) * slope
            y += a * f32((x - x1) * (x - x2))

            rl.DrawLine(previous.x, previous.y - 1, x, i32(y - 1), line.color)
            rl.DrawLine(previous.x, previous.y + 1, x, i32(y + 1), line.color)

            previous = { x, i32(y) }
        }
    }
}

line_height_delta :: proc(line : Line, x : f32, y0 : f32) -> f32
{
    p1 := line.p1
    p2 := line.p2

    x1 := p1.x
    x2 := p2.x
    y1 := p1.y
    y2 := p2.y

    if x1 == x2 do return 0

    a := f32(x1 - x2) / 2
    a = a * a
    a = -f32(line.sag) / a

    slope := f32(y2 - y1) / f32(x2 - x1)

    y := f32(y1)
    y += (x - f32(x1)) * slope
    y += a * (x - f32(x1)) * (x - f32(x2))

    return y - y0
}

render_label :: proc(label : Label)
{
    if label.hidden do return

    width := rl.MeasureText(label.text, label.font_height)

    x_offset : i32
    switch label.align
    {
        case .LEFT:
            x_offset = 0

        case .CENTER:
            x_offset = width / 2

        case .RIGHT:
            x_offset = width

    }

    x := label.position.x - x_offset
    y := label.position.y - label.font_height / 2

    rl.DrawText(
        label.text, x, y, label.font_height, label.color
    )
}