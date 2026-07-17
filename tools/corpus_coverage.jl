# Regenerate the ACCURATE featured-corpus island-coverage report.
#
# Exports every featured notebook through the real pipeline (export_notebook →
# WasmTarget compile → differential/canvas oracle) and records, per notebook, the
# CELL-LEVEL coverage from each export's `coverage.json`:
#   cells:  interactive / fallback / total   ← the REAL number (a "partial" group
#                                               ships an island but still has fallback
#                                               cells; those are non-interactive on the
#                                               deployed page — the group-level island
#                                               count overstates interactivity)
#   groups: island / partial / fallback / total
#
# Writes `test/featured_coverage.json` (committed source of truth) + prints a table.
# Run:  julia --project=. tools/corpus_coverage.jl  [notebook-substr]
# This is the canonical "count fallbacks for real" regen; the CI gate compares a
# fresh run against the committed file so the corpus can't silently regress.

using Snapshot, JSON

const CORPUS = joinpath(@__DIR__, "..", "test", "notebooks", "featured")
const OUT    = joinpath(@__DIR__, "..", "test", "featured_coverage.json")

function corpus_coverage(pattern = "")
    nbs = sort([f for f in readdir(CORPUS) if endswith(f, ".jl") && occursin(pattern, f)])
    results = Dict{String,Any}()
    println(rpad("notebook", 28), "  cells (interactive/total, fallback)   groups (i/p/f)")
    for nb in nbs
        out = mktempdir()
        rec = Dict{String,Any}()
        try
            export_notebook(joinpath(CORPUS, nb); output_dir = out, verify = true,
                            oracle_samples = 3, therapy = true)
            cov = nothing
            for (root, _, files) in walkdir(out), f in files
                f == "coverage.json" && (cov = JSON.parsefile(joinpath(root, f)))
            end
            if cov === nothing
                rec["error"] = "no coverage.json produced"
            else
                rec["cells"] = cov["cells"]; rec["groups"] = cov["groups"]
            end
        catch e
            rec["error"] = first(sprint(showerror, e), 200)
        end
        results[nb] = rec
        if haskey(rec, "cells")
            c = rec["cells"]; g = rec["groups"]
            println(rpad(nb, 28), "  ", rpad("$(c["interactive"])/$(c["total"]) ($(c["fallback"]) fb)", 36),
                    "$(g["island"])i $(g["partial"])p $(g["fallback"])f")
        else
            println(rpad(nb, 28), "  ERROR: ", get(rec, "error", "?"))
        end
    end
    ti = sum(get(get(r, "cells", Dict()), "interactive", 0) for r in values(results); init = 0)
    tf = sum(get(get(r, "cells", Dict()), "fallback", 0) for r in values(results); init = 0)
    summary = Dict("interactive" => ti, "fallback" => tf, "total" => ti + tf)
    open(OUT, "w") do io
        JSON.print(io, Dict("summary" => summary, "notebooks" => results), 2)
    end
    println("\nCORPUS TOTAL: ", ti, " interactive, ", tf, " fallback (", ti + tf, " cells) → ", OUT)
    return results
end

corpus_coverage(isempty(ARGS) ? "" : ARGS[1])
