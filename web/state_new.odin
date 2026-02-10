package web

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import "graph"

import res "resources"

init_new :: proc(state : ^New)
{
    time = 0
    current_node = 0
    paused = false

    g = graph.Graph{ x = 15, y = 10, width = 600 - 30, height = 300 - 20 }
    graph.generate_graph(&g)    
    solver = graph.init_solver(&g)

    for n, n_id in g.nodes
    {
        button := NodeButton{
            box = { x = i32(n.x - 8), y = i32(n.y - 8), w = 16, h = 16 },
            node_id = n_id,
            sprite = Square{
                x = i32(n.x), y = i32(n.y),
                size = 8,
                color = rl.WHITE,
                hidden = true
            }
        }

        append(&node_buttons, button)
    }

    for e in g.edges
    {
        a, b := e.endpoints[0], e.endpoints[1]
        line := Line{
            p1 = g.nodes[a],
            p2 = g.nodes[b],
            sag = 2,
            color = WEB_COLOR_DEFAULT
        }

        append(&web_lines, line)
    }

    for face in g.faces
    {
        barycenter : [2]i32
        for e in face.edges
        {
            a := g.nodes[g.edges[e].endpoints[0]]
            b := g.nodes[g.edges[e].endpoints[1]]
            barycenter += a
            barycenter += b
        }
        barycenter = barycenter / i32(2 * len(face.edges))

        formatted := fmt.aprintf("%d", face.count, allocator=context.temp_allocator)
        text := strings.clone_to_cstring(formatted)

        label := Label{
            text = text,
            position = barycenter,
            color = FACE_LABEL_COLOR,
            font_height = 14
        }

        append(&face_labels, label)
    }

    start_and_end := [2]int{ 1, 2 }
    for node_id in start_and_end
    {
        sprite := Sprite{
            center = float(g.nodes[node_id]),
            registration = { 0, 0 },
            sheet = res.sheets.bad,
            size = { 12, 12 }
        }
        append(&bad_nodes, sprite)
    }

    player = Sprite{
        center = float(g.nodes[0]),
        registration = { 0, 1 },
        sheet = res.sheets.girl,
        size = { 26, 26 },
        target = float(g.nodes[0]),
        animation = nil,
        frame = 0
    }

    goal = Sprite{
        center = float(g.nodes[3]),
        registration = { 0, 0 },
        sheet = res.sheets.goal,
        size = { 24, 24 }
    }

    dead_label = Label{
        position = {
            i32(300),
            i32(150),
        },
        text = "DEAD",
        color = rl.RED,
        hidden = true,
        font_height = 200
    }

    win_label = Label{
        position = {
            i32(300),
            i32(150),
        },
        text = "SAVED",
        color = rl.GREEN,
        hidden = true,
        font_height = 150
    }

    seconds_label = Label{
        position = { 50, 290 },
        color = WEB_COLOR_SAFE,
        align = .RIGHT,
        font_height = 20
    }

    centiseconds_label = Label{
        position = { 60, 290 },
        color = WEB_COLOR_SAFE,
        align = .LEFT,
        font_height = 20
    }

    timer_decimal_point = Label{
        position = { 55, 290 },
        color = WEB_COLOR_SAFE,
        align = .CENTER,
        text = ".",
        font_height = 20
    }
}

update_new :: proc(state : ^New) -> union{State}
{
    return Playing{}
}