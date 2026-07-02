import Pluto, JSON
using Snapshot
session = Pluto.ServerSession()
out = "/tmp/collatz_pared_out"; mkpath(out)
nb = Pluto.SessionActions.open(session, "/Users/daleblack/Documents/dev/GroupTherapyOrg/Snapshot.jl/test/notebooks/collatz_pared.jl"; run_async=false)
st = Pluto.notebook_to_js(nb)
delete!(st, "status_tree")
generate_wasm_islands(session, nb, st; output_dir=out, url_path="collatz_pared.jl")
rep = JSON.parsefile(joinpath(out, "collatz_pared.islands", "report.json"))
for r in rep
    println("judgement: ", r["judgement"])
    for c in something(r["cells"], Any[])
        get(c, "ok", true) && continue
        println("  CELL keys=", collect(keys(c)), " ", get(c, "cell_id", get(c, "id", "?")), ": ", join(get(c, "reasons", []), " | ")[1:min(end, 400)])
    end
end
Pluto.SessionActions.shutdown(session, nb)
