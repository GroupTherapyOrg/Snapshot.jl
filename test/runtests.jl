# Snapshot test suite — extraction, compilation, oracle, judgement, and
# (when node is available) the full export. One process, one warmup.

using Test
import Pluto
import JSON
import Pkg
using Snapshot

const HAS_NODE = Sys.which("node") !== nothing

@testset "registry package contract" begin
    root = dirname(@__DIR__)
    project = Pkg.TOML.parsefile(joinpath(root, "Project.toml"))
    docs_project = Pkg.TOML.parsefile(joinpath(root, "docs", "Project.toml"))
    @test !haskey(project, "sources")
    @test project["compat"]["WasmTarget"] == "0.5.2"
    @test !haskey(docs_project, "sources")
    @test docs_project["compat"]["Therapy"] == "0.2.3"
end

@testset "fun export theme contract" begin
    root = dirname(@__DIR__)
    themes = read(joinpath(root, "assets", "classic-themes.css"), String)
    exporter = read(joinpath(root, "src", "exporter.jl"), String)
    @test occursin(":root[data-theme=\"fun-light\"]", themes)
    @test occursin(":root[data-theme=\"fun-dark\"]", themes)
    @test occursin("fun-light", exporter)
    @test occursin("<option value=\"fun-light\">", exporter)
    @test occursin("<option value=\"fun-dark\">", exporter)
end

@testset "featured notebook coverage gate" begin
    root = dirname(@__DIR__)
    verifier = joinpath(root, "docs", "verify_notebook_coverage.py")
    @test isfile(verifier)
    @test success(`python3 $verifier $(joinpath(root, "docs", "notebooks-static", "index.json"))`)
    workflow = read(joinpath(root, ".github", "workflows", "docs.yml"), String)
    @test occursin("python3 docs/verify_notebook_coverage.py", workflow)
    @test occursin("committed_exports", workflow)
    @test occursin("inputs.committed_exports", workflow)
    @test occursin("needs.build.result == 'success'", workflow)
    exporter = read(joinpath(root, "src", "exporter.jl"), String)
    @test occursin("t === \"button\"", exporter)
    @test occursin("b.firstElementChild", exporter)
    @test occursin("setTimeout(rerender, 0)", exporter)
    # Lean pages must preserve Pluto's inline-widget execution scope and marshal
    # a combine() bond's multiple child inputs as one ordered value.
    @test occursin("const __run=async function()", exporter)
    @test occursin("const Generators=window.Generators", exporter)
    @test occursin("holder && !holderIsInput && holder.value !== undefined", exporter)
    @test occursin("inp.type !== \"submit\" && inp.type !== \"reset\"", exporter)
    @test occursin("valueInputs.map(inputValue)", exporter)
    @test occursin("addEventListener(\"input\"", exporter)
    @test occursin("}, true);", exporter)
end

@testset "single final wasm assembly path" begin
    compiler_source = read(joinpath(dirname(@__DIR__), "src", "compile.jl"), String)
    # One import-aware canvas admission probe and one final assembly call.
    @test length(collect(eachmatch(r"WasmTarget\.compile_multi\b", compiler_source))) == 2
    # compile_group Core.eval's fresh functions/imported bindings. Julia 1.12
    # requires every Wasm compiler entry to cross that world-age boundary.
    @test length(collect(eachmatch(
        r"Base\.invokelatest\(WasmTarget\.compile", compiler_source))) == 3
    @test occursin("pushfirst!(LOAD_PATH, env_dir)", compiler_source)
    @test !occursin("Pkg.activate", compiler_source)
    @test !occursin("WasmTarget.compile_module(", compiler_source)
    @test !occursin("WasmTarget.to_bytes(", compiler_source)
    @test !occursin("WasmTarget.optimize(", compiler_source)
end

const DEMO = joinpath(@__DIR__, "notebooks", "demo.jl")          # slider → x^2 → md
const TWO_GROUPS = joinpath(@__DIR__, "notebooks", "two_groups.jl")  # island group + fallback group
const ERROR_OUTPUT = joinpath(@__DIR__, "notebooks", "error_output.jl")

session = Pluto.ServerSession()
session.options.evaluation.workspace_use_distributed = false

@testset "lean error output is concise" begin
    errored = Pluto.SessionActions.open(session, ERROR_OUTPUT; run_async=false)
    html = Snapshot.generate_therapy_html(errored, mktempdir(), "error_output", nothing)
    @test occursin("Notebook cell failed", html)
    @test occursin("short public message", html)
    @test occursin("&lt;script&gt;alert(1)&lt;/script&gt;&amp;", html)
    @test !occursin("<script>alert(1)</script>", html)
    @test !occursin(":stacktrace", lowercase(html))
    @test !occursin("Base_compiler.jl", html)
    @test !occursin("error_output.jl#", html)
    Pluto.SessionActions.shutdown(session, errored; async=false)
end

