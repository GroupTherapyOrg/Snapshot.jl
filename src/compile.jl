# islands/compile.jl — M2: ExtractedGroup → WasmGC island module + assets
#
# Stateless model (per M0): one wasm export per dependent cell,
#
#     cellbody_<id>(bond₁, bond₂, …) -> String
#
# recomputed per staterequest — mirroring the slider-server protocol's own
# statelessness. Strings cross to JS via the `_str_len`/`_str_byte` accessor
# pattern (Therapy.jl), so no js-string builtins are required.
#
# Compilation is all-or-nothing per group: a partial island would repaint
# some cells and leave others stale. Any cell failing WasmTarget's strict
# compile (or the Node initial-body verification) degrades the whole group —
# with reasons — so M4's judgement can route it to precompute/live fallback.

import WasmTarget
import JSON


Base.@kwdef struct CompiledIsland
    bond_names::Vector{Symbol}
    arg_types::Vector{DataType}
    initial_values::Vector{Any}
    bytes::Vector{UInt8}
    cells::Vector{NamedTuple{(:cell_id, :export_name),Tuple{String,String}}}
    ok::Bool
    reasons::Vector{String} = String[]
    # per-cell failures (PARTIAL islands): these dependent cells won't update
    # in the export — the shim decorates exactly these with warnings
    cell_failures::Vector{NamedTuple{(:cell_id, :reasons),Tuple{String,Vector{String}}}} =
        NamedTuple{(:cell_id, :reasons),Tuple{String,Vector{String}}}[]
end

const _SUPPORTED_BOND_TYPES = (Int64, Int32, Float64, Float32, Bool)

_js_arg_tag(T::DataType) = T <: Union{Int64,Int32} ? "int" : T <: Union{Float64,Float32} ? "float" : "bool"

# ─────────────────────────────────────────────────────────────────────────────
# Group → wasm bytes
# ─────────────────────────────────────────────────────────────────────────────

"""
    compile_group(g; initial_bodies=nothing, verify_node=true, optimize=false)

Compile one extracted group to a wasm island, with PER-CELL granularity:
each dependent cell is probe-compiled and verified individually; cells that
fail any stage are recorded in `cell_failures` (with reasons) while the
surviving cells still ship. A partial island is honest: surviving cells
update live, failed cells keep their original content and get decorated by
the shim. Only group-level gates (bond types, preamble, module assembly)
degrade the whole group.
"""
function compile_group(
    g::ExtractedGroup;
    initial_bodies::Union{Nothing,Dict{String,String}}=nothing,
    verify_node::Bool=true,
    optimize=false,
)::CompiledIsland
    CF = NamedTuple{(:cell_id, :reasons),Tuple{String,Vector{String}}}
    failures = CF[]
    cellfail!(id, rs...) = push!(failures, (cell_id=string(id), reasons=collect(String, rs)))

    fail(reasons...) = CompiledIsland(;
        bond_names=g.bond_names, arg_types=g.arg_types, initial_values=g.initial_values,
        bytes=UInt8[], cells=[], ok=false, reasons=collect(String, reasons),
        cell_failures=failures)

    g.ok || return fail("extraction not ok", g.reasons...)
    all(T -> any(S -> T === S, _SUPPORTED_BOND_TYPES), g.arg_types) ||
        return fail("unsupported bond arg types $(g.arg_types) (v0: Int/Float/Bool)")

    # Sandbox module: preamble (structs/imports) at top level — group-level gate
    sandbox = Module(gensym(:PlutoIslandCompile))
    try
        for pre in g.preamble
            Core.eval(sandbox, pre)
        end
    catch e
        return fail("preamble eval failed: $(sprint(showerror, e)[1:min(end, 300)])")
    end

    # Per-cell: eval + probe-compile individually; survivors enter the module
    arg_tuple = Tuple(g.arg_types)
    survivors = Pair{Function,CellPlan}[]
    for p in g.cell_plans
        if !p.ok
            cellfail!(p.cell_id, p.reasons...)
            continue
        end
        f = try
            Core.eval(sandbox, p.fn_expr)
        catch e
            cellfail!(p.cell_id, "sandbox eval failed: $(sprint(showerror, e)[1:min(end, 200)])")
            continue
        end
        try
            WasmTarget.compile(f, arg_tuple)
        catch e
            cellfail!(p.cell_id, "WasmTarget compile failed: $(sprint(showerror, e)[1:min(end, 200)])")
            continue
        end
        push!(survivors, f => p)
    end
    isempty(survivors) && return fail("no cells compiled")

    entries = Vector{Any}()
    for (f, p) in survivors
        push!(entries, (f, arg_tuple, p.export_name))
    end
    # String→JS accessors. Closure form on purpose: the typed-declaration form
    # trips WasmTarget's sequential-compile state pollution gap when compiled
    # after string-concat functions (see WASM_FINDINGS.md).
    push!(entries, ((s::String) -> Int64(ncodeunits(s)), (String,), "_str_len"))
    push!(entries, ((s::String, i::Int64) -> Int64(codeunit(s, i)), (String, Int64), "_str_byte"))

    bytes = try
        WasmTarget.compile_multi(entries; optimize)
    catch e
        return fail("module assembly (compile_multi) failed: $(sprint(showerror, e)[1:min(end, 300)])")
    end

    island = CompiledIsland(;
        bond_names=g.bond_names, arg_types=g.arg_types, initial_values=g.initial_values,
        bytes,
        cells=[(cell_id=string(p.cell_id), export_name=p.export_name) for (_, p) in survivors],
        ok=true, cell_failures=failures)

    if verify_node && initial_bodies !== nothing
        result = _verify_initial_bodies(island, initial_bodies)
        result isa String && return fail("Node verification failed globally: $result")
        if !isempty(result)
            island = exclude_cells(island, result)
            if isempty(island.cells)
                return CompiledIsland(;
                    bond_names=g.bond_names, arg_types=g.arg_types,
                    initial_values=g.initial_values, bytes=UInt8[], cells=[],
                    ok=false, reasons=["no cells survived initial-body verification"],
                    cell_failures=island.cell_failures)
            end
        end
    end

    island
