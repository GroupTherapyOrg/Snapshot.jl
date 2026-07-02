import Pluto, JSON
using Snapshot
session = Pluto.ServerSession()
out = mktempdir()
nb = Pluto.SessionActions.open(session, "test/notebooks/newton_pared.jl"; run_async=false)
st = Pluto.notebook_to_js(nb)
delete!(st, "status_tree")
generate_wasm_islands(session, nb, st; output_dir=out, url_path="newton_pared.jl")
rep = JSON.parsefile(joinpath(out, "newton_pared.islands", "report.json"))
for r in rep
    println("judgement: ", r["judgement"], "  bonds: ", get(r, "bonds", "?"))
    for x in something(r["reasons"], Any[]); println("  group reason: ", first(string(x), 200)); end
    for c in something(r["cells"], Any[])
        get(c, "ok", true) && continue
        println("  cell ", get(c, "cell_id", "?"), ": ", join(get(c, "reasons", []), " | ")[1:min(end,250)])
    end
end
Pluto.SessionActions.shutdown(session, nb)