@testset "import binding syntax" begin
    parsed_import = Snapshot._parse_cell(Pluto.Cell("""import Base as B
    # An ordinary trailing comment is still part of a valid Pluto cell.
    """))
    @test parsed_import isa Expr
    @test parsed_import.head === :toplevel
    @test Snapshot._parse_cell(Pluto.Cell("x = 1\ny = x + 1")) isa Expr
    @test Snapshot._parse_cell(Pluto.Cell("x =")) === nothing

    explicit_names(src) = Snapshot._import_names(session, nothing, Meta.parse(src))
    @test explicit_names("using Foo: x, y") == Set([:x, :y])
    @test explicit_names("import Foo: x") == Set([:x])
    @test explicit_names("import Foo: x as renamed") == Set([:renamed])
    @test explicit_names("using Foo: @widget") == Set([Symbol("@widget")])
    @test explicit_names("import Base: +") == Set([:+])
    @test explicit_names("using .Local: helper") == Set([:helper])
    @test explicit_names("import Foo.Bar") == Set([:Bar])
    @test explicit_names("import Foo as Alias") == Set([:Alias])

    unresolved = Set([:needed])
    successful_unknown = (names=Set{Symbol}(), direct_names=Set{Symbol}(),
        module_names=Set([:Foo]), analysis_ok=false,
        cell_succeeded=true, compiler_available=false,
        expr=Meta.parse("using Foo"))
    errored_unknown = (names=Set{Symbol}(), direct_names=Set{Symbol}(),
        module_names=Set([:Foo]), analysis_ok=false,
        cell_succeeded=false, compiler_available=false,
        expr=Meta.parse("using Foo"))
    @test Snapshot._import_relevant(successful_unknown, unresolved)
    @test !Snapshot._import_relevant(errored_unknown, unresolved)
    @test Snapshot._import_relevant(errored_unknown, Set([:Foo]))
    @test !Snapshot._import_relevant(successful_unknown, Set{Symbol}())

    direct_mean = (names=Set([:Statistics, :mean]),
        direct_names=Set([:Statistics, :mean]), module_names=Set([:Statistics]),
        analysis_ok=true, cell_succeeded=true, compiler_available=true,
        expr=Meta.parse("using Statistics"))
    reexported_mean = (names=Set([:PoisonReexport, :mean]),
        direct_names=Set([:PoisonReexport]), module_names=Set([:PoisonReexport]),
        analysis_ok=true, cell_succeeded=true, compiler_available=false,
        expr=Meta.parse("using PoisonReexport"))
    direct_providers = union(direct_mean.direct_names, reexported_mean.direct_names)
    @test Snapshot._import_relevant(direct_mean, Set([:mean]), direct_providers)
    @test !Snapshot._import_relevant(reexported_mean, Set([:mean]), direct_providers)
    @test Snapshot._import_relevant(merge(reexported_mean,
        (compiler_available=true,)), Set([:mean]), direct_providers)
end

# ─── demo notebook: extraction → compile → oracle ───────────────────────────
notebook = Pluto.SessionActions.open(session, DEMO; run_async=false)
original_state = Pluto.notebook_to_js(notebook)
connections = bound_variable_connections_graph(session, notebook)

@testset "embedded fragment inherits host theme" begin
    fragment_html = Snapshot.generate_therapy_html(notebook, mktempdir(),
        "demo", nothing; fragment=true)
    @test occursin("class=\"snap-notebook\"", fragment_html)
    @test !occursin("localStorage.getItem('snap-theme')", fragment_html)
end

@testset "extraction" begin
    groups = extract_groups(session, notebook; connections, original_state)
    @test length(groups) == 1
    g = groups[1]
    @test g.bond_names == [:x]
    @test g.arg_types == [Int64]
    @test g.initial_values == [1]
    @test length(g.cell_plans) == 2
    @test all(p -> p.ok, g.cell_plans)

    # native check: generated fns reproduce the original bodies
    sandbox = Module(:IslandSandbox)
    for p in g.cell_plans
        f = Core.eval(sandbox, p.fn_expr)
        @test Base.invokelatest(f, g.initial_values...) ==
              original_state["cell_results"][p.cell_id]["output"]["body"]
    end
end

