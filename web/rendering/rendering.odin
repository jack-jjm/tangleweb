package rendering

import rl "vendor:raylib"

Entity :: union{ Square, Line, Label }

Square :: struct {
    using center : [2]i32,
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
    color : rl.Color
}

ClickArea :: struct {
    using box : struct { x, y, w, h : i32 },
    node_id : int,
    entity_id : int
}

entities : [dynamic]Entity
click_areas : [dynamic]ClickArea

add :: proc(entity : Entity) -> int
{
    append(&entities, entity)
    return len(entities) - 1
}

get_entity :: proc(id : int) -> ^Entity
{
    return &entities[id]
}

collide :: proc(p : [2]i32, area : ClickArea) -> bool
{
    return \
        p.x >= area.x &&
        p.x <= area.x + area.w &&
        p.y >= area.y &&
        p.y <= area.y + area.h
}

add_click_area :: proc(area : ClickArea)
{
    append(&click_areas, area)
}

render_square :: proc(square : Square)
{
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
    using label

    width := rl.MeasureText(text, font_height)

    x := label.center.x - width / 2
    y := label.center.y - font_height / 2

    rl.DrawText(
        text, x, y, font_height, color
    )
}

render_entity :: proc(entity : Entity)
{
    switch entity in entity
    {
        case Square:
            render_square(entity)

        case Line:
            render_line(entity)

        case Label:
            render_label(entity)
    }
}

render :: render_entity
