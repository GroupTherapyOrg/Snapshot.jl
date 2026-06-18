# Harvest PlutoIslands featured-corpus island pieces into a STATIC fixtures file
# vendored into WasmTarget.jl, so WT can test real PI cells directly (no Pluto).
#
# For every featured notebook → every @bind group → every extracted cell, capture
#   {notebook, group, bonds, argtypes, preamble, cell{fn_src, rettype, samples,
#    golden, ok, kind, mime, reasons}}
# Golden = native (PI-Pluto) output repr over a few sample bond combos. Extraction
# failures and non-bridge cells are recorded too (status tracked, not dropped) so
# the WT-side ledger can catch regressions in BOTH directions.
#
# Run (in PI's env):  julia --project=. tools/harvest_wt_fixtures.jl [notebook-substr]
# Flushes after EACH notebook, so a heavy/hanging notebook never loses prior work.

import Pluto, JSON
using PlutoIslands

const CORPUS = joinpath(@__DIR__, "..", "test", "notebooks", "featured")
const OUT = joinpath(@__DIR__, "..", "..", "WasmTarget.jl", "test", "integration", "pi_island_fixtures.json")
# lightest-deps first so partial runs already yield useful fixtures
const ORDER = [
    "Interactivity with HTML.jl", "Basic mathematics.jl", "CollatzConjecture.jl",
    "newton.jl", "PlutoUI.jl.jl", "fractals.jl", "convolution_1d.jl",
    "convolution_2d.jl", "images.jl", "dither.jl", "turtles-art.jl", "Titration.jl",
]

pattern = isempty(ARGS) ? "" : ARGS[1]
files = [f for f in ORDER if isfile(joinpath(CORPUS, f)) && occursin(pattern, f)]

# up to 4 sample bond-combos per group from the extracted domains (+ the initial)
function _samples(g)
    combos = Vector{Vector{Any}}()
    push!(combos, collect(g.initial_values))
    try
        if length(g.bond_names) == 1 && g.domains[1] isa AbstractVector && !isempty(g.domains[1])
            dom = g.domains[1]
            picks = unique(Any[dom[1], dom[(end+1)÷2], dom[end]])
            for v in picks
                c = [v]
                c != combos[1] && push!(combos, c)
            end
        elseif all(d -> d isa AbstractVector, g.domains)
            # multi-bond: domains[i] are per-bond value lists → vary one bond at a time
            for (i, dom) in enumerate(g.domains)
                (dom isa AbstractVector && !isempty(dom)) || continue
                c = collect(g.initial_values); c[i] = dom[end]
                c != combos[1] && push!(combos, c)
            end
        end
    catch
    end
    return combos[1:min(end, 4)]
end

session = Pluto.ServerSession()
session.options.evaluation.workspace_use_distributed = false

records = Any[]
flush!() = open(OUT, "w") do io; JSON.print(io, records, 2) end

for nbname in files
    println("=== ", nbname, " ===")
    nbrecs = Any[]
    try
        nb = Pluto.SessionActions.open(session, joinpath(CORPUS, nbname); run_async = false)
        state = Pluto.notebook_to_js(nb)
        conn = bound_variable_connections_graph(session, nb)
        groups = extract_groups(session, nb; connections = conn, original_state = state)
        for (gi, g) in enumerate(groups)
            grec = Dict{String,Any}(
                "notebook" => nbname, "group" => gi,
                "bonds" => string.(g.bond_names), "argtypes" => string.(g.arg_types),
                "group_ok" => g.ok, "group_reasons" => g.reasons,
                "preamble" => [string(ex) for ex in g.preamble],
                "cells" => Any[])
            samples = _samples(g)
            sb = Module(gensym(:hv))
            try Core.eval(sb, :(using Markdown)) catch end
            for ex in g.preamble
                try Core.eval(sb, ex) catch end
            end
            for p in g.cell_plans
                crec = Dict{String,Any}(
                    "cell_id" => string(p.cell_id), "extract_ok" => p.ok,
                    "kind" => string(p.body_kind), "mime" => p.mime,
                    "reasons" => p.reasons,
                    "fn_src" => p.fn_expr === nothing ? nothing : string(p.fn_expr))
                if p.fn_expr !== nothing
                    try
                        f = Core.eval(sb, p.fn_expr)
                        rt = Core.Compiler.widenconst(Base.code_typed(f, Tuple(g.arg_types))[1][2])
                        crec["rettype"] = string(rt)
                        crec["samples"] = [[repr(x) for x in s] for s in samples]
                        crec["golden"] = map(samples) do s
                            try repr(Base.invokelatest(f, s...)) catch e; "ERR:" * sprint(showerror, e) end
                        end
                    catch e
                        crec["eval_err"] = sprint(showerror, e)
                    end
                end
                push!(grec["cells"], crec)
            end
            push!(nbrecs, grec)
        end
        Pluto.SessionActions.shutdown(session, nb)
        println("  groups=", length(groups), " cells=", sum(g -> length(g["cells"]), nbrecs; init = 0))
    catch e
        push!(nbrecs, Dict{String,Any}("notebook" => nbname, "error" => sprint(showerror, e)))
        println("  NOTEBOOK ERROR: ", sprint(showerror, e))
    end
    append!(records, nbrecs)
    flush!()   # persist after every notebook
    println("  flushed → ", OUT)
end
println("HARVEST DONE: ", length(records), " group-records → ", OUT)