@testset "closure-first import fallback" begin
    poison_path = joinpath(@__DIR__, "notebooks", "import_poison.jl")
    fixture_parent = joinpath(@__DIR__, "fixtures")
    pushfirst!(LOAD_PATH, fixture_parent)
    poison = try
        Pluto.SessionActions.open(session, poison_path; run_async=false)
    finally
        popfirst!(LOAD_PATH)
    end
    # Exact production failure shape: Pluto loaded the unrelated package, but
    # the fresh compiler environment cannot resolve it after LOAD_PATH returns
    # to Snapshot's own environment.
    fresh = Module(:PoisonFreshSandbox)
    @test_throws ArgumentError Core.eval(fresh, :(using SnapshotPoisonFixture))
    poison_state = Pluto.notebook_to_js(poison)
    poison_connections = bound_variable_connections_graph(session, poison)
    poison_group = only(extract_groups(session, poison;
        connections=poison_connections, original_state=poison_state))

    # An unrelated failed package cell must neither enter the island preamble
    # nor turn a healthy slider-dependent cell into a group-level failure.
    @test poison_group.ok
    @test all(p -> p.ok, poison_group.cell_plans)
    @test !any(ex -> occursin("SnapshotPoisonFixture", string(ex)),
               poison_group.preamble)
    poison_island = compile_group(poison_group; verify_node=false)
    @test poison_island.ok
    @test isempty(poison_island.cell_failures)

    poison_out = mktempdir()
    poison_assets = generate_wasm_islands(session, poison, poison_state;
        output_dir=poison_out, url_path="import_poison.jl", verify=false)
    @test poison_assets !== nothing
    poison_report = only(JSON.parsefile(joinpath(
        poison_out, "import_poison.islands", "report.json")))
    @test poison_report["judgement"] == "island"
    @test all(c -> c["ok"], poison_report["cells"])
    poison_coverage = JSON.parsefile(joinpath(
        poison_out, "import_poison.islands", "coverage.json"))
    @test poison_coverage["groups"] == Dict(
        "island" => 1, "partial" => 0, "fallback" => 0, "total" => 1)

    # Publisher-declared native-only controls must bypass extraction and
    # compilation entirely while retaining an honest report + warning shim.
    configured_out = mktempdir()
    configured_assets = generate_wasm_islands(session, poison, poison_state;
        output_dir=configured_out, url_path="import_poison.jl", verify=false,
        force_fallback_bonds=[:x])
    @test configured_assets == "import_poison.islands"
    configured_report = only(JSON.parsefile(joinpath(
        configured_out, configured_assets, "report.json")))
    @test configured_report["judgement"] == "fallback"
    @test configured_report["fallback_kind"] == "configured"
    @test configured_report["oracle_samples"] == 0
    @test all(c -> !c["ok"], configured_report["cells"])
    @test any(r -> occursin("island inference intentionally skipped", r),
              configured_report["reasons"])
    configured_manifest = JSON.parsefile(joinpath(
        configured_out, configured_assets, "islands.json"))
    @test isempty(configured_manifest["groups"])
    @test configured_manifest["fallback_groups"] == [
        Dict("bonds" => ["x"], "judgement" => "fallback",
             "fallback_kind" => "configured")]
    @test occursin("configured by the publisher",
        read(joinpath(configured_out, configured_assets, "shim.js"), String))

    invalid_out = mktempdir()
    @test_throws Snapshot.InvalidFallbackBondSelection generate_wasm_islands(
        session, poison, poison_state;
        output_dir=invalid_out, url_path="import_poison.jl", verify=false,
        force_fallback_bonds=[:renamed_or_missing])
    @test !ispath(joinpath(invalid_out, "import_poison.islands"))
    @test_throws Snapshot.InvalidFallbackBondSelection generate_wasm_islands(
        session, poison, poison_state;
        output_dir=invalid_out, url_path="import_poison.jl", verify=false,
        force_fallback_bonds=[1])
    @test_throws Snapshot.InvalidFallbackBondSelection generate_wasm_islands(
        session, poison, poison_state;
        output_dir=invalid_out, url_path="import_poison.jl", verify=false,
        force_fallback_bonds=42)

    bondless = Pluto.SessionActions.open(session, ERROR_OUTPUT; run_async=false)
    bondless_state = Pluto.notebook_to_js(bondless)
    @test_throws Snapshot.InvalidFallbackBondSelection generate_wasm_islands(
        session, bondless, bondless_state;
        output_dir=invalid_out, url_path="error_output.jl", verify=false,
        force_fallback_bonds=[:removed_last_bond])
    @test_throws Snapshot.InvalidFallbackBondSelection generate_wasm_islands(
        session, bondless, bondless_state;
        output_dir=invalid_out, url_path="error_output.jl", verify=false,
        force_fallback_bonds=42)
    Pluto.SessionActions.shutdown(session, bondless)

    # The same filtered preamble must preserve existing per-cell honesty: an
    # independently unsupported sibling is recorded as a partial island rather
    # than letting the unrelated failed import collapse the whole group.
    bad_plan = Snapshot.CellPlan(; cell_id=Base.UUID("ab000006-0000-4000-8000-000000000006"),
        mime="text/plain", export_name="intentional_failure",
        fn_expr=:(function (x::Int64); SnapshotMissingRuntime(x); end), ok=true)
    partial_group = ExtractedGroup(; bond_names=poison_group.bond_names,
        arg_types=poison_group.arg_types, initial_values=poison_group.initial_values,
        preamble=poison_group.preamble,
        cell_plans=vcat(poison_group.cell_plans, [bad_plan]), ok=true)
    partial_island = compile_group(partial_group; verify_node=false)
    @test partial_island.ok
    @test length(partial_island.cells) == length(poison_island.cells)
    @test length(partial_island.cell_failures) == 1

    partial_src = read(poison_path, String)
    partial_cell = """

    # ╔═╡ ab000006-0000-4000-8000-000000000006
    SnapshotMissingRuntime(x)
    """
    partial_src = replace(partial_src,
        "# ╔═╡ 00000000-0000-0000-0000-000000000001" =>
            partial_cell * "\n# ╔═╡ 00000000-0000-0000-0000-000000000001")
    partial_src = replace(partial_src,
        "# ╠═ab000005-0000-4000-8000-000000000005" =>
            "# ╠═ab000005-0000-4000-8000-000000000005\n# ╠═ab000006-0000-4000-8000-000000000006")
    partial_path = joinpath(mktempdir(), "import_partial.jl")
    write(partial_path, partial_src)
    pushfirst!(LOAD_PATH, fixture_parent)
    partial_nb = try
        Pluto.SessionActions.open(session, partial_path; run_async=false)
    finally
        popfirst!(LOAD_PATH)
    end
    partial_state = Pluto.notebook_to_js(partial_nb)
    partial_out = mktempdir()
    @test generate_wasm_islands(session, partial_nb, partial_state;
        output_dir=partial_out, url_path="import_partial.jl", verify=false) !== nothing
    partial_assets = joinpath(partial_out, "import_partial.islands")
    partial_report = only(JSON.parsefile(joinpath(partial_assets, "report.json")))
    @test partial_report["judgement"] == "partial"
    @test count(c -> c["ok"], partial_report["cells"]) == 1
    @test count(c -> !c["ok"], partial_report["cells"]) == 1
    partial_coverage = JSON.parsefile(joinpath(partial_assets, "coverage.json"))
    @test partial_coverage["groups"]["partial"] == 1
    @test partial_coverage["cells"] ==
          Dict("interactive" => 1, "fallback" => 1, "total" => 2)
    partial_manifest = JSON.parsefile(joinpath(partial_assets, "islands.json"))
    @test sum(length(g["cells"]) for g in partial_manifest["groups"]) == 1
    Pluto.SessionActions.shutdown(session, partial_nb)

    # Conversely, if the unavailable package is genuinely referenced, Snapshot
    # must retain its import and report an honest group fallback—not advertise a
    # false island or silently rewrite the user's Julia semantics.
    required_src = replace(read(poison_path, String), "x + 1" =>
        "SnapshotPoisonFixture.poison_marker(x)")
    required_path = joinpath(mktempdir(), "import_required.jl")
    write(required_path, required_src)
    pushfirst!(LOAD_PATH, fixture_parent)
    required_nb = try
        Pluto.SessionActions.open(session, required_path; run_async=false)
    finally
        popfirst!(LOAD_PATH)
    end
    required_state = Pluto.notebook_to_js(required_nb)
    required_group = only(extract_groups(session, required_nb;
        original_state=required_state))
    @test any(ex -> occursin("SnapshotPoisonFixture", string(ex)),
              required_group.preamble)
    required_island = compile_group(required_group; verify_node=false)
    @test !required_island.ok
    @test any(r -> occursin("preamble eval failed", r), required_island.reasons)
    required_out = mktempdir()
    @test generate_wasm_islands(session, required_nb, required_state;
        output_dir=required_out, url_path="import_required.jl", verify=false) !== nothing
    required_report = only(JSON.parsefile(joinpath(
        required_out, "import_required.islands", "report.json")))
    @test required_report["judgement"] == "fallback"
    @test all(c -> !c["ok"], required_report["cells"])

    # Browser contract: a fully-fallback group is truly inert and has a real,
    # accessible status node; the partial sibling remains operable. Re-running
    # decoration after a DOM mutation must not duplicate the status.
    browser_out = mktempdir()
    cp(joinpath(required_out, "import_required.islands"),
       joinpath(browser_out, "import_required.islands"))
    # Production publishers may omit detailed compiler reports. The manifest's
    # privacy-safe fallback index must still make the control inert.
    rm(joinpath(browser_out, "import_required.islands", "report.json"))
    cp(joinpath(partial_out, "import_partial.islands"),
       joinpath(browser_out, "import_partial.islands"))
    write(joinpath(browser_out, "import_required.html"),
          Snapshot.generate_therapy_html(required_nb, browser_out,
              "import_required", "import_required.islands"))
    write(joinpath(browser_out, "import_partial.html"),
          Snapshot.generate_therapy_html(partial_nb, browser_out,
              "import_partial", "import_partial.islands"))
    fallback_e2e = joinpath(@__DIR__, "e2e_fallback.mjs")
    fallback_proc = run(ignorestatus(`node $fallback_e2e $browser_out`))
    if fallback_proc.exitcode == 2
        @test_skip "playwright unavailable"
    else
        @test fallback_proc.exitcode == 0
    end
    Pluto.SessionActions.shutdown(session, required_nb)
    Pluto.SessionActions.shutdown(session, poison)

    soft_path = joinpath(@__DIR__, "notebooks", "import_softscope.jl")
    soft = Pluto.SessionActions.open(session, soft_path; run_async=false)
    soft_state = Pluto.notebook_to_js(soft)
    soft_connections = bound_variable_connections_graph(session, soft)
    soft_group = only(extract_groups(session, soft;
        connections=soft_connections, original_state=soft_state))

    # Pluto does not associate the exported `mean` binding with a plain
    # using-cell. Snapshot must recover the ordinary package import without
    # requiring users to rewrite it as an explicit import.
    @test soft_group.ok
    @test any(ex -> ex isa Expr && ex.head === :using, soft_group.preamble)
    @test any(ex -> ex isa Expr && ex.head === :import &&
                    occursin("magnitude", string(ex)), soft_group.preamble)
    soft_island = compile_group(soft_group; verify_node=false)
    @test soft_island.ok
    @test isempty(soft_island.cell_failures)
    Pluto.SessionActions.shutdown(session, soft)

    # Independent packages exporting the same name leave the unqualified Pluto
    # binding ambiguous. Neither package may be hoisted merely because it lists
    # that export: a healthy sibling must survive as a partial island.
    ambiguous_path = joinpath(@__DIR__, "notebooks", "import_ambiguous.jl")
    pushfirst!(LOAD_PATH, fixture_parent)
    ambiguous = try
        Pluto.SessionActions.open(session, ambiguous_path; run_async=false)
    finally
        popfirst!(LOAD_PATH)
    end
    ambiguous_state = Pluto.notebook_to_js(ambiguous)
    ambiguous_group = only(extract_groups(session, ambiguous;
        original_state=ambiguous_state))
    @test !any(ex -> occursin("SnapshotGoodClashFixture", string(ex)) ||
                    occursin("SnapshotPoisonFixture", string(ex)),
               ambiguous_group.preamble)
    ambiguous_island = compile_group(ambiguous_group; verify_node=false)
    @test ambiguous_island.ok
    @test length(ambiguous_island.cells) == 1
    @test length(ambiguous_island.cell_failures) == 1
    Pluto.SessionActions.shutdown(session, ambiguous)

