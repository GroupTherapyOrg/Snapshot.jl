# exporter.jl — the two-level public API.
#
#   export_notebook(path; ...)            — run a notebook in Pluto, write the
#       classic static HTML export PLUS wasm islands. Self-contained: the HTML
#       writer is absorbed from PlutoSliderServer's generate_static_export and
#       uses only Pluto APIs.
#
#   generate_wasm_islands(session, notebook, original_state; ...) — the
#       integrator hook: given an already-RUNNING notebook, extract bond
#       groups, compile + verify islands, write `<name>.islands/` assets, and
#       return the directory basename for HTML injection. This is what a
#       slider-server-style exporter (e.g. the PlutoSliderServer fork) calls.

import Pluto: without_pluto_file_extension
using Base64: base64encode

"""
    generate_wasm_islands(session, notebook, original_state;
                          output_dir, url_path,
                          verify=true, oracle_samples=5,
                          max_wasm_size_per_group=5_000_000,
                          fallback_warnings=true) -> Union{Nothing,String}

Compile every bond group of a RUNNING notebook to wasm islands (per-cell
granularity, Node-verified, differential-oracle checked) and write the
`<name>.islands/` asset directory. Returns the directory basename, or
`nothing` when no island shipped (the report + warning shim are still
written whenever the notebook has bond groups).

Set `fallback_warnings=false` when a precompute/live slider-server backend
will serve the non-island groups — they are interactive then, just not wasm.
"""
function generate_wasm_islands(
    session::Pluto.ServerSession,
    notebook::Pluto.Notebook,
    original_state::Dict;
    output_dir::AbstractString,
    url_path::AbstractString,
    verify::Bool=true,
    oracle_samples::Integer=5,
    max_wasm_size_per_group::Integer=5_000_000,
    fallback_warnings::Bool=true,
)::Union{Nothing,String}
    connections = bound_variable_connections_graph(session, notebook)
    groups = extract_groups(session, notebook; connections, original_state)
    isempty(groups) && return nothing

    # original output bodies (String bodies only — tree+object bodies are Dicts)
    initial_bodies = Dict{String,String}()
    for (id, cr) in original_state["cell_results"]
        body = try
            cr["output"]["body"]
        catch
            nothing
        end
        body isa String && (initial_bodies[string(id)] = body)
    end

    islands = CompiledIsland[]
    report = []   # the judgement record, one entry per group
    for g in groups
        island = compile_group(g;
            # missing-initial groups: original bodies are missing-tainted and
            # not reproducible — skip initial-body check, the oracle covers them
            initial_bodies=g.synthetic_initials ? nothing : initial_bodies,
            verify_node=verify)
        if island.ok && length(island.bytes) > max_wasm_size_per_group
            island = CompiledIsland(;
                bond_names=island.bond_names, arg_types=island.arg_types,
                initial_values=island.initial_values, bytes=UInt8[], cells=[],
                ok=false,
                reasons=["wasm size $(length(island.bytes)) exceeds max_wasm_size_per_group"])
        end

        oracle = nothing
        if island.ok && verify
            oracle = differential_oracle(
                session, notebook, original_state, connections, g, island;
                samples=oracle_samples)
            if oracle.mismatch !== nothing
                # global oracle failure → whole group degrades
                island = CompiledIsland(;
                    bond_names=island.bond_names, arg_types=island.arg_types,
                    initial_values=island.initial_values, bytes=UInt8[], cells=[],
                    ok=false, reasons=["differential oracle: $(oracle.mismatch)"],
                    cell_failures=island.cell_failures)
            elseif !isempty(oracle.failed_cells)
                # per-cell mismatches → exclude exactly those cells
                island = exclude_cells(island, oracle.failed_cells)
                if isempty(island.cells)
                    island = CompiledIsland(;
                        bond_names=island.bond_names, arg_types=island.arg_types,
                        initial_values=island.initial_values, bytes=UInt8[], cells=[],
                        ok=false, reasons=["no cells survived the differential oracle"],
                        cell_failures=island.cell_failures)
                end
            end
        end

        ship = island.ok && !isempty(island.cells)

        # per-cell record: surviving cells (ok), per-cell failures (reasons),
        # and — for group-level failures — every dependent cell inherits the
        # group reasons. The shim decorates exactly the ok=false entries.
        dependent_cell_ids = [string(c.cell_id) for c in _dependent_cells(notebook.topology, g.bond_names)]
        explicit = Dict{String,Any}()
        for c in island.cells
            explicit[c.cell_id] = Dict("id" => c.cell_id, "ok" => true)
        end
        for cf in island.cell_failures
            explicit[cf.cell_id] = Dict("id" => cf.cell_id, "ok" => false, "reasons" => cf.reasons)
        end
        cell_records = [
            get(explicit, id) do
                Dict("id" => id, "ok" => false,
                     "reasons" => isempty(island.reasons) ? ["group degraded"] : island.reasons)
            end for id in dependent_cell_ids
        ]

        push!(report, Dict(
            "bonds" => string.(g.bond_names),
            "judgement" => !ship ? "fallback" :
                           any(r -> !r["ok"], cell_records) ? "partial" : "island",
            "reasons" => island.reasons,
            "oracle_samples" => oracle === nothing ? 0 : oracle.samples_run,
            "oracle_skipped" => oracle === nothing ? nothing : oracle.skipped_reason,
            "cells" => cell_records,
        ))
        if ship
            push!(islands, island)
            @info "🏝️ island compiled" url_path bonds = island.bond_names cells =
                length(island.cells) failed_cells = length(island.cell_failures) wasm_kb =
                round(length(island.bytes) / 1024; digits=1) oracle_samples =
                oracle === nothing ? 0 : oracle.samples_run
        else
            @warn "🏝️ bond group degraded to fallback" url_path bonds = g.bond_names reasons =
                island.reasons
        end
    end

    islands_dirname = without_pluto_file_extension(basename(url_path)) * ".islands"
    assets_dir = joinpath(output_dir, dirname(url_path), islands_dirname)
    # the judgement report is written even when NO island shipped — it is the
    # debugging/metric surface AND drives the shim's fallback-warning chrome
    mkpath(assets_dir)
    write(joinpath(assets_dir, "report.json"), JSON.json(report))

    # ship the shim even with zero islands: it still serves bondconnections
    # (the FULL bond graph lets non-island staterequests pass through to
    # precompute files / a live slider server) and decorates fallback cells
    bond_graph = Dict(string(k) => string.(v) for (k, v) in connections)
    write_island_assets(assets_dir, islands; bond_graph, fallback_warnings)
    n_degraded = count(r -> r["judgement"] == "fallback", report)
    @info "🏝️ wasm islands written" url_path islands = length(islands) degraded = n_degraded dir =
        assets_dir
    islands_dirname
