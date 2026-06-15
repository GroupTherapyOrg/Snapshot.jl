# Baseline/repro: extract the feedback_pared notebook and report each cell plan's
# ok-ness + reason + the generated body string at the initial bond value.
# Run: julia +1.12 --project=. tools/repro/feedback_extract.jl
import Pluto
using PlutoIslands

const NB = joinpath(@__DIR__, "..", "..", "test", "notebooks", "feedback_pared.jl")

session = Pluto.ServerSession()
session.options.evaluation.workspace_use_distributed = false
notebook = Pluto.SessionActions.open(session, NB; run_async=false)
original_state = Pluto.notebook_to_js(notebook)
connections = bound_variable_connections_graph(session, notebook)

groups = extract_groups(session, notebook; connections, original_state)
println("groups: ", length(groups))
for (gi, g) in enumerate(groups)
    println("── group $gi  bonds=$(g.bond_names)  types=$(g.arg_types)  init=$(g.initial_values)  ok=$(g.ok)")
    isempty(g.reasons) || println("   group reasons: ", g.reasons)
    sandbox = Module(:IslandSandbox)
    Core.eval(sandbox, :(using Markdown))
    for pe in g.preamble
        try Core.eval(sandbox, pe) catch e; println("   [preamble eval err] ", e); end
    end
    for p in g.cell_plans
        println("   cell $(p.cell_id)  mime=$(p.mime)  ok=$(p.ok)  kind=$(p.body_kind)")
        if !p.ok
            println("      reasons: ", p.reasons)
        else
            # native: does the fn reproduce the original body at the initial value?
            try
                f = Core.eval(sandbox, p.fn_expr)
                got = Base.invokelatest(f, g.initial_values...)
                want = original_state["cell_results"][p.cell_id]["output"]["body"]
                println("      native match @init: ", got == want)
                if got != want
                    println("      got:  ", repr(got))
                    println("      want: ", repr(want))
                end
            catch e
                println("      [fn eval/run err] ", e)
            end
        end
    end
end

# ── full compile + differential oracle (exercises BOTH if-branches as x varies) ──
if Sys.which("node") !== nothing
    g = groups[1]
    println("\n── compile + oracle ──")
    island = compile_group(g; verify_node=false)
    println("island.ok=$(island.ok)  cells=$(length(island.cells))  failures=$(island.cell_failures)")
    res = differential_oracle(session, notebook, original_state, connections, g, island; samples=12)
    println("oracle ok=$(res.ok)  samples_run=$(res.samples_run)")
    res.mismatch === nothing || println("  mismatch: ", res.mismatch)
    isempty(res.failed_cells) || foreach(p -> println("  FAIL $(p[1]): $(p[2])"), res.failed_cells)
else
    println("\n(node unavailable — skipped compile+oracle)")
end

Pluto.SessionActions.shutdown(session, notebook; async=false)