end

# ─── combine-style multi-input widget: output-suppressed bond cell, html from
#     the workspace bond registry, Vector raw values + transform table ────────
let
    nb2 = Pluto.SessionActions.open(session, joinpath(@__DIR__, "notebooks", "combine_widget.jl"); run_async=false)
    st2 = Pluto.notebook_to_js(nb2)
    conn2 = bound_variable_connections_graph(session, nb2)
    @testset "combine widget introspection" begin
        gs = extract_groups(session, nb2; connections=conn2, original_state=st2)
        @test length(gs) == 1
        g = gs[1]
        @test g.ok
        @test g.bond_names == [:duo]
        @test g.synthetic_initials
        # the initial is REMAPPED through the transform table: raw ["#aabbcc", 2]
        # (what the client sends) becomes the NamedTuple the cell fn consumes
        @test g.initial_values == [(color = "#aabbcc", n = 2)]
        # raw probe domain: initial combo + vary-one-child-at-a-time
        @test g.domains[1] isa Vector
        @test length(g.domains[1]) >= 3
        @test all(d -> d isa Vector, g.domains[1])
        @test g.transforms[1] !== nothing
    end
    Pluto.SessionActions.shutdown(session, nb2)
end

# ─── feedback notebook: `if/elseif/else` of wrapper(md"…") cells + a nested-md
#     cell — the generalized md-skeleton (markdown structure rendered once &
#     baked; only branch conditions + string(scalar) compiled) ───────────────
let
    nbf = Pluto.SessionActions.open(session, joinpath(@__DIR__, "notebooks", "feedback_pared.jl"); run_async=false)
    stf = Pluto.notebook_to_js(nbf)
    connf = bound_variable_connections_graph(session, nbf)
    @testset "feedback cells (branch + nested md skeleton)" begin
        gs = extract_groups(session, nbf; connections=connf, original_state=stf)
        @test length(gs) == 1
        g = gs[1]
        @test g.ok
        @test g.bond_names == [:x]
        @test length(g.cell_plans) == 2
        @test all(p -> p.ok, g.cell_plans)

        # The admonition STRUCTURE is baked into the skeleton, so each fn is pure
        # string ops (no correct/keep_working/Markdown machinery) — it evals in a
        # bare sandbox and reproduces the original body at the initial value.
        sandbox = Module(:FeedbackSandbox)
        for p in g.cell_plans
            f = Core.eval(sandbox, p.fn_expr)
            @test Base.invokelatest(f, g.initial_values...) ==
                  stf["cell_results"][p.cell_id]["output"]["body"]
        end

        # compile + oracle: 12 samples over x∈1:100 hit BOTH if-branches; the
        # generated wasm must match real notebook re-runs on each.
        if HAS_NODE
            island = compile_group(g; verify_node=false)
            @test island.ok
            @test isempty(island.cell_failures)
            res = differential_oracle(session, nbf, stf, connf, g, island; samples=12)
            @test res.ok
            @test res.samples_run == 12
        end
    end
    Pluto.SessionActions.shutdown(session, nbf)
