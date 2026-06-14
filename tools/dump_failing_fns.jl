# Dump the EXACT recompute function (fn_expr source + arg_types) for every cell
# whose WasmTarget.compile fails — the raw material for minimal fuzz repros.
#
# Run:  julia +1.12 --project=. tools/dump_failing_fns.jl "Basic mathematics"

import Pluto
import WasmTarget
import Pkg
using PlutoIslands
const M = PlutoIslands

pattern = isempty(ARGS) ? "Basic mathematics" : ARGS[1]
const CORPUS = joinpath(@__DIR__, "..", "test", "notebooks", "featured")
file = first(f for f in readdir(CORPUS) if occursin(pattern, f))
path = joinpath(CORPUS, file)
println("### notebook: ", file)

session = Pluto.ServerSession()
notebook = Pluto.SessionActions.open(session, path; run_async=false)
original_state = Pluto.notebook_to_js(notebook)
groups = M.extract_groups(session, notebook; original_state)

nb_env = notebook.nbpkg_ctx === nothing ? nothing :
    try Pluto.PkgCompat.env_dir(notebook.nbpkg_ctx) catch; nothing end
prev = Base.active_project()
nb_env !== nothing && Pkg.activate(nb_env; io=devnull)

for (gi, g) in enumerate(groups)
    g.ok || continue
    sandbox = Module(gensym(:Dump))
    try
        Core.eval(sandbox, :(using Markdown)); Core.eval(sandbox, :(using InteractiveUtils))
        for pre in g.preamble; Core.eval(sandbox, pre); end
    catch e
        println("\n[group $gi bonds=$(g.bond_names)] preamble eval failed: ", first(sprint(showerror,e),120)); continue
    end
    argt = Tuple(g.arg_types)
    for p in g.cell_plans
        p.ok || continue
        f = try Core.eval(sandbox, p.fn_expr) catch; continue end
        # skip canvas/image probe rewrites — we want the raw WT.compile verdict
        try
            WasmTarget.compile(f, argt)
        catch e
            msg = first(sprint(showerror, e), 220)
            (occursin("Validation", string(typeof(e))) || occursin("validate", msg) ||
             occursin("expected", msg) || occursin("CompileError", string(typeof(e)))) || continue
            println("\n========================================================")
            println("GROUP $gi bonds=", g.bond_names, "  arg_types=", argt)
            println("CELL ", p.cell_id, "  mime=", p.mime)
            println("ERROR: ", msg)
            println("FN_EXPR:\n", p.fn_expr)
        end
    end
end
nb_env !== nothing && Pkg.activate(dirname(prev); io=devnull)
Pluto.SessionActions.shutdown(session, notebook; async=false)
println("\nDUMP DONE")
