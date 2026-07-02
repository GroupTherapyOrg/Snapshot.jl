# SINGLE SOURCE OF TRUTH for the featured-notebook job list. Used by BOTH
# docs/export_notebooks.jl AND the docs CI discover step, so the parallel matrix
# and the export can NEVER disagree on a slug (that mismatch broke the docs once).
#
# Base Julia only — NO deps — so the CI discover step runs `julia notebook_jobs.jl
# --json` to emit its matrix without instantiating the heavy Snapshot env.
#
# Each job is (path, slug): the source filename may contain spaces; the slug NEVER
# does — the static host 404s on %20 in paths, and the route + committed exports
# use underscores. So we read the real names and normalize once, here.

function notebook_jobs()
    here = @__DIR__
    corpus = joinpath(here, "..", "test", "notebooks", "featured")
    feat = sort(filter(f -> endswith(f, ".jl") && !occursin("backup", f), readdir(corpus)))
    # demos first (guaranteed-interactive showcases), then the featured corpus
    jobs = Tuple{String,String}[
        (joinpath(here, "..", "test", "notebooks", "demo.jl"), "wasm_islands_demo"),
        (joinpath(here, "..", "test", "notebooks", "two_groups.jl"), "two_groups"),
    ]
    for f in feat
        push!(jobs, (joinpath(corpus, f), replace(splitext(f)[1], " " => "_")))
    end
    return jobs
end

# CLI: `julia notebook_jobs.jl --json` → the CI matrix. Each item carries the slug
# (used as the export pattern + artifact name) and the repo-relative source path
# (used for the per-notebook cache-key hash). Hand-rolled JSON to stay dep-free.
if "--json" in ARGS   # CLI mode only; when export_notebooks.jl includes this, ARGS holds its pattern
    root = abspath(joinpath(@__DIR__, ".."))
    _esc(s) = replace(replace(string(s), "\\" => "\\\\"), "\"" => "\\\"")
    items = String[]
    for (path, slug) in notebook_jobs()
        rel = relpath(abspath(path), root)
        push!(items, "{\"slug\":\"$(_esc(slug))\",\"path\":\"$(_esc(rel))\"}")
    end
    println("[", join(items, ","), "]")
end