end

# ─── pieces notebook: a no-initial-value range bond → the feedback cell ERRORS at
#     the initial state (stacktrace mime) and has a bond-DEPENDENT nested
#     admonition `$(keep_working(md"…$(Int(n…))…"))`. Exercises the stacktrace-mime
#     skeleton gate + in-place nested-md sentinelization (Basic-mathematics :n). ──
let
    nbp = Pluto.SessionActions.open(session, joinpath(@__DIR__, "notebooks", "pieces_pared.jl"); run_async=false)
    stp = Pluto.notebook_to_js(nbp)
    connp = bound_variable_connections_graph(session, nbp)
    @testset "feedback cells (stacktrace-mime + nested bond-dependent md)" begin
        gs = extract_groups(session, nbp; connections=connp, original_state=stp)
        @test length(gs) == 1
        g = gs[1]
        @test g.ok
        @test g.bond_names == [:n]
        @test length(g.cell_plans) == 1
        @test all(p -> p.ok, g.cell_plans)
        if HAS_NODE
            island = compile_group(g; verify_node=false)
            @test island.ok
            @test isempty(island.cell_failures)
            # 12 samples over n∈0:50 hit both `if` branches AND render the nested
            # admonition as a proper block (no <p>-wrapped <div> mismatch).
            res = differential_oracle(session, nbp, stp, connp, g, island; samples=12)
            @test res.ok
            @test res.samples_run == 12
        end
    end
    Pluto.SessionActions.shutdown(session, nbp)
end

