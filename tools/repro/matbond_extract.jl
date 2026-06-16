# Validate Matrix{Float64} bond support (src/bridge.jl matrix marshalling) through
# the real pipeline: extract → compile → oracle over varied-size matrices.
import Pluto
using PlutoIslands

NB = joinpath(@__DIR__, "..", "..", "test", "notebooks", "matbond_pared.jl")
session = Pluto.ServerSession()
session.options.evaluation.workspace_use_distributed = false
nb = Pluto.SessionActions.open(session, NB; run_async=false)
st = Pluto.notebook_to_js(nb)
conn = bound_variable_connections_graph(session, nb)
groups = extract_groups(session, nb; connections=conn, original_state=st)
println("groups=", length(groups))
for g in groups
    println(" bonds=$(g.bond_names) types=$(g.arg_types) ok=$(g.ok) reasons=$(g.reasons)")
    for p in g.cell_plans; println("   cell $(p.cell_id) mime=$(p.mime) ok=$(p.ok)"); end
    if Sys.which("node") !== nothing && g.ok && all(p->p.ok, g.cell_plans)
        island = compile_group(g; verify_node=false)
        println("   island.ok=$(island.ok) reasons=$(island.reasons) cellfail=$(island.cell_failures)")
        if island.ok
            res = differential_oracle(session, nb, st, conn, g, island; samples=3)
            println("   oracle ok=$(res.ok) samples=$(res.samples_run) mismatch=$(res.mismatch)")
            isempty(res.failed_cells) || foreach(p->println("      FAIL $(p[1]): $(p[2])"), res.failed_cells)
        end
    end
end
Pluto.SessionActions.shutdown(session, nb; async=false)
