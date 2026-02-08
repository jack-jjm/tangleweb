package web

import rl "vendor:raylib"

Square :: struct {
    using center : [2]i32,
    hidden : bool,
    size : i32,
    color : rl.Color
}

Line :: struct {
    p1 : [2]i32,
    p2 : [2]i32,
    color : rl.Color
}

Label :: struct {
    center : [2]i32,
    font_height : i32,
    text : cstring,
    color : rl.Color,
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
    normal := [2]i32{ u.y, -u.x }

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

    rl.DrawLine(
        p1.x + d1.x, p1.y + d1.y, p2.x + d1.x, p2.y + d1.y, line.color
    )
    rl.DrawLine(
        p1.x + d2.x, p1.y + d2.y, p2.x + d2.x, p2.y + d2.y, line.color
    )
}

render_label :: proc(label : Label)
{
    if label.hidden do return

    width := rl.MeasureText(label.text, label.font_height)

    x := label.center.x - width / 2
    y := label.center.y - label.font_height / 2

    rl.DrawText(
        label.text, x, y, label.font_height, label.color
    )
}