# ─── matrix bond: Matrix{Float64} crosses the bridge (rows×cols + row-major
#     element stream). Unlocks convolution filter / image-matrix bonds (C-P3). ──
let
    nbm = Pluto.SessionActions.open(session, joinpath(@__DIR__, "notebooks", "matbond_pared.jl"); run_async=false)
    stm = Pluto.notebook_to_js(nbm)
    connm = bound_variable_connections_graph(session, nbm)
    @testset "matrix bond (Matrix{Float64} bridge)" begin
        gs = extract_groups(session, nbm; connections=connm, original_state=stm)
        @test length(gs) == 1
        g = gs[1]
        @test g.ok
        @test g.arg_types == [Matrix{Float64}]
        @test all(p -> p.ok, g.cell_plans)
        if HAS_NODE
            island = compile_group(g; verify_node=false)
            @test island.ok
            # samples are varied-SIZE matrices (2×3, 2×2) — dims + values must
            # round-trip (size/getindex/sum all checked in the cell body).
            res = differential_oracle(session, nbm, stm, connm, g, island; samples=3)
            @test res.ok
            @test res.samples_run == 3
        end
    end
    Pluto.SessionActions.shutdown(session, nbm)
end

if HAS_NODE
    initial_bodies = Dict{String,Any}(
        string(id) => cr["output"]["body"] for (id, cr) in original_state["cell_results"]
    )

    @testset "compile + node verify" begin
        g = extract_groups(session, notebook; connections, original_state)[1]
        island = compile_group(g; initial_bodies, verify_node=true)
        @test island.ok
        @test length(island.cells) == 2
        @test isempty(island.cell_failures)

        # tampered bodies must be caught per cell — none survive
        bad_bodies = Dict{String,Any}(k => v * "TAMPERED" for (k, v) in initial_bodies)
        bad = compile_group(g; initial_bodies=bad_bodies, verify_node=true)
        @test !bad.ok
        @test length(bad.cell_failures) == 2
    end

    @testset "differential oracle" begin
        g = extract_groups(session, notebook; connections, original_state)[1]
        island = compile_group(g; verify_node=false)
        res = differential_oracle(session, notebook, original_state, connections, g, island; samples=5)
        @test res.ok
        @test res.samples_run == 5

        # off-by-one wasm must be caught per cell
        tampered_plans = [
            Snapshot.CellPlan(;
                cell_id=p.cell_id, mime=p.mime, export_name=p.export_name,
                fn_expr=Expr(:function, Expr(:tuple, :(x::Int64)), :(return string(x^2 + 1))),
                ok=true)
            for p in g.cell_plans
        ]
        g_bad = ExtractedGroup(;
            bond_names=g.bond_names, arg_types=g.arg_types, initial_values=g.initial_values,
            preamble=g.preamble, cell_plans=tampered_plans, ok=true)
        island_bad = compile_group(g_bad; verify_node=false)
        res_bad = differential_oracle(session, notebook, original_state, connections, g_bad, island_bad; samples=5)
        @test !res_bad.ok
        @test length(res_bad.failed_cells) == length(island_bad.cells)
    end
end

Pluto.SessionActions.shutdown(session, notebook; async=false)

# ─── figure notebook: WasmMakie canvas cells (E-004) ─────────────────────────
const WASMMAKIE_DIR = normpath(joinpath(@__DIR__, "..", "..", "WasmMakie.jl"))

