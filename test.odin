package main

import rl "vendor:raylib"
import "core:fmt"
import "core:math/linalg"

intersect :: proc(a, b, c, d : [2]f32) -> bool
{
    u := a - c
    v := b - c
    M := linalg.Matrix2f32{
        u.x, v.x, u.y, v.y
    }
    iM := linalg.matrix2x2_inverse(M)
    g := d - c
    coordinates := [2]f32{
        iM[0, 0] * g.x + iM[0, 1] * g.y,
        iM[1, 0] * g.x + iM[1, 1] * g.y
    }
    return coordinates.x >= 0 && coordinates.y >= 0 && coordinates.x + coordinates.y >= 1
}

main :: proc()
{
    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    rl.InitWindow(800, 800, "test")

    rl.SetTargetFPS(60)

    a := [2]f32{ 262, 13 }
    b := [2]f32{ 378, 146 }
    c := [2]f32{ 254, 135 }
    d := [2]f32{ 372, 43 }

    for !rl.WindowShouldClose()
    {
        // d.x = cast(f32) rl.GetMouseX()
        // d.y = cast(f32) rl.GetMouseY()

        result := intersect(a, b, c, d)

        rl.BeginDrawing()

        rl.ClearBackground(rl.WHITE)

        rl.DrawRectangle(i32(a.x - 5), i32(a.y - 5), 10, 10, rl.BLACK)
        rl.DrawRectangle(i32(b.x - 5), i32(b.y - 5), 10, 10, rl.BLACK)
        rl.DrawRectangle(i32(c.x - 5), i32(c.y - 5), 10, 10, rl.BLACK)
        rl.DrawRectangle(i32(d.x - 5), i32(d.y - 5), 10, 10, rl.BLACK)

        rl.DrawLine(i32(a.x), i32(a.y), i32(b.x), i32(b.y), rl.BLACK)
        rl.DrawLine(i32(c.x), i32(c.y), i32(d.x), i32(d.y), rl.RED if result else rl.BLACK)

        rl.EndDrawing()
    }
}