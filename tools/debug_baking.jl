# Debug why function-bond baking does/doesn't fire on PlutoUI.
# Opens PlutoUI, extracts groups, and for every bond reports: observed type,
# whether a transform table was built, and whether a bake fired.
#
# Run:  julia +1.12 --project=. tools/debug_baking.jl

import Pluto
import WasmTarget
using Snapshot
const M = Snapshot

const NB = joinpath(@__DIR__, "..", "test", "notebooks", "featured", "PlutoUI.jl.jl")

session = Pluto.ServerSession()
notebook = Pluto.SessionActions.open(session, NB; run_async=false)
original_state = Pluto.notebook_to_js(notebook)

# Mirror the extract_groups bond loop probes WITHOUT the full pipeline, for the
# function-valued bonds specifically.
for n in (:which_function, :favourite_function, :my_functions, :vegetable, :fruit)
    println("\n=== bond ", n, " ===")
    v = try
        Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook), n)
    catch e
        println("  eval_fetch FAILED: ", typeof(e)); missing
    end
    println("  observed value type: ", v === missing ? "missing" : typeof(v))
    pv = try
        Pluto.possible_bond_values(session, notebook, n)
    catch e
        println("  possible_bond_values FAILED: ", typeof(e)); nothing
    end
    println("  possible_bond_values: ", pv isa Symbol ? pv :
            pv === nothing ? "nothing" : "len=$(length(collect(pv)))  $(first(collect(pv), min(3,length(collect(pv)))))")
    if pv !== nothing && !(pv isa Symbol)
        raw_domain = collect(Any, pv)
        transformed = try
            Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook),
                :(map(r -> Main.PlutoRunner.transform_bond_value($(QuoteNode(n)), r), $(raw_domain))))
        catch e
            println("  transform fetch FAILED: ", typeof(e)); nothing
        end
        if transformed !== nothing
            println("  transformed types: ", typeof(transformed), "  elts: ", first(transformed, min(3,length(transformed))))
            nonident = any(!isequal(t, r) for (t, r) in zip(transformed, raw_domain))
            println("  non-identity transform: ", nonident)
            tbl = collect(zip(raw_domain, transformed))
            println("  all transformed _bakeable: ", all(p -> M._bakeable(p[2]), tbl))
            println("  all raw keys bridge-supported: ",
                    all(p -> WasmTarget.Bridge.args_supported(typeof(p[1])), tbl))
        end
    end
end

# And the real verdict: what arg_types / bakes does extract_groups produce?
println("\n\n=== extract_groups verdict ===")
groups = M.extract_groups(session, notebook; original_state)
for g in groups
    any(n -> n in (:which_function, :favourite_function, :my_functions), g.bond_names) || continue
    println("group bonds=", g.bond_names, " arg_types=", g.arg_types, " ok=", g.ok)
    isempty(g.reasons) || println("  reasons: ", g.reasons)
end
Pluto.SessionActions.shutdown(session, notebook; async=false)
println("\nDEBUG DONE")