if isdir(WASMMAKIE_DIR)
    @testset "canvas cells (WasmMakie figure)" begin
        # WasmMakie is unregistered → prepare a real env for the notebook's
        # Pkg.activate escape-hatch cell (nbpkg can't install path deps)
        env = mktempdir()
        write(joinpath(env, "Project.toml"), """
            [deps]
            WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

            [sources]
            WasmMakie = {path = "$(WASMMAKIE_DIR)"}
            """)
        prev_proj = Base.active_project()
        Pkg.activate(env; io=devnull)
        Pkg.instantiate(; io=devnull)
        Pkg.activate(dirname(prev_proj); io=devnull)

        src = read(joinpath(@__DIR__, "notebooks", "figure.jl"), String)
        nbpath = joinpath(mktempdir(), "figure.jl")
        write(nbpath, replace(src, "@@WM_ENV@@" => env))
        nbf = Pluto.SessionActions.open(session, nbpath; run_async=false)
        # the notebook's own Pkg.activate ran in-process and must STAY active:
        # Pluto re-evals `using WasmMakie` in each fresh workspace module the
        # oracle's bond re-runs create — restoring early breaks the reimport
        stf = Pluto.notebook_to_js(nbf)
        connf = bound_variable_connections_graph(session, nbf)
        gf = only(extract_groups(session, nbf; connections=connf, original_state=stf))
        @test gf.ok
        @test gf.bond_names == [:n]
        @test gf.arg_types == [Int64]

        island = compile_group(gf; verify_node=false, env_dir=env)
        @test island.ok
        # A partial island remains group-valid by design, so assert the
        # per-cell admission diagnostics before indexing the canvas result.
        # This makes a compiler regression report its structured cause instead
        # of collapsing into an unhelpful `only(empty)` error.
        @test isempty(island.cell_failures)
        canvas_cells = [c for c in island.cells if c.kind == "canvas"]
        @test length(canvas_cells) == 1
        cc = only(canvas_cells)
        @test cc.desc["w"] > 0 && cc.desc["h"] > 0
        @test any(c -> c.kind == "string", island.cells)   # md cell stays a string body
        @test island.canvas_glue !== nothing && occursin("canvas2d_imports", island.canvas_glue)
        @test island.canvas_fonts !== nothing && startswith(island.canvas_fonts, "[")
        @test findfirst(codeunits("canvas2d"), island.bytes) !== nothing

        # manifest carries the provider payload + cell kind
        out = mktempdir()
        write_island_assets(out, [island])
        manifest = JSON.parsefile(joinpath(out, "islands.json"))
        grp = manifest["groups"][1]
        @test grp["canvas_glue"] !== nothing
        cellsm = Dict(c["id"] => c for c in grp["cells"])
        @test cellsm[cc.cell_id]["kind"] == "canvas"
        @test cellsm[cc.cell_id]["desc"]["w"] == cc.desc["w"]

        # node smoke: the canvas export must actually drive the canvas2d
        # imports (counting stubs; per-import return types from the specs)
        if HAS_NODE
            WM = Base.loaded_modules[Base.PkgId(
                Base.UUID("782397d3-b2e0-4093-86f4-3070b4a5c6bd"), "WasmMakie")]
            rets = Dict(string(s.name) => string(s.ret) for s in WM.import_specs())
            script = """
            const fs = require('fs');
            const bytes = fs.readFileSync(process.argv[2]);
            const rets = $(JSON.json(rets));
            let count = 0;
            (async () => {
              const mod = await WebAssembly.compile(bytes);
              const imports = {};
              for (const imp of WebAssembly.Module.imports(mod)) {
                (imports[imp.module] ||= {})[imp.name] =
                  imp.module === 'Math' ? Math[imp.name] :
                  imp.module === 'canvas2d'
                    ? (rets[imp.name] === 'F64' ? (() => { count++; return 0; })
                                                : (() => { count++; return 0n; }))
                    : (() => 0n);
              }
              const ex = (await WebAssembly.instantiate(mod, imports)).exports;
              ex["$(cc.export_name)"](2n);
              console.log(count);
            })().catch(e => { console.error(String(e && e.message || e)); process.exit(1); });
            """
            mktempdir() do dir
                write(joinpath(dir, "island.wasm"), island.bytes)
                write(joinpath(dir, "smoke.cjs"), script)
                io = IOBuffer()
                ok = success(pipeline(`node $(joinpath(dir, "smoke.cjs")) $(joinpath(dir, "island.wasm"))`;
                                      stdout=io, stderr=stderr))
                @test ok
                ok && @test parse(Int, strip(String(take!(io)))) > 50
            end

            # command-stream equality oracle: native html_snippet's embedded
            # RecordingCtx stream vs the wasm export run under recording stubs
            res = differential_oracle(session, nbf, stf, connf, gf, island; samples=4)
            @test res.ok
            @test res.samples_run == 4
            @test isempty(res.failed_cells)
        end

        Pluto.SessionActions.shutdown(session, nbf; async=false)
        Pkg.activate(dirname(prev_proj); io=devnull)
    end

    HAS_NODE && @testset "canvas export (figure notebook e2e)" begin
        # reuse the prepared env + templated notebook from the testset above
        env = mktempdir()
        write(joinpath(env, "Project.toml"), """
            [deps]
            WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

            [sources]
            WasmMakie = {path = "$(WASMMAKIE_DIR)"}
            """)
        prev_proj = Base.active_project()
        Pkg.activate(env; io=devnull)
        Pkg.instantiate(; io=devnull)
        Pkg.activate(dirname(prev_proj); io=devnull)

        src = read(joinpath(@__DIR__, "notebooks", "figure.jl"), String)
        nbpath = joinpath(mktempdir(), "figure.jl")
        write(nbpath, replace(src, "@@WM_ENV@@" => env))

        out = mktempdir()
        # Persistent canvases are a lean-host contract. The classic Pluto
        # export intentionally keeps its staterequest-compatible <img> fallback.
        html_path = export_notebook(nbpath; output_dir=out, session, env_dir=env,
                                    therapy=true)
        Pkg.activate(dirname(prev_proj); io=devnull)   # notebook leaked its activate
        @test isfile(html_path)

        manifest = JSON.parsefile(joinpath(out, "figure.islands", "islands.json"))
        kinds = [c["kind"] for g2 in manifest["groups"] for c in g2["cells"]]
        @test "canvas" in kinds
        @test any(g2 -> g2["canvas_glue"] !== nothing, manifest["groups"])
        report = JSON.parsefile(joinpath(out, "figure.islands", "report.json"))
        @test report[1]["judgement"] == "island"
        @test all(c -> c["ok"], report[1]["cells"])

        e2e = joinpath(@__DIR__, "e2e_canvas.mjs")
        proc = run(ignorestatus(`node $e2e $out figure.html`))
        if proc.exitcode == 2
            @test_skip "playwright unavailable"
        else
            @test proc.exitcode == 0
        end
    end
end

