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
    shared_fonts_path::Union{Nothing,AbstractString}=nothing,
    # WasmTarget.optimize level applied to every island: false (off) |
    # true/:size (-Os) | :speed (-O3) | :debug (-O1). Verify + oracle run on the
    # OPTIMIZED bytes below, so we always verify exactly what we ship.
    optimize=false,
    # notebooks using the Pkg.activate escape hatch (nbpkg disabled, e.g. for
    # unregistered packages like WasmMakie) have no nbpkg env to detect —
    # callers pass the activated env here. With in-process workspaces the env
    # must also REMAIN active while this runs: Pluto re-evals the notebook's
    # `using`s in each fresh workspace module the oracle's bond re-runs create
    env_dir::Union{Nothing,String}=nothing,
)::Union{Nothing,String}
    connections = bound_variable_connections_graph(session, notebook)
    groups = extract_groups(session, notebook; connections, original_state)
    isempty(groups) && return nothing

    # original output bodies — String for text mimes, Dict for tree+object
    initial_bodies = Dict{String,Any}()
    for (id, cr) in original_state["cell_results"]
        body = try
            cr["output"]["body"]
        catch
            nothing
        end
        (body isa String || body isa AbstractDict) && (initial_bodies[string(id)] = body)
    end

    nb_env_dir = env_dir !== nothing ? env_dir :
        notebook.nbpkg_ctx === nothing ? nothing :
        try Pluto.PkgCompat.env_dir(notebook.nbpkg_ctx) catch; nothing end

    islands = CompiledIsland[]
    all_islands = CompiledIsland[]   # per-group, shipped or not (state refresh)
    report = []   # the judgement record, one entry per group
    for g in groups
        island = compile_group(g;
            env_dir=nb_env_dir,
            # missing-initial groups: original bodies are missing-tainted and
            # not reproducible — skip initial-body check, the oracle covers them
            initial_bodies=g.synthetic_initials ? nothing : initial_bodies,
            verify_node=verify,
            optimize)
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
        _cell_code(id) = begin
            c = get(notebook.cells_dict, Base.UUID(id), nothing)
            c === nothing ? nothing : c.code
        end
        for cf in island.cell_failures
            rec = Dict{String,Any}("id" => cf.cell_id, "ok" => false, "reasons" => cf.reasons)
            # the structured WasmTarget diagnostic (kind/func/construct/loc + the exact
            # offending CELL parsed from the #==# source path) — drives the shim's card
            if cf.diag !== nothing
                rec["diag"] = cf.diag
                code = _cell_code(cf.cell_id)
                code !== nothing && (rec["code"] = code)
                oc = get(cf.diag, "cell", nothing)
                if oc !== nothing && oc != cf.cell_id
                    occode = _cell_code(oc)
                    occode !== nothing && (rec["offending_code"] = occode)
                end
            end
            explicit[cf.cell_id] = rec
        end
        cell_records = [
            get(explicit, id) do
                Dict("id" => id, "ok" => false,
                     "reasons" => isempty(island.reasons) ? ["group degraded"] : island.reasons)
            end for id in dependent_cell_ids
        ]

        push!(report, Dict(
            "bonds" => string.(g.bond_names),
            "arg_types" => string.(island.arg_types),
            "judgement" => !ship ? "fallback" :
                           any(r -> !r["ok"], cell_records) ? "partial" : "island",
            "reasons" => island.reasons,
            "oracle_samples" => oracle === nothing ? 0 : oracle.samples_run,
            "oracle_skipped" => oracle === nothing ? nothing : oracle.skipped_reason,
            "cells" => cell_records,
        ))
        push!(all_islands, island)
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

    # make the EXPORTED initial state self-consistent: synthetic-initial groups
    # ran headless with `missing` — set their introspected initials through the
    # real bond machinery so the re-snapshotted statefile shows real bodies
    # (callers re-take notebook_to_js after this returns)
    for (g, island) in zip(groups, all_islands)
        (island.ok && !isempty(island.cells) && g.synthetic_initials) || continue
        try
            run = RunningNotebook(; path=string(notebook.path), notebook,
                original_state, bond_connections=connections)
            bonds = Dict{Symbol,Any}(
                n => Dict{String,Any}("value" => _raw_initial(g, j))
                for (j, n) in enumerate(g.bond_names))
            run_bonds_get_patches(session, run, bonds, nothing)
        catch e
            @warn "🏝️ initial-state refresh failed for group" bonds = g.bond_names exception = e
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
    write_island_assets(assets_dir, islands; bond_graph, fallback_warnings, shared_fonts_path)
    # Accurate, CELL-LEVEL coverage. A "partial" group ships an island but STILL has
    # fallback cells — those are non-interactive on the deployed page, so the group-level
    # island count overstates interactivity (the count then disagrees with what you see
    # on GitHub Pages). Count what actually ships, per cell. `coverage.json` is the
    # source of truth for audits / the CI island-count gate / the site.
    cell_recs = collect(Iterators.flatten(r["cells"] for r in report))
    coverage = Dict(
        "groups" => Dict(
            "island"   => count(r -> r["judgement"] == "island", report),
            "partial"  => count(r -> r["judgement"] == "partial", report),
            "fallback" => count(r -> r["judgement"] == "fallback", report),
            "total"    => length(report)),
        "cells" => Dict(
            "interactive" => count(c -> c["ok"], cell_recs),
            "fallback"    => count(c -> !c["ok"], cell_recs),
            "total"       => length(cell_recs)))
    write(joinpath(assets_dir, "coverage.json"), JSON.json(coverage))
    @info "🏝️ wasm islands written" url_path islands_shipped = length(islands) groups_island =
        coverage["groups"]["island"] groups_partial = coverage["groups"]["partial"] groups_fallback =
        coverage["groups"]["fallback"] cells_interactive = coverage["cells"]["interactive"] cells_fallback =
        coverage["cells"]["fallback"] dir = assets_dir
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
    # WasmTarget.optimize level for every island: false | true/:size | :speed | :debug
    optimize=false,
    baked_state::Bool=true,
    baked_notebookfile::Bool=true,
    disable_ui::Bool=true,
    pluto_cdn_root::Union{Nothing,String}=nothing,
    session::Union{Nothing,Pluto.ServerSession}=nothing,
    env_dir::Union{Nothing,String}=nothing,
    shared_fonts_path::Union{Nothing,AbstractString}=nothing,
    # therapy=true → emit a LEAN standalone page (SSR cells + the wasm islands
    # driven directly from HTML inputs), no Pluto frontend / no baked statefile.
    therapy::Bool=false,
    # therapy-only: render the floating theme picker (true for standalone pages;
    # pass false when embedding in a host app that supplies its own picker).
    theme_picker::Bool=true,
    # therapy-only: ALSO write `<name>.fragment.html` — a native-inline component
    # (no <html>/<body>, @scope-isolated CSS, asset URLs left as the `assets_base`
    # placeholder) for embedding directly into a host app / collection shell.
    fragment::Bool=false,
    assets_base::AbstractString="",
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
                verify, oracle_samples, max_wasm_size_per_group, env_dir, optimize,
                shared_fonts_path)
        catch e
            @error "🏝️ island generation failed — exporting static" exception =
                (e, catch_backtrace())
            nothing
        end
    end

    if islands_dirname !== nothing
        # island generation may have set synthetic initials in the workspace —
        # re-snapshot so the exported initial state matches the widgets
        original_state = Pluto.notebook_to_js(notebook)
        delete!(original_state, "status_tree")
    end

    Pluto.SessionActions.shutdown(session, notebook; async=false)
    own_session && @async nothing  # session owns no server; nothing to stop

    # write export files (Pluto.generate_html — same output as PSS / the
    # in-Pluto export button)
    export_html_path = joinpath(output_dir, name * ".html")
    if therapy
        # lean Therapy-style export: SSR the cells + drive the wasm islands from
        # plain HTML inputs (no Pluto frontend, no 2.6 MB baked statefile).
        write(export_html_path, generate_therapy_html(notebook, output_dir, name, islands_dirname; theme_picker))
        # native-inline component fragment (no iframe): same SSR cells + islands, but
        # CSS @scope-isolated and asset URLs = the `assets_base` placeholder the host
        # rewrites. One notebook run → both the standalone page and the embeddable.
        if fragment
            frag_path = joinpath(output_dir, name * ".fragment.html")
            write(frag_path, generate_therapy_html(notebook, output_dir, name, islands_dirname;
                theme_picker=false, fragment=true, assets_base))
        end
        return export_html_path
    end
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

