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
    using line
    rl.DrawLine(
        p1.x, p1.y, p2.x, p2.y, color
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