end

"Drop cells (id ⇒ reason) from an island, recording them as failures."
function exclude_cells(island::CompiledIsland, failed::Dict{String,String})::CompiledIsland
    CompiledIsland(;
        bond_names=island.bond_names, arg_types=island.arg_types,
        initial_values=island.initial_values, bytes=island.bytes,
        cells=[c for c in island.cells if !haskey(failed, c.cell_id)],
        ok=island.ok, reasons=island.reasons,
        cell_failures=vcat(island.cell_failures,
            [(cell_id=id, reasons=[r]) for (id, r) in failed]))
end

"Compile every group; returns (islands, degraded) — degraded carry reasons."
function compile_islands(groups::Vector{ExtractedGroup}; kwargs...)
    islands = [compile_group(g; kwargs...) for g in groups]
    (islands=[i for i in islands if i.ok], degraded=[i for i in islands if !i.ok])
end

# ─────────────────────────────────────────────────────────────────────────────
# Node verification (mini-oracle at initial values; M4 samples the domain)
# ─────────────────────────────────────────────────────────────────────────────

_js_initial(v::Union{Int64,Int32}) = "BigInt(\"$(v)\")"
_js_initial(v::Union{Float64,Float32}) = string(Float64(v))
_js_initial(v::Bool) = v ? "1" : "0"

