package graph

import "core:math/linalg"
import "core:math"

ShoelaceFormula :: struct {
    first, last : [2]i32,
    area : f32,
    initialized : bool
}

add_shoelace_point :: proc(shoelace : ^ShoelaceFormula, point : [2]i32)
{
    if !shoelace.initialized
    {
        shoelace.first = point
        shoelace.initialized = true
    }

    last := shoelace.last
    shoelace.area += f32(point.y * last.x - point.x * last.y)
    shoelace.last = point
}

close_shoelace :: proc(shoelace : ^ShoelaceFormula) -> f32
{
    first := shoelace.first
    last := shoelace.last
    shoelace.area += f32(first.y * last.x - first.x * last.y)
    return shoelace.area / 2
}

distance_sq :: proc(a, b : [2]i32) -> i32
{
    return (a.x - b.x)*(a.x - b.x) + (a.y - b.y)*(a.y - b.y)
}

intersect :: proc(a, b, c, d : [2]i32) -> bool
{
    u := a - c
    v := b - c
    M := linalg.Matrix2f32{
        f32(u.x),
        f32(v.x),
        f32(u.y),
        f32(v.y)
    }
    iM := linalg.matrix2x2_inverse(M)
    g := d - c
    coordinates := [2]f32{
        iM[0, 0] * f32(g.x) + iM[0, 1] * f32(g.y),
        iM[1, 0] * f32(g.x) + iM[1, 1] * f32(g.y)
    }
    return coordinates.x >= 0 && coordinates.y >= 0 && coordinates.x + coordinates.y >= 1
}

atan3 :: proc(x, y, theta0 : f32) -> f32
{
    theta := math.atan2(y, x)
    if theta < 0 do theta += 2*math.PI
    if theta < theta0
    {
        theta = theta + 2*math.PI
    }
    return theta - theta0
}

deg :: proc(rad : f32) -> int
{
    return int(rad * 180/math.PI)
}