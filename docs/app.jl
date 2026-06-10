#!/usr/bin/env julia
# PlutoIslands.jl documentation site
#
# Usage (from repo root):
#   julia --project=docs docs/app.jl dev    # Development server with HMR
#   julia --project=docs docs/app.jl build  # Build static site to docs/dist
#
# Built with Therapy.jl, mirroring the Therapy.jl docs. Two pages:
#   /            — what this fork is + quickstart
#   /notebooks/  — the featured-notebook gallery (static or wasm-islands
#                  exports, pre-rendered by docs/export_notebooks.jl and
#                  COMMITTED — CI only builds this site and deploys)

if !haskey(ENV, "JULIA_PROJECT")
    using Pkg
    Pkg.activate(@__DIR__)
end

using Therapy

cd(@__DIR__)

# Base path: empty in dev (localhost:8080/notebooks/), repo name on GH Pages
const IS_BUILD = length(ARGS) > 0 && ARGS[1] == "build"
ENV["PIDOCS_BASE"] = IS_BUILD ? "/PlutoIslands.jl" : ""

app = App(
    routes_dir = "src/routes",
    components_dir = "src/components",
    title = "PlutoIslands.jl",
    output_dir = "dist",
    base_path = ENV["PIDOCS_BASE"],
    layout = :Layout,
)

# Load file-based routes + components first so the per-notebook route
# handlers below can reference NotebookPage (BasisSimulator docs pattern).
Therapy.load_app!(app)

# Pre-rendered notebook exports (committed; see docs/export_notebooks.jl)
let nb_static = joinpath(@__DIR__, "notebooks-static")
    isdir(nb_static) && Therapy.staticfiles(app, nb_static, "notebooks-static")
end
# card art + site assets
let assets = joinpath(@__DIR__, "assets")
    isdir(assets) && Therapy.staticfiles(app, assets, "assets")
end

# Per-notebook routes — /notebooks/<slug>/ renders the export in an iframe
# INSIDE the docs layout (no full-page navigation away from the webapp).
import JSON
let index_path = joinpath(@__DIR__, "notebooks-static", "index.json"),
    host = isdefined(Main, :TherapyApp) ? getfield(Main, :TherapyApp) : Main

    NotebookPage = isdefined(host, :NotebookPage) ? getfield(host, :NotebookPage) : nothing
    if NotebookPage === nothing
        @warn "[docs] NotebookPage component not found — per-notebook routes skipped"
    elseif isfile(index_path)
        for e in JSON.parsefile(index_path)
            e["status"] == "failed" && continue
            route = "/notebooks/$(e["slug"])/"
            push!(app.routes, route => let np = NotebookPage,
                    slug = e["slug"], title = e["title"], html = e["html"],
                    status = e["status"], islands = Int(get(e, "islands", 0))
                () -> Base.invokelatest(np, slug, title, html, status, islands)
            end)
            println("  Registered notebook route: $(route)")
        end
    end
end

Therapy.run(app)