"""
Per-cell Node verification. Returns a `String` on GLOBAL failure (module
won't instantiate etc.), else `Dict{String,String}` of failing cell ids ⇒
reason (empty = all good). Each export call is individually try/caught so
one trapping cell doesn't poison the others.
"""
function _verify_initial_bodies(island::CompiledIsland, initial_bodies::Dict{String,String})
    args_js = join([_js_initial(v) for v in island.initial_values], ", ")
    calls = join(["""  try { out[$(repr(c.cell_id))] = {ok: true, body: readStr(ex.$(c.export_name)($args_js))}; }
      catch (e) { out[$(repr(c.cell_id))] = {ok: false, err: String(e && e.message || e)}; }"""
                  for c in island.cells], "\n")
    script = """
    const fs = require('fs');
    const bytes = fs.readFileSync(process.argv[2]);
    (async () => {
      const mod = await WebAssembly.compile(bytes);
      const imports = {};
      for (const imp of WebAssembly.Module.imports(mod)) {
        (imports[imp.module] ||= {})[imp.name] = imp.module === 'Math' ? Math[imp.name] : (() => 0);
      }
      const ex = (await WebAssembly.instantiate(mod, imports)).exports;
      const readStr = (ref) => {
        const len = Number(ex._str_len(ref));
        const b = new Uint8Array(len);
        for (let i = 1; i <= len; i++) b[i-1] = Number(ex._str_byte(ref, BigInt(i)));
        return new TextDecoder().decode(b);
      };
      const out = {};
    $(calls)
      console.log(JSON.stringify(out));
    })().catch(e => { console.error(String(e && e.message || e)); process.exit(1); });
    """
    mktempdir() do dir
        wasm_path = joinpath(dir, "island.wasm")
        js_path = joinpath(dir, "check.cjs")
        write(wasm_path, island.bytes)
        write(js_path, script)
        out = IOBuffer(); errio = IOBuffer()
        ok = success(pipeline(`node $js_path $wasm_path`; stdout=out, stderr=errio))
        ok || return "node failed: $(String(take!(errio))[1:min(end, 300)])"
        got = JSON.parse(String(take!(out)))
        failed = Dict{String,String}()
        for c in island.cells
            expected = get(initial_bodies, c.cell_id, nothing)
            r = get(got, c.cell_id, nothing)
            if expected === nothing
                failed[c.cell_id] = "no original body to verify against"
            elseif r === nothing || !r["ok"]
                failed[c.cell_id] = "wasm call failed: $(r === nothing ? "missing" : r["err"])"
            elseif r["body"] != expected
                failed[c.cell_id] = "initial body mismatch: wasm $(repr(r["body"])) != original $(repr(expected))"
            end
        end
        failed
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Asset writing (what the M3 export step ships)
# ─────────────────────────────────────────────────────────────────────────────

"""
    write_island_assets(dir, islands; bond_graph=nothing) -> manifest_path

Write `group_<k>.wasm` + `islands.json` + `shim.js` into `dir` (the
`<notebook>.islands/` directory next to the exported HTML). `bond_graph` is
the FULL bondconnections graph (island + fallback groups) — the shim serves
it so fallback bonds still reach their precompute files / live server.
"""
function write_island_assets(
    dir::AbstractString,
    islands::Vector{CompiledIsland};
    bond_graph::Union{Nothing,Dict{String,Vector{String}}}=nothing,
    fallback_warnings::Bool=true,
)
    mkpath(dir)
    manifest = Dict(
        "version" => 1,
        # decorate non-island bond cells with not-interactive admonitions?
        # (exports with a live/precompute backend set this false — those
        # groups ARE interactive, just not via wasm)
        "fallback_warnings" => fallback_warnings,
        "bond_graph" => something(bond_graph, Dict(
            string(n) => string.(island.bond_names)
            for island in islands for n in island.bond_names
        )),
        "groups" => [
            begin
                wasm_name = "group_$(k - 1).wasm"
                write(joinpath(dir, wasm_name), island.bytes)
                Dict(
                    "wasm" => wasm_name,
                    # initial values double as defaults: the client omits
                    # never-touched bonds from staterequests. Non-finite floats
                    # encode as strings (JSON forbids NaN/Inf); the shim's
                    # Number(...) coercion decodes them.
                    "bonds" => [Dict(
                        "name" => string(n),
                        "type" => _js_arg_tag(T),
                        "initial" => v isa Bool ? v : v isa Integer ? Int(v) :
                                     isfinite(Float64(v)) ? Float64(v) : string(Float64(v)),
                        ) for (n, T, v) in zip(island.bond_names, island.arg_types, island.initial_values)],
                    "cells" => [Dict("id" => c.cell_id, "fn" => c.export_name) for c in island.cells],
                )
            end for (k, island) in enumerate(islands)
        ],
    )
    manifest_path = joinpath(dir, "islands.json")
    write(manifest_path, JSON.json(manifest))
    cp(joinpath(@__DIR__, "..", "assets", "shim.js"), joinpath(dir, "shim.js"); force=true)
    manifest_path
end
