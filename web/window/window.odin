package window

import rl "vendor:raylib"

resize_unhandled := true
fullscreen_unhandled := false
restore_unhandled := false
last_window_position : struct { x, y, width, height : i32, maximized : bool }
w, h : i32

step :: proc()
{
    if rl.IsKeyReleased(rl.KeyboardKey.F11)
    {
        if !rl.IsWindowFullscreen()
        {
            last_window_position.width = rl.GetScreenWidth()
            last_window_position.height = rl.GetScreenHeight()
            
            pos := rl.GetWindowPosition()
            last_window_position.x = i32(pos.x)
            last_window_position.y = i32(pos.y)
            
            last_window_position.maximized = rl.IsWindowMaximized()

            display := rl.GetCurrentMonitor()

            w, h = rl.GetMonitorWidth(display), rl.GetMonitorHeight(display)                
            if !rl.IsWindowMaximized()
            {
                rl.SetWindowSize(w, h)
                fullscreen_unhandled = true
            }
            else
            {
                rl.RestoreWindow()
                restore_unhandled = true
            }
        }
        else
        {
            rl.ToggleFullscreen()
            rl.SetWindowSize(last_window_position.width, last_window_position.height)
            rl.SetWindowPosition(last_window_position.x, last_window_position.y)

            if last_window_position.maximized
            {
                rl.MaximizeWindow()
            }
        }
    }

    if rl.IsWindowResized() do resize_unhandled = true
    if resize_unhandled
    {            
        if fullscreen_unhandled
        {                
            rl.ToggleFullscreen()
            fullscreen_unhandled = false
        }

        if restore_unhandled
        {
            display := rl.GetCurrentMonitor()
            w, h = rl.GetMonitorWidth(display), rl.GetMonitorHeight(display)
            rl.SetWindowSize(w, h)
            fullscreen_unhandled = true
            restore_unhandled = false
        }

        if !rl.IsWindowFullscreen()
        {
            w, h = rl.GetScreenWidth(), rl.GetScreenHeight()
        }
        else
        {
            display := rl.GetCurrentMonitor();
            w, h = rl.GetMonitorWidth(display), rl.GetMonitorHeight(display)
        }
    }
}

is_resized :: proc() -> bool
{
    defer resize_unhandled = false
    return resize_unhandled
}