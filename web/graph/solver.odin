package graph

Solver :: struct {
    graph : ^Graph,
    edges : []Safety,
    nodes : []Safety,
}

SolverResult :: enum { SOLVABLE, IMPOSSIBLE }

reset_solver :: proc(solver : Solver)
{
    for _, i in solver.edges
    {
        solver.edges[i] = .UNKNOWN
    }
}

init_solver :: proc(graph : ^Graph) -> Solver
{
    solver : Solver

    solver.edges = make([]Safety, len(graph.edges))
    solver.nodes = make([]Safety, len(graph.nodes))
    solver.graph = graph

    iterator := Neighbors{ graph=graph^, source=0 }
    for node_id, edge_id in neighbors(&iterator)
    {
        declare_safe(solver, edge_id)
    }

    return solver
}

declare_safe :: proc(solver : Solver, safe_edge_id : int)
{
    solver.edges[safe_edge_id] = .SAFE
    
    for &face in solver.graph.faces
    {
        count_unsafe := 0
        count_safe := 0
        apply := false
        for edge_id in face.edges
        {
            if solver.edges[edge_id] == .SAFE do count_safe += 1
            if solver.edges[edge_id] == .UNSAFE do count_unsafe += 1

            if edge_id == safe_edge_id do apply = true
        }

        if apply
        {
            if count_safe == len(face.edges) - face.count do for edge_id in face.edges
            {
                if solver.edges[edge_id] == .UNKNOWN do solver.edges[edge_id] = .UNSAFE
            }
        }
    }
}

solve :: proc(solver : Solver) -> SolverResult
{
    return .SOLVABLE
}