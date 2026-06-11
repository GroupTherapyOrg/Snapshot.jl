# PlutoIslands test suite — extraction, compilation, oracle, judgement, and
# (when node is available) the full export. One process, one warmup.

using Test
import Pluto
import JSON
using PlutoIslands

const HAS_NODE = Sys.which("node") !== nothing

const DEMO = joinpath(@__DIR__, "notebooks", "demo.jl")          # slider → x^2 → md
const TWO_GROUPS = joinpath(@__DIR__, "notebooks", "two_groups.jl")  # island group + fallback group

session = Pluto.ServerSession()
session.options.evaluation.workspace_use_distributed = false

# ─── demo notebook: extraction → compile → oracle ───────────────────────────
notebook = Pluto.SessionActions.open(session, DEMO; run_async=false)
original_state = Pluto.notebook_to_js(notebook)
connections = bound_variable_connections_graph(session, notebook)

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
            PlutoIslands.CellPlan(;
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
        @test by_bonds["z"]["judgement"] == "fallback"
        @test all(c -> !c["ok"], by_bonds["z"]["cells"])

        manifest = JSON.parsefile(joinpath(assets, "islands.json"))
        @test length(manifest["groups"]) == 1
        @test haskey(manifest["bond_graph"], "x") && haskey(manifest["bond_graph"], "z")
        @test manifest["fallback_warnings"] == true
        @test isfile(joinpath(assets, "shim.js"))
        @test isfile(joinpath(assets, manifest["groups"][1]["wasm"]))

        Pluto.SessionActions.shutdown(session, nb2; async=false)
    end

    @testset "export_notebook (self-contained)" begin
        out = mktempdir()
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

println("PLUTOISLANDS TESTS DONE")