# ─── two_groups: per-cell judgement + asset writing ──────────────────────────
if HAS_NODE
    @testset "hybrid judgement + assets" begin
        nb2 = Pluto.SessionActions.open(session, TWO_GROUPS; run_async=false)
        st2 = Pluto.notebook_to_js(nb2)
        delete!(st2, "status_tree")

        out = mktempdir()
        dirname_ = generate_wasm_islands(session, nb2, st2; output_dir=out, url_path="two_groups.jl")
        @test dirname_ == "two_groups.islands"
        assets = joinpath(out, dirname_)

        report = JSON.parsefile(joinpath(assets, "report.json"))
        by_bonds = Dict(first(r["bonds"]) => r for r in report)
        @test by_bonds["x"]["judgement"] == "island"
        @test by_bonds["x"]["oracle_samples"] > 0
        @test all(c -> c["ok"], by_bonds["x"]["cells"])
        # z's collect(1:z) ships as a TREE island (bridge read-side)
        @test by_bonds["z"]["judgement"] == "island"
        @test all(c -> c["ok"], by_bonds["z"]["cells"])

        mixed_out = mktempdir()
        mixed_name = generate_wasm_islands(session, nb2, st2;
            output_dir=mixed_out, url_path="two_groups.jl",
            force_fallback_bonds=["x"])
        mixed_report = JSON.parsefile(joinpath(mixed_out, mixed_name, "report.json"))
        mixed_by_bonds = Dict(first(r["bonds"]) => r for r in mixed_report)
        @test mixed_by_bonds["x"]["judgement"] == "fallback"
        @test mixed_by_bonds["x"]["fallback_kind"] == "configured"
        @test mixed_by_bonds["z"]["judgement"] == "island"
        mixed_manifest = JSON.parsefile(joinpath(mixed_out, mixed_name, "islands.json"))
        @test length(mixed_manifest["groups"]) == 1
        @test only(mixed_manifest["groups"])["bonds"][1]["name"] == "z"

        # Connected groups are atomic: selecting one bond must never leave its
        # co-dependent sibling falsely live.
        connected_path = joinpath(mktempdir(), "connected_groups.jl")
        write(connected_path, replace(read(TWO_GROUPS, String),
            "collect(1:z)" => "(collect(1:z), x + z)"))
        connected_nb = Pluto.SessionActions.open(session, connected_path; run_async=false)
        connected_state = Pluto.notebook_to_js(connected_nb)
        connected_out = mktempdir()
        connected_name = generate_wasm_islands(session, connected_nb, connected_state;
            output_dir=connected_out, url_path="connected_groups.jl",
            verify=false, force_fallback_bonds=[:x])
        connected_report = JSON.parsefile(joinpath(
            connected_out, connected_name, "report.json"))
        @test length(connected_report) == 1
        @test Set(only(connected_report)["bonds"]) == Set(["x", "z"])
        @test only(connected_report)["judgement"] == "fallback"
        @test only(connected_report)["fallback_kind"] == "configured"
        @test isempty(JSON.parsefile(joinpath(
            connected_out, connected_name, "islands.json"))["groups"])
        Pluto.SessionActions.shutdown(session, connected_nb; async=false)

        manifest = JSON.parsefile(joinpath(assets, "islands.json"))
        @test length(manifest["groups"]) == 2
        tree_cells = [c for g in manifest["groups"] for c in g["cells"] if c["kind"] == "tree"]
        @test length(tree_cells) == 1
        @test haskey(manifest["bond_graph"], "x") && haskey(manifest["bond_graph"], "z")
        @test manifest["fallback_warnings"] == true
        @test isfile(joinpath(assets, "shim.js"))
        shim = read(joinpath(assets, "shim.js"), String)
        @test occursin("cell.present_frame(front, cell.frame, cell.w, cell.h, seq)", shim)
        @test occursin("Number(front.dataset.wasmmakiePresentation || 0) + 1", shim)
        # Fully-fallback groups must not leave a native Pluto widget looking
        # live while every dependent output is frozen at export time.
        @test occursin("group.judgement === \"fallback\"", shim)
        @test occursin("control.disabled = true", shim)
        @test occursin("static in this export", shim)
        @test isfile(joinpath(assets, manifest["groups"][1]["wasm"]))

        Pluto.SessionActions.shutdown(session, nb2; async=false)
    end

    @testset "export_notebook (self-contained)" begin
        out = mktempdir()
        invalid_out = mktempdir()
        @test_throws Snapshot.InvalidFallbackBondSelection export_notebook(
            TWO_GROUPS; output_dir=invalid_out, session,
            force_fallback_bonds=[:stale_publisher_config])
        @test_throws Snapshot.InvalidFallbackBondSelection export_notebook(
            ERROR_OUTPUT; output_dir=invalid_out, session,
            force_fallback_bonds=[:removed_last_bond])
        @test isempty(readdir(invalid_out))

        html_path = export_notebook(DEMO; output_dir=out, session)
        @test isfile(html_path)
        html = read(html_path, String)
        @test occursin("demo.islands/shim.js", html)
        @test occursin("pluto_slider_server_url = \".\"", html)
        @test isfile(joinpath(out, "demo.islands", "islands.json"))

        # browser E2E (exit 2 = playwright unavailable → skip)
        e2e = joinpath(@__DIR__, "e2e.mjs")
        proc = run(ignorestatus(`node $e2e $out demo.html`))
        if proc.exitcode == 2
            @test_skip "playwright unavailable"
        else
            @test proc.exitcode == 0
        end
    end
end

println("SNAPSHOT TESTS DONE")