"""
    generate_therapy_html(notebook, output_dir, name, islands_dirname) -> String

Lean export: SSR every cell to plain HTML, render reactive (island) cells as
`#out-<id>` mount points, and load the island shim + a tiny wiring script that
drives `window.__pi_renderAll` from any `<bond def>` input. No Pluto frontend, no
2.6 MB baked statefile — the wasm islands regenerate every reactive cell in-browser.
"""
function generate_therapy_html(notebook, output_dir::AbstractString, name::AbstractString,
                               islands_dirname::Union{Nothing,AbstractString};
                               theme_picker::Bool=true,
                               fragment::Bool=false,
                               assets_base::AbstractString="")
    # which cells are reactive island cells? (their output is regenerated by wasm)
    island_cell_ids = Set{String}()
    if islands_dirname !== nothing
        mpath = joinpath(output_dir, islands_dirname, "islands.json")
        if isfile(mpath)
            man = JSON.parsefile(mpath)
            for g in get(man, "groups", Any[]), c in get(g, "cells", Any[])
                push!(island_cell_ids, string(c["id"]))
            end
        end
    end
    # ── Pluto-faithful per-cell rendering: THREE visibility states Pluto encodes ──
    #   • code SHOWN  (code_folded=false, non-markdown) → syntax-highlighted code
    #     block (.pl-code) ABOVE the output, so e.g. `f` makes sense as the output
    #     of `function f(…)`.
    #   • code HIDDEN (code_folded=true)               → output only; the code is
    #     truly ABSENT from the DOM (= Therapy Show(false) for a static export).
    #   • markdown cells (`md"…"`)                     → rendered prose, never the
    #     `md"…"` source, regardless of fold state.
    #   • output SUPPRESSED (trailing `;`)             → empty body → no output div.
    _esc(s) = replace(replace(replace(s, "&" => "&amp;"), "<" => "&lt;"), ">" => "&gt;")
    _is_md(c) = (cc = lstrip(c); startswith(cc, "md\"") || startswith(cc, "@md") || startswith(cc, "Markdown."))
    # Pluto tree+object body (a Dict) → the same <pluto-tree>/<p-r>/<p-k>/<p-v> DOM
    # the shim emits, so the ported treeview.css styles it 1-1. Mirrors shim.js
    # tree_to_html: containers collapse to `[v1, v2, …]`, scalars are their text repr.
    # `budget` caps total rendered nodes (Pluto's treeview truncates large structures
    # too); leaf strings are length-capped. Keeps a baked array/matrix preview small
    # instead of inlining the whole thing.
    function _tree_html(b, budget=Ref(120))
        b isa AbstractString && return _esc(first(b, 4000))
        if b isa AbstractDict && haskey(b, :elements)
            kind = _esc(string(get(b, :type, "Array")))
            els = b[:elements]; io2 = IOBuffer(); shown = 0
            for el in els
                budget[] -= 1
                if budget[] <= 0
                    print(io2, "<p-r><p-k></p-k><p-v>… ", length(els) - shown, " more</p-v></p-r>")
                    break
                end
                shown += 1
                tup = el isa Tuple || el isa AbstractVector
                k = tup && length(el) >= 1 ? el[1] : ""
                inner = tup && length(el) >= 2 ? el[2] : el
                cbody = (inner isa Tuple || inner isa AbstractVector) && length(inner) >= 1 ? inner[1] : inner
                print(io2, "<p-r><p-k>", _esc(string(k)), "</p-k><p-v>", _tree_html(cbody, budget), "</p-v></p-r>")
            end
            return string("<pluto-tree class=\"collapsed ", kind, "\"><pluto-tree-prefix></pluto-tree-prefix><pluto-tree-items class=\"", kind, "\">", String(take!(io2)), "</pluto-tree-items></pluto-tree>")
        end
        return _esc(first(string(b), 4000))
    end
    has_toc = false
    cells_io = IOBuffer()
    for id in notebook.cell_order
        cell = get(notebook.cells_dict, id, nothing)
        cell === nothing && continue
        cid = string(id)
        code = cell.code
        folded = cell.code_folded
        body = cell.output.body
        bodystr = body isa AbstractString ? body : ""
        # Pluto runs each cell <script> in an ISOLATED scope with `currentScript` (the
        # script element) and `invalidation` (a cleanup promise) bound as locals. Our
        # lean export would otherwise run them as plain GLOBAL inline scripts → top-level
        # `const input_el = …` collides across cells ("already declared") and bare
        # `currentScript`/`invalidation` are undefined. Wrap each inline output <script>
        # in an IIFE binding those, mimicking Pluto's runner — fixes e.g. Slider
        # show_value (its script wires the input to update the displayed <output>).
        bodystr = replace(bodystr, r"<script>(.*?)</script>"s => function (whole)
            inner = match(r"<script>(.*?)</script>"s, whole).captures[1]
            # capture currentScript DURING parse (valid only then), but DEFER the body to
            # DOMContentLoaded — at parse time the script's following siblings (e.g. the
            # Slider's <output>) aren't in the DOM yet, so currentScript.nextElementSibling
            # would be null. Wrapping the body in __run() also makes top-level `return`s legal.
            string("<script>(function(){",
                "const currentScript=document.currentScript;",
                "const invalidation=new Promise(function(){});",
                "const __run=function(){\n", inner, "\n};",
                "document.readyState===\"loading\"?document.addEventListener(\"DOMContentLoaded\",__run):__run();",
                "})();</script>")
        end)
        # PlutoUI.TableOfContents needs Pluto's own DOM — skip its (non-functional)
        # widget output and render a lean aside ToC in the shell instead.
        if occursin("TableOfContents", code)
            has_toc = true
            continue
        end
        is_island = cid in island_cell_ids
        show_code = !folded && !_is_md(code) && !isempty(strip(code))
        # Pluto's captured output, baked 1-1 at BASE level: a string body as-is; a
        # tree+object body (Vector/Tuple/struct) → Pluto's own <pluto-tree> DOM. An
        # island REPLACES this on a successful wasm render; if that render throws, the
        # shim drops a loud !!! warning here — the captured value is ALWAYS shown, never
        # a blank. Empty body = Pluto suppressed it (trailing `;`) → no output div.
        baked = body isa AbstractString ? bodystr : _tree_html(body)
        # an island RE-RENDERS its output, so baking a LARGE captured body (a big
        # array tree, a base64 image) would only bloat the page as a redundant
        # fallback — keep the base layer only when it's small (tuples, numbers,
        # short values); large outputs rely on the island (+ the loud warning on fail).
        is_island && length(baked) > 8192 && (baked = "")
        has_out = is_island || !isempty(strip(baked))
        (show_code || has_out) || continue
        print(cells_io, "<div class=\"pl-cell\">")
        # Pluto order: OUTPUT on top, code BELOW it, wrapped in <pluto-output> so the
        # ported Pluto output CSS (editor.css + treeview.css) applies 1-1.
        # every mount gets id="out-<cid>" so the shim can find it — islands to
        # re-render, and FALLBACK cells (bond group that couldn't compile) to receive
        # the loud !!! warning. (Was island-only, so fallback cells got no warning.)
        if is_island
            print(cells_io, "<pluto-output class=\"rich_output\" id=\"out-", cid, "\">", baked, "</pluto-output>")
        elseif !isempty(strip(baked))
            print(cells_io, "<pluto-output class=\"rich_output\" id=\"out-", cid, "\">", baked, "</pluto-output>")
        end
        show_code && print(cells_io,
            "<pre class=\"pl-code\"><code class=\"pl-jl\">", _esc(code), "</code></pre>")
        println(cells_io, "</div>")
    end
    cells_html = String(take!(cells_io))
    # ─── Table of Contents — a ~1-1 port of PlutoUI.TableOfContents(aside=true) ───
    # Same DOM (`nav.plutoui-toc.aside.indent` > header[toggle×2 + title] + section),
    # same CSS (auto-derived into pluto-base.css → PLUTO_OUTPUT_CSS, re-themed to
    # DaisyUI tokens), and a faithful-but-vanilla port of PlutoUI's toc_js: depth-3
    # heading scan with after-H* nesting, click-toggle collapse, smooth-scroll on row
    # click, scroll-spy via two IntersectionObservers (the "on top half of viewport"
    # highlight rule from PlutoUI), and the small-screen auto-hide. `data-embedded`
    # tells the CSS/JS this instance lives inside the docs column (vs a standalone
    # page) so it positions sensibly and starts collapsed instead of floating over
    # the docs chrome. Renders only when the notebook used PlutoUI.TableOfContents.
    #
    # NOTE: kept dependency-free (native scrollIntoView, no smooth-scroll-into-view
    # lib) and resilient to our reactive island re-renders (a MutationObserver +
    # delayed rebuilds repopulate the rows once cell output mounts).
    toc_html = has_toc ? (embedded -> string(
        "<nav class=\"plutoui-toc aside indent",
        embedded ? " toc-embedded\" data-embedded=\"1\">" : "\">",
        raw"""
  <header>
    <span class="toc-toggle open-toc"></span>
    <span class="toc-toggle closed-toc"></span>
    <span>Table of Contents</span>
  </header>
  <section></section>
</nav>
<script>
(function () {
  function init() {
    var navs = document.querySelectorAll(".plutoui-toc");
    if (!navs.length) return;
    navs.forEach(function (nav) {
      if (nav.__pl_toc_init) return; nav.__pl_toc_init = true;
      var section = nav.querySelector("section");
      var embedded = nav.hasAttribute("data-embedded");
      // the notebook root this ToC belongs to (its nearest .snap-notebook, else <main>,
      // else the document) — keeps the heading scan scoped in BOTH contexts.
      var root = (nav.closest && nav.closest(".snap-notebook")) || document.querySelector("main") || document;
      var DEPTH = 3; // PlutoUI default
      var headById = {};

      function headerSelector() {
        var sel = [];
        for (var i = 1; i <= DEPTH; i++) { sel.push("pluto-output h" + i); }
        return sel.join(",");
      }
      function getHeaders() {
        return Array.prototype.filter.call(root.querySelectorAll(headerSelector()),
          function (el) { return !el.classList.contains("no-toc"); });
      }

      // ── scroll-spy: PlutoUI's two-observer "topmost header in upper half" rule ──
      var highlighted = new Set();
      var lastClickTime = { current: 0 };
      function intersectionCallback(ixs) {
        var onTop = ixs.filter(function (ix) {
          return ix.intersectionRatio > 0 && ix.intersectionRect.y < ix.rootBounds.height / 2;
        });
        if (onTop.length > 0) {
          highlighted.forEach(function (a) { a.classList.remove("in-view"); });
          highlighted.clear();
          onTop.slice(0, 1).forEach(function (i) {
            var div = headById[i.target.id]; if (!div) return;
            div.classList.add("in-view"); highlighted.add(div);
          });
        }
      }
      var io1 = "IntersectionObserver" in window
        ? new IntersectionObserver(intersectionCallback, { root: null, threshold: 1, rootMargin: "-15px" }) : null;
      var io2 = "IntersectionObserver" in window
        ? new IntersectionObserver(intersectionCallback, { root: null, threshold: 1, rootMargin: "15px" }) : null;

      // skip rebuilds when the heading set hasn't changed (the heading texts as a
      // fingerprint) — without this the MutationObserver + island re-renders would
      // thrash `render()` in a loop (replaceChildren mutates the DOM → observer → …).
      var lastSig = null;
      function render() {
        var heads = getHeaders();
        var sig = heads.map(function (h) { return h.tagName + ":" + h.innerText; }).join("|");
        if (sig === lastSig) return; // nothing changed → don't touch the DOM
        lastSig = sig;
        headById = {}; highlighted.clear();
        io1 && io1.disconnect(); io2 && io2.disconnect();
        var frag = document.createDocumentFragment();
        var last = "H1";
        heads.forEach(function (h, i) {
          if (!h.id) h.id = "toc-h-" + i;
          var lvl = h.tagName; // H1..H6
          var a = document.createElement("a");
          a.className = lvl; a.href = "#" + h.id; a.title = h.innerText;
          a.textContent = h.innerText;
          a.addEventListener("click", function (e) {
            e.preventDefault();
            try { history.replaceState(null, "", a.getAttribute("href")); } catch (_) {}
            lastClickTime.current = Date.now();
            h.scrollIntoView({ behavior: "smooth", block: "start" });
          });
          var row = document.createElement("div");
          row.className = "toc-row " + lvl + " after-" + last;
          row.appendChild(a);
          frag.appendChild(row);
          headById[h.id] = row;
          io1 && io1.observe(h); io2 && io2.observe(h);
          last = lvl;
        });
        section.replaceChildren(frag);
      }

      // toggle collapse on the header icons (PlutoUI: any click within a .toc-toggle)
      nav.addEventListener("click", function (e) {
        var t = e.target.closest && e.target.closest(".toc-toggle");
        if (t) { e.stopImmediatePropagation(); nav.classList.toggle("hide"); }
      });

      // small-screen auto-hide (PlutoUI thresholds). Embedded ToCs ALSO start hidden
      // so they never float over docs content at rest — hover/click the edge strip.
      function matchListener() {
        var w = (embedded && root.getBoundingClientRect ? root.getBoundingClientRect().width
                 : (document.documentElement.scrollWidth || window.innerWidth));
        var small = w < 1000;
        nav.classList.toggle("smallscreen", small);
        if (!nav.__pl_user_toggled) nav.classList.toggle("hide", small || embedded);
      }
      nav.querySelectorAll(".toc-toggle").forEach(function (t) {
        t.addEventListener("click", function () { nav.__pl_user_toggled = true; });
      });
      ["resize"].forEach(function (ev) { window.addEventListener(ev, matchListener); });

      render();
      // reactive islands mount their output after first paint — rebuild a few times
      [100, 1000, 3000].forEach(function (ms) { setTimeout(render, ms); });
      // and watch the CELLS container for structural changes (island re-renders add
      // output). We observe the cells area, NOT the nav — observing the whole `root`
      // (which CONTAINS this nav) would let our own section.replaceChildren() retrigger
      // the observer in a tight loop. A debounce + the heading fingerprint above are a
      // second safety net. The IntersectionObserver-only scroll-spy doesn't need this.
      var cellsArea = (root.querySelector && root.querySelector(".snap-cells")) ||
                      (root.querySelector && root.querySelector("main")) ||
                      (root === document ? null : root);
      if ("MutationObserver" in window && cellsArea && !cellsArea.contains(nav)) {
        var deb = null;
        new MutationObserver(function () {
          clearTimeout(deb); deb = setTimeout(render, 200);
        }).observe(cellsArea, { childList: true, subtree: true });
      }
      matchListener();
    });
  }
  document.readyState === "loading"
    ? document.addEventListener("DOMContentLoaded", init) : init();
})();
</script>
""")) : (_ -> "")
    shim_tag = islands_dirname === nothing ? "" :
        string("<script src=\"", islands_dirname, "/shim.js\"></script>")
    wiring = raw"""
<script>
(function () {
  function collectBonds() {
    const vals = {};
    document.querySelectorAll("bond[def]").forEach(function (b) {
      const inp = b.querySelector("input,select,textarea");
      if (!inp) return;
      const t = inp.type;
      // Match the shim's value_tree contract per input type: numbers as Number,
      // checkbox as Boolean, and date/time inputs as the {__pluto_date_ms: epochMs}
      // marker the shim decodes into a Julia DateTime (the staterequest path sends
      // valueAsDate → msgpack Date ext → the same marker). Passing the raw string
      // here would make value_tree treat the DateTime struct's value as undefined.
      let v;
      if (t === "range" || t === "number") v = Number(inp.value);
      else if (t === "checkbox") v = inp.checked;
      else if (t === "date" || t === "datetime-local" || t === "month" || t === "week" || t === "time")
        v = Number.isNaN(inp.valueAsNumber) ? undefined : { __pluto_date_ms: inp.valueAsNumber };
      else v = inp.value;
      vals[b.getAttribute("def")] = v;
    });
    return vals;
  }
  async function rerender() {
    if (window.__pi_renderAll) { try { await window.__pi_renderAll(collectBonds()); } catch (e) { console.warn(e); } }
  }
  document.addEventListener("input", function (e) {
    if (e.target.closest && e.target.closest("bond[def]")) rerender();
  });
  (function wait() { window.__pi_renderAll ? rerender() : setTimeout(wait, 50); })();
})();
</script>
"""
    # Pluto-faithful math: KaTeX 0.11.1 (same version Pluto ships) rendering every
    # `.tex` element — inline `<span class="tex">$…$</span>` AND display
    # `<p class="tex">$$…$$</p>`. Re-runs after reactive re-renders via a
    # MutationObserver (the dataset.r guard prevents re-processing / loops).
    katex_js = raw"""
<script>
(function () {
  function render(root) { (root || document).querySelectorAll(".tex").forEach(function (s) {
    if (s.dataset.r) return;
    var t = s.textContent.trim();
    var disp = t.indexOf("$$") === 0;
    t = t.replace(/^\$\$?/, "").replace(/\$\$?$/, "");
    try { katex.render(t, s, { displayMode: disp, throwOnError: false }); s.dataset.r = "1"; } catch (e) {}
  }); }
  (function wait() { window.katex ? render() : setTimeout(wait, 80); })();
  new MutationObserver(function () { window.katex && render(); }).observe(document.body, { childList: true, subtree: true });
})();
</script>
"""
    # Julia syntax highlighting for shown code cells, using the SAME Lezer-Julia parser
    # Pluto highlights with (@plutojl/lezer-julia + @lezer/highlight) loaded client-side
    # as ES modules. Walks the parse tree, wraps tokens in tok-* spans (styled above).
    # Degrades gracefully to plain (escaped) code if the modules fail to load.
    hl_js = raw"""
<script type="module">
import { parser } from "https://esm.sh/@plutojl/lezer-julia@1";
import { highlightTree, classHighlighter } from "https://esm.sh/@lezer/highlight@1";
const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
function hl(code) {
  const tree = parser.parse(code); let out = "", pos = 0;
  highlightTree(tree, classHighlighter, (from, to, cls) => {
    if (from > pos) out += esc(code.slice(pos, from));
    out += '<span class="' + cls + '">' + esc(code.slice(from, to)) + '</span>'; pos = to;
  });
  out += esc(code.slice(pos)); return out;
}
document.querySelectorAll("code.pl-jl").forEach(el => {
  try { el.innerHTML = hl(el.textContent); } catch (e) { console.warn("pl-hl", e); }
});
</script>
"""
    # Layer-2 styling: DEFAULT to DaisyUI — the SAME design language as the snapshot
    # dashboard + collection shells (data-theme + daisyui@5/themes.css + per-theme
    # --color-* tokens). One `data-theme` swap reskins chrome AND the notebook's Pluto
    # cells together; the Worker can override data-theme at serve time (zero rebuild).
    # Pluto's standard pieces map to NAMED, token-themed components (admonition→pl-alert,
    # code→pl-code, table→pl-table) — pretty by default + instantly theme-swappable.
    dui_css = raw"""
:root{--pl-muted:color-mix(in oklab,var(--color-base-content) 60%,transparent)}
body{font-family:var(--system-ui-font-stack,ui-sans-serif,system-ui,-apple-system,'Segoe UI',sans-serif);max-width:768px;margin:0 auto;padding:2rem 1rem;line-height:1.65;color:var(--color-base-content);background:var(--color-base-100)}
/* Pluto's tree/table/code use white-space:pre (no wrap); the output box must
   scroll horizontally so wide content (long arrays, wide tables, long inline
   math) stays inside the cell column instead of bleeding off-page — exactly
   how Pluto's own cell output behaves. */
pluto-output{display:block;overflow-x:auto;overflow-y:visible}
.cell{margin:1.1rem 0}
img.wasmmakie-island,.snap-reactive canvas{max-width:100%;height:auto}
input[type=range]{accent-color:var(--color-primary);width:15rem;vertical-align:middle}
select,input[type=number]{accent-color:var(--color-primary)}
bond{display:inline-block}
a{color:var(--color-primary)}
/* floating DaisyUI theme picker (test control): swaps <html data-theme>; because the
   ported Pluto output CSS reads DaisyUI --color-* tokens, ONE swap restyles every cell */
.snap-theme-picker{position:fixed;top:.75rem;left:.75rem;z-index:50;display:flex;align-items:center;gap:.4rem;background:var(--color-base-200);color:var(--color-base-content);border:1px solid var(--color-base-300);border-radius:.6rem;padding:.35rem .55rem;box-shadow:0 1px 4px rgba(0,0,0,.14);font-size:.8rem;line-height:1}
.snap-theme-picker select{background:var(--color-base-100);color:var(--color-base-content);border:1px solid var(--color-base-300);border-radius:.4rem;padding:.25rem .45rem;font-size:.8rem;font-family:inherit;cursor:pointer}
/* shown-code blocks = OUR Lezer-highlighted SOURCE, sit BELOW the cell's pluto-output
   (Pluto's own output CSS owns everything INSIDE pluto-output; this is the code listing) */
.pl-cell{margin:1.25rem 0}
.pl-code{background:var(--color-base-200);border-radius:.4rem;padding:.5rem .75rem;overflow-x:auto;max-width:100%;font-size:.8em;line-height:1.5;margin:.4rem 0 0}
.pl-code code{background:none;padding:0;font-size:1em;white-space:pre;font-family:var(--julia-mono-font-stack,ui-monospace,Menlo,monospace)}
/* keep wide cell content inside the notebook column (don't blow out the page):
   long code lines scroll within their block; PlutoUI multi-slider rows wrap;
   widgets/markdown never exceed the column; anything still wide scrolls in-cell.
   NOTE: these are intentionally UNPREFIXED. The standalone page has NO .snap-notebook
   wrapper (it uses <main>), and in the docs fragment the whole sheet is wrapped in
   `@scope (.snap-notebook)` — so a `.snap-notebook X` selector matched NOTHING in either
   context (the earlier 272px residual). Bare class/element selectors auto-scope under
   @scope for the fragment and stay notebook-specific (these are Pluto/PlutoUI classes)
   for the standalone page. */
pre,table,bond,.markdown,img{max-width:100%}
.slider_group_inner,.slider_group,.on_small_show,.on_big_show{flex-wrap:wrap !important;max-width:100% !important}
/* PlutoUI/combine `sidebar-left|right` parks slider columns in the PAGE MARGIN via
   `position:absolute; left:100%` (Pluto's full-width editor has room); in our narrow
   embedded column that flings them past the right edge by their own ~17rem width (the
   272px page overflow + sliders in the gutter). Flow them inline instead — `position:
   static` also neutralises the left/right/top:100% offsets (they only apply to
   positioned boxes). `.aside` is PlutoUI.combine's own margin-aside variant. */
.sidebar-left,.sidebar-right,.sidebar-bottom,.slider_group.aside{position:static !important;left:auto !important;right:auto !important;top:auto !important;width:auto !important}
/* PlutoUI.aside() (margin notes / admonitions in the gutter) does the SAME trick via
   an inline cell <style>: `aside.plutoui-aside-wrapper{position:absolute;right:-11px;
   width:0}` + `> div{width:300px}` — a zero-width anchor whose 300px child spills past
   the right edge (the fractals / PlutoUI.jl 312px overflow). Flow the note inline in
   our narrow column instead: static anchor, and the child caps at the column width. */
.plutoui-aside-wrapper{position:static !important;right:auto !important;left:auto !important;width:auto !important}
.plutoui-aside-wrapper>div{width:auto !important;max-width:100% !important}
/* safety net: anything STILL wider than the column scrolls within the notebook column
   rather than pushing the page layout out (e.g. a stray fixed-width figure). */
.snap-cells,main{overflow-x:auto}
/* Lezer-Julia token highlight (classHighlighter tok-* classes), DaisyUI-aware */
.tok-keyword,.tok-controlKeyword,.tok-definitionKeyword,.tok-moduleKeyword,.tok-operatorKeyword{color:#8b5cf6}
.tok-comment,.tok-lineComment,.tok-blockComment{color:var(--pl-muted);font-style:italic}
.tok-string,.tok-character,.tok-special{color:#16a34a}
.tok-number,.tok-integer,.tok-float,.tok-bool,.tok-atom,.tok-constant{color:#d97706}
.tok-typeName{color:#0891b2}
.tok-macroName{color:#db2777}
.tok-function,.tok-definition{color:#2563eb}
.tok-operator,.tok-arithmeticOperator,.tok-compareOperator,.tok-logicOperator,.tok-derefOperator,.tok-typeOperator{color:var(--color-base-content);opacity:.8}
/* ── EMBEDDED ToC (docs): keep Pluto's floating aside, but make it respect the docs
   chrome. It stays a fixed top-right panel (like Pluto) so it never disturbs the
   notebook column's flow — but sits BELOW the docs sticky header (lower z-index +
   a little lower) and, crucially, the collapsed `.hide` state slides flush to the
   right viewport edge (translateX to right:0) instead of PAST it, so it can never
   add a horizontal scrollbar. It starts collapsed (the JS adds .hide) so it reads
   as a tidy tab the reader opens, never floating over docs text at rest. */
.plutoui-toc.toc-embedded.aside{z-index:30;top:4.5rem;right:0;max-height:calc(100vh - 6rem);box-shadow:0 2px 14px rgba(0,0,0,.10)}
.plutoui-toc.toc-embedded.aside.hide{transform:translateX(calc(100% - 28px))}
"""
    # Pluto's OWN output CSS (editor.css pluto-output rules + treeview.css) and
    # PlutoUI's TableOfContents CSS, copied VERBATIM and re-themed only by the
    # variable map at the top of the file → output.body renders exactly as Pluto
    # does, in whatever DaisyUI theme is active (Worker can swap it). The custom
    # classic-light/classic-dark token blocks ship inline (CDN themes.css only
    # has the built-ins).
    pluto_css = string(CLASSIC_THEMES_CSS, "\n", PLUTO_OUTPUT_CSS)
    # Pluto trees are click-to-expand/collapse — wire the same toggle on the caret.
    tree_js = raw"""
<script>
document.addEventListener("click", function (e) {
  if (!e.target.closest) return;
  var pre = e.target.closest("pluto-tree > pluto-tree-prefix");
  if (pre && pre.parentElement) pre.parentElement.classList.toggle("collapsed");
});
</script>
"""
    # Floating theme picker (TEST control). Sets <html data-theme>; the ported Pluto
    # CSS reads DaisyUI --color-* tokens so one swap restyles the WHOLE notebook.
    # classic-light/classic-dark are our custom themes (1:1 Pluto palettes, tokens
    # inlined via CLASSIC_THEMES_CSS); the rest are DaisyUI 5 built-ins (themes.css
    # is already loaded in <head>). Choice persists in localStorage.
    # Standalone pages render it; embedded-in-a-host (docs) pass theme_picker=false
    # so the HOST app's single picker drives every notebook (same-origin iframe).
    picker_block = theme_picker ? raw"""
<div class="snap-theme-picker">
  <span aria-hidden="true">🎨</span>
  <select id="snap-theme-select" aria-label="Theme" onchange="__piSetTheme(this.value)">
    <optgroup label="Snapshot classic (Pluto palette)">
      <option value="classic-light">classic-light</option>
      <option value="classic-dark">classic-dark</option>
    </optgroup>
    <optgroup label="DaisyUI">
      <option value="light">light</option>
      <option value="dark">dark</option>
      <option value="cupcake">cupcake</option>
      <option value="bumblebee">bumblebee</option>
      <option value="emerald">emerald</option>
      <option value="corporate">corporate</option>
      <option value="synthwave">synthwave</option>
      <option value="retro">retro</option>
      <option value="cyberpunk">cyberpunk</option>
      <option value="valentine">valentine</option>
      <option value="halloween">halloween</option>
      <option value="garden">garden</option>
      <option value="forest">forest</option>
      <option value="aqua">aqua</option>
      <option value="lofi">lofi</option>
      <option value="pastel">pastel</option>
      <option value="fantasy">fantasy</option>
      <option value="wireframe">wireframe</option>
      <option value="black">black</option>
      <option value="luxury">luxury</option>
      <option value="dracula">dracula</option>
      <option value="cmyk">cmyk</option>
      <option value="autumn">autumn</option>
      <option value="business">business</option>
      <option value="acid">acid</option>
      <option value="lemonade">lemonade</option>
      <option value="night">night</option>
      <option value="coffee">coffee</option>
      <option value="winter">winter</option>
      <option value="dim">dim</option>
      <option value="nord">nord</option>
      <option value="sunset">sunset</option>
    </optgroup>
  </select>
</div>
<script>
function __piSetTheme(t){document.documentElement.setAttribute('data-theme',t);try{localStorage.setItem('snap-theme',t);}catch(e){}}
(function(){var sel=document.getElementById('snap-theme-select');if(sel)sel.value=document.documentElement.getAttribute('data-theme')||'light';})();
</script>
""" : ""
    if fragment
        # NATIVE INLINE COMPONENT: a self-contained <div class="snap-notebook"> with
        # @scope-isolated CSS (no leakage to/from the host app), the SSR cells, and
        # the island shim/wiring. The docs serve these via a FULL page load (links
        # carry data-no-router) so every script runs fresh — same as the standalone
        # page the harness proves reactive. assets_base makes the shim src absolute
        # & base-aware (a placeholder the host rewrites per base_path).
        scoped = replace(string(dui_css, "\n", pluto_css), "\nbody{" => "\n:scope{")
        scoped = replace(scoped, ":root{" => ":scope{")
        # the notebook inherits the host's DaisyUI theme; flow transparently into the
        # page (no card/box bg) so it reads as native content, not an embed.
        scoped = string(scoped, "\n:scope{background:transparent;max-width:none;padding:0;margin:0}")
        frag_css = string("@scope (.snap-notebook) {\n", scoped, "\n}")
        frag_shim = islands_dirname === nothing ? "" :
            string("<script src=\"", assets_base, "/", islands_dirname, "/shim.js\"></script>")
        # apply the host picker's saved theme to THIS notebook on load
        theme_apply = string("<script>(function(){try{var t=localStorage.getItem('snap-theme');",
            "if(t){var s=document.currentScript;var n=s&&s.closest?s.closest('.snap-notebook'):null;",
            "if(n)n.setAttribute('data-theme',t);}}catch(e){}})();</script>")
        # the EMBEDDED ToC lives INSIDE .snap-notebook so the @scope'd Pluto ToC CSS
        # styles it; data-embedded makes it position sensibly + start collapsed.
        return string(
            "<div class=\"snap-notebook\">\n",
            "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/daisyui@5/themes.css\">\n",
            "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@0.11.1/dist/katex.min.css\">\n",
            "<script defer src=\"https://cdn.jsdelivr.net/npm/katex@0.11.1/dist/katex.min.js\"></script>\n",
            "<style>\n", frag_css, "\n</style>\n",
            theme_apply, "\n",
            toc_html(true), "\n",
            "<div class=\"snap-cells\">\n", cells_html, "</div>\n",
            frag_shim, "\n", wiring, "\n", katex_js, "\n", hl_js, "\n", tree_js, "\n",
            "</div>\n",
        )
    end
    return string(
        "<!DOCTYPE html>\n<html lang=\"en\" data-theme=\"light\">\n<head>\n<meta charset=\"utf-8\">\n",
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
        "<script>(function(){try{var t=localStorage.getItem('snap-theme');if(t)document.documentElement.setAttribute('data-theme',t);}catch(e){}})();</script>\n",
        "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/daisyui@5/themes.css\">\n",
        "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@0.11.1/dist/katex.min.css\">\n",
        "<script defer src=\"https://cdn.jsdelivr.net/npm/katex@0.11.1/dist/katex.min.js\"></script>\n",
        "<title>", name, "</title>\n<style>\n", dui_css, "\n", pluto_css,
        "</style>\n</head>\n<body>\n", picker_block, "\n", toc_html(false), "<main>\n", cells_html, "</main>\n",
        shim_tag, "\n", wiring, "\n", katex_js, "\n", hl_js, "\n", tree_js, "\n</body>\n</html>\n",
    )
end
