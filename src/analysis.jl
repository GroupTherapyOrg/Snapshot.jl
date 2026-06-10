# Bond-connection analysis (absorbed from PlutoSliderServer's MoreAnalysis.jl).

"""Return a `Dict{Symbol,Vector{Symbol}}` mapping each bound variable to its
co-dependent bound variables — the bond groups the islands compile per."""
function bound_variable_connections_graph(
    session::Pluto.ServerSession,
    notebook::Pluto.Notebook,
)::Dict{Symbol,Vector{Symbol}}
    topology = notebook.topology
    bound_variables = Pluto.get_bond_names(session, notebook)
    Dict{Symbol,Vector{Symbol}}(
        var => let
            cells = Pluto.MoreAnalysis.codependents(topology, var)
            defined_there = union!(
                Set{Symbol}(),
                (topology.nodes[c].definitions for c in cells)...,
            )
            collect((defined_there ∩ bound_variables))
        end for var in bound_variables
    )
end
