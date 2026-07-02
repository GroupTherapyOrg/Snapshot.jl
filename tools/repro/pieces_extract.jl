# Repro the Basic-math :n feedback cell (no-initial-value range bond → cell errors
# at initial → stacktrace mime → was string(::MD) → unreachable). After the
# stacktrace-mime skeleton gate, it should extract via the skeleton, compile, and
# pass the oracle over sampled n (both branches).
import Pluto
using Snapshot

NB = joinpath(@__DIR__, "..", "..", "test", "notebooks", "pieces_pared.jl")
session = Pluto.ServerSession()
session.options.evaluation.workspace_use_distributed = false
nb = Pluto.SessionActions.open(session, NB; run_async=false)
st = Pluto.notebook_to_js(nb)
conn = bound_variable_connections_graph(session, nb)
groups = extract_groups(session, nb; connections=conn, original_state=st)
println("groups=", length(groups))
for g in groups
    println(" bonds=$(g.bond_names) ok=$(g.ok) synthetic=$(g.synthetic_initials) init=$(g.initial_values)")
    for p in g.cell_plans
        println("   cell $(p.cell_id) mime=$(p.mime) ok=$(p.ok) kind=$(p.body_kind)")
        p.ok || println("      reasons: $(p.reasons)")
    end
    if Sys.which("node") !== nothing && g.ok && all(p->p.ok, g.cell_plans)
        island = compile_group(g; verify_node=false)
        println("   island.ok=$(island.ok) reasons=$(island.reasons) cellfail=$(island.cell_failures)")
        if island.ok
            res = differential_oracle(session, nb, st, conn, g, island; samples=12)
            println("   oracle ok=$(res.ok) samples=$(res.samples_run) mismatch=$(res.mismatch)")
            isempty(res.failed_cells) || foreach(p->println("      FAIL $(p[1]): $(p[2])"), res.failed_cells)
        end
    end
end
Pluto.SessionActions.shutdown(session, nb; async=false)