end

"""
Inject the islands shim `<script>` into exported HTML (idempotent). The tag
goes right after `<head>` so fetch interception is installed before any
editor module executes.
"""
function inject_islands_script(html::String, islands_dirname::String)::String
    tag = "<script src=\"./$(islands_dirname)/shim.js\"></script>"
    occursin(tag, html) && return html
    replace(html, "<head>" => "<head>" * tag; count=1)
end

# ─────────────────────────────────────────────────────────────────────────────
# Self-contained notebook export (absorbed from PSS generate_static_export —
# Pluto APIs only)
# ─────────────────────────────────────────────────────────────────────────────

"""
    export_notebook(notebook_path; output_dir=dirname(notebook_path),
                    islands=true, verify=true, oracle_samples=5,
                    baked_state=true, baked_notebookfile=true,
                    disable_ui=true, pluto_cdn_root=nothing,
                    session=nothing) -> output html path

Run a Pluto notebook and write a static HTML export where every compilable
`@bind` group is interactive via WasmTarget-compiled wasm islands — no Julia
server, no precomputed request files. Cells whose bond group could not
compile keep their original content and are decorated with a Pluto-style
warning explaining why.
"""
function export_notebook(
    notebook_path::AbstractString;
    output_dir::AbstractString=dirname(abspath(notebook_path)),
    islands::Bool=true,
    verify::Bool=true,
    oracle_samples::Integer=5,
    max_wasm_size_per_group::Integer=5_000_000,
    baked_state::Bool=true,
    baked_notebookfile::Bool=true,
    disable_ui::Bool=true,
    pluto_cdn_root::Union{Nothing,String}=nothing,
    session::Union{Nothing,Pluto.ServerSession}=nothing,
)
    mkpath(output_dir)
    jl_contents = read(notebook_path, String)
    name = without_pluto_file_extension(basename(notebook_path))

    own_session = session === nothing
    session = something(session, Pluto.ServerSession())
    notebook = Pluto.SessionActions.open(session, abspath(notebook_path); run_async=false)
    original_state = Pluto.notebook_to_js(notebook)
    delete!(original_state, "status_tree")

    islands_dirname = nothing
    if islands
        islands_dirname = try
            generate_wasm_islands(
                session, notebook, original_state;
                output_dir, url_path=basename(notebook_path),
                verify, oracle_samples, max_wasm_size_per_group)
        catch e
            @error "🏝️ island generation failed — exporting static" exception =
                (e, catch_backtrace())
            nothing
        end
    end

    Pluto.SessionActions.shutdown(session, notebook; async=false)
    own_session && @async nothing  # session owns no server; nothing to stop

    # write export files (Pluto.generate_html — same output as PSS / the
    # in-Pluto export button)
    export_html_path = joinpath(output_dir, name * ".html")
    statefile_js = if baked_state
        "\"data:;base64,$(base64encode(io -> Pluto.pack(io, original_state)))\""
    else
        statefile_path = joinpath(output_dir, name * ".plutostate")
        write(statefile_path, sprint(Pluto.pack, original_state))
        repr(basename(statefile_path))
    end
    notebookfile_js = if baked_notebookfile
        "\"data:text/julia;charset=utf-8;base64,$(base64encode(jl_contents))\""
    else
        export_jl_path = joinpath(output_dir, name * ".jl")
        abspath(export_jl_path) == abspath(notebook_path) || write(export_jl_path, jl_contents)
        repr(basename(export_jl_path))
    end

    frontmatter = convert(
        Pluto.FrontMatter,
        get(() -> Pluto.FrontMatter(),
            get(() -> Dict{String,Any}(), original_state, "metadata"), "frontmatter"),
    )

    html = Pluto.generate_html(;
        pluto_cdn_root,
        version=Pluto.PLUTO_VERSION,
        notebookfile_js,
        statefile_js,
        # the shim impersonates a slider server in-tab; the client must engage
        slider_server_url_js=islands_dirname === nothing ? "undefined" : "\".\"",
        binder_url_js="undefined",
        disable_ui,
        header_html=Pluto.frontmatter_html(frontmatter),
    )
    islands_dirname !== nothing && (html = inject_islands_script(html, islands_dirname))
    write(export_html_path, html)
    export_html_path
end
