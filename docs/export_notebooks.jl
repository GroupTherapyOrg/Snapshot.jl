# Export every featured notebook to docs/notebooks-static/ — static HTML plus
# wasm islands for every compilable bond group.
#
# BasisSimulator.jl docs pattern: exports are HASH-CACHED and COMMITTED. CI
# never runs notebooks — it inherits the committed exports and only builds the
# Therapy site around them. Re-render happens only when a notebook's source
# changes (or FORCE_NB_REBUILD=1).
#
# Writes index.json: one entry per notebook with title/description (from Pluto
# frontmatter), status (interactive | static | failed), island/fallback counts,
# and the source hash for caching. Notebooks whose CELLS error still export —
# Pluto shows those errors inside the cells. Only whole-run failures are
# marked "failed" (with the error in the gallery).
#
# Run from repo root (the package env itself):
#   julia --project=. docs/export_notebooks.jl [pattern]

using PlutoIslands
import Pluto
import JSON
using SHA: sha256, bytes2hex

const CORPUS = joinpath(@__DIR__, "..", "test", "notebooks", "featured")
const OUT = joinpath(@__DIR__, "notebooks-static")
const INDEX = joinpath(OUT, "index.json")
mkpath(OUT)

pattern = isempty(ARGS) ? "" : ARGS[1]
force = get(ENV, "FORCE_NB_REBUILD", "0") == "1"

old_index = isfile(INDEX) ? Dict(e["slug"] => e for e in JSON.parsefile(INDEX)) : Dict()

"frontmatter `#> key = \"value\"` reader (title/description), no notebook run needed"
function frontmatter_field(src::String, key::String)
    m = match(Regex("^#>\\s+$(key)\\s*=\\s*\"(.*)\"\\s*\$", "m"), src)
    m === nothing ? nothing : String(m.captures[1])
end

"Read a notebook's island (group-level) AND cell-level counts from its exported
`.islands/` dir. coverage.json (PI's accurate cell tally) is the real metric —
a 'partial' group ships an island but still has non-interactive fallback CELLS,
so the group count alone overstates interactivity."
function read_counts(slug::AbstractString)
    dir = joinpath(OUT, slug * ".islands")
    islands = degraded = 0
    rp = joinpath(dir, "report.json")
    if isfile(rp)
        r = JSON.parsefile(rp)
        islands = count(g -> g["judgement"] != "fallback", r)
        degraded = count(g -> g["judgement"] == "fallback", r)
    end
    ci = cf = ct = 0
    cp = joinpath(dir, "coverage.json")
    if isfile(cp)
        cells = get(JSON.parsefile(cp), "cells", Dict())
        ci = get(cells, "interactive", 0)
        cf = get(cells, "fallback", 0)
        ct = get(cells, "total", 0)
    end
    (; islands, degraded, cells_interactive=ci, cells_fallback=cf, cells_total=ct)
end

"merge island/cell counts into an index entry (single source of the schema)"
function apply_counts!(entry::AbstractDict, c)
    entry["islands"] = c.islands
    entry["degraded"] = c.degraded
    entry["cells_interactive"] = c.cells_interactive
    entry["cells_fallback"] = c.cells_fallback
    entry["cells_total"] = c.cells_total
    entry["status"] = c.islands > 0 ? "interactive" : "static"
    entry
end

# featured corpus + our own demo notebooks (guaranteed-interactive showcases)
jobs = [(joinpath(CORPUS, f), splitext(f)[1])
        for f in sort(filter(f -> endswith(f, ".jl") && !occursin("backup", f), readdir(CORPUS)))]
pushfirst!(jobs, (joinpath(@__DIR__, "..", "test", "notebooks", "two_groups.jl"), "two_groups"))
pushfirst!(jobs, (joinpath(@__DIR__, "..", "test", "notebooks", "demo.jl"), "wasm islands demo"))
all_slugs = [j[2] for j in jobs]
filter!(j -> occursin(pattern, j[2] * ".jl"), jobs)

# pattern runs must not clobber the other notebooks' entries
entries = [old_index[s] for s in all_slugs
           if haskey(old_index, s) && !any(j -> j[2] == s, jobs)]

for (i, (path, slug)) in enumerate(jobs)
    f = basename(path)
    src = read(path, String)
    hash = bytes2hex(sha256(src))
    html_name = slug * ".html"

    # exports are named after the source file — stage under the slug name
    # when they differ (e.g. demo/m0/notebook.jl → "wasm islands demo.jl")
    if basename(path) != slug * ".jl"
        staged = joinpath(mktempdir(), slug * ".jl")
        cp(path, staged)
        path = staged
    end

    old = get(old_index, slug, nothing)
    if !force && old !== nothing && get(old, "hash", "") == hash &&
       isfile(joinpath(OUT, get(old, "html", html_name)))
        # refresh presentation-only fields without re-exporting
        old["title"] = something(frontmatter_field(src, "title"), replace(slug, "_" => " "))
        old["description"] = something(frontmatter_field(src, "description"), "")
        old["image"] = something(frontmatter_field(src, "image"), "island-demo.svg")
        # refresh counts from the on-disk export (schema may have grown cell-level
        # fields since this entry was first written — no re-export needed)
        get(old, "status", "") == "failed" || apply_counts!(old, read_counts(slug))
        @info "[$i/$(length(jobs))] cached ✓" slug
        push!(entries, old)
        continue
    end

    @info "[$i/$(length(jobs))] exporting…" slug
    t0 = time()
    entry = Dict{String,Any}(
        "slug" => slug,
        "html" => html_name,
        "hash" => hash,
        "title" => something(frontmatter_field(src, "title"), replace(slug, "_" => " ")),
        "description" => something(frontmatter_field(src, "description"), ""),
        # frontmatter image URL, else our own card art (site-relative asset)
        "image" => something(frontmatter_field(src, "image"), "island-demo.svg"),
    )
    try
        PlutoIslands.export_notebook(path; output_dir=OUT)
        isfile(joinpath(OUT, html_name)) || error("export produced no HTML (notebook failed to run?)")
        # island (group) + accurate cell-level counts from the export's report/coverage
        apply_counts!(entry, read_counts(slug))
    catch e
        entry["status"] = "failed"
        entry["error"] = first(sprint(showerror, e), 500)
        @error "export failed" slug exception = (e, catch_backtrace())
    end
    entry["seconds"] = round(time() - t0; digits=1)
    push!(entries, entry)

    # checkpoint after every notebook — long runs are resumable
    write(INDEX, JSON.json(entries, 2))
end

write(INDEX, JSON.json(entries, 2))
n_int = count(e -> e["status"] == "interactive", entries)
n_static = count(e -> e["status"] == "static", entries)
n_fail = count(e -> e["status"] == "failed", entries)
cells_int = sum(e -> get(e, "cells_interactive", 0), entries; init=0)
cells_tot = sum(e -> get(e, "cells_total", 0), entries; init=0)
cells_fb = sum(e -> get(e, "cells_fallback", 0), entries; init=0)
println("EXPORT DONE: $(n_int) interactive · $(n_static) static · $(n_fail) failed notebooks")
println("             $(cells_int)/$(cells_tot) bond-cells interactive · $(cells_fb) fallback → $OUT")
