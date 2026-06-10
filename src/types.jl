# Minimal running-notebook handle (absorbed from PlutoSliderServer's Types.jl —
# the subset the islands engine and oracle need).

import Pluto: Token

Base.@kwdef struct RunningNotebook
    path::String
    notebook::Pluto.Notebook
    original_state::Any
    token::Token = Token()
    bond_connections::Dict{Symbol,Vector{Symbol}}
end
