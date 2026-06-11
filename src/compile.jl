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
    cells::Vector{NamedTuple{(:cell_id, :export_name, :kind, :desc),Tuple{String,String,String,Any}}}
    ok::Bool
    reasons::Vector{String} = String[]
    # per-cell failures (PARTIAL islands): these dependent cells won't update
    # in the export — the shim decorates exactly these with warnings
    cell_failures::Vector{NamedTuple{(:cell_id, :reasons),Tuple{String,Vector{String}}}} =
        NamedTuple{(:cell_id, :reasons),Tuple{String,Vector{String}}}[]
    # WasmTarget.Bridge arg descriptors, one per bond (manifest + verify/oracle)
    arg_descs::Vector{Any} = Any[]
    # per-bond raw⇒transformed tables (see ExtractedGroup.transforms)
    transforms::Vector{Any} = Any[]
end

import WasmTarget.Bridge
import Pkg

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
    initial_bodies::Union{Nothing,Dict{String,Any}}=nothing,
    verify_node::Bool=true,
    optimize=false,
    # the notebook's package environment — activated during eval/compile so
    # notebook imports (e.g. `using Collatz`) resolve in the sandbox
    env_dir::Union{Nothing,String}=nothing,
)::CompiledIsland
    CF = NamedTuple{(:cell_id, :reasons),Tuple{String,Vector{String}}}
    failures = CF[]
    cellfail!(id, rs...) = push!(failures, (cell_id=string(id), reasons=collect(String, rs)))

    fail(reasons...) = CompiledIsland(;
        bond_names=g.bond_names, arg_types=g.arg_types, initial_values=g.initial_values,
        bytes=UInt8[], cells=[], ok=false, reasons=collect(String, reasons),
        cell_failures=failures)

    g.ok || return fail("extraction not ok", g.reasons...)

    prev_project = Base.active_project()
    env_dir !== nothing && Pkg.activate(env_dir; io=devnull)
    try
    all(Bridge.args_supported, g.arg_types) ||
        return fail("bond arg types $(g.arg_types) outside the bridge universe")

    # bridge marshalling: one arg descriptor per bond, plus the constructor
    # closure (ctors, vector new/set pairs) compiled into the module
    arg_descs = Any[]
    bridge_accs = Any[]
    bridge_names = Set{String}()
    for T in g.arg_types
        d, baccs = Bridge.arg_descriptor(T)
        push!(arg_descs, d)
        for (bf, bat, bnm) in baccs
            Bridge._acc!(bridge_accs, bridge_names, bnm, bf, bat)
        end
    end

    # Sandbox module: preamble (structs/imports) at top level — group-level gate
    sandbox = Module(gensym(:PlutoIslandCompile))
    try
        # Pluto injects these into every notebook module implicitly
        Core.eval(sandbox, :(using Markdown))
        Core.eval(sandbox, :(using InteractiveUtils))
        for pre in g.preamble
            Core.eval(sandbox, pre)
        end
    catch e
        return fail("preamble eval failed: $(sprint(showerror, e)[1:min(end, 300)])")
    end

    # Per-cell: eval + probe-compile individually; survivors enter the module
    arg_tuple = Tuple(g.arg_types)
    survivors = Tuple{Function,CellPlan,Any}[]
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
        tree_desc = nothing
        if p.body_kind === :tree
            rt = try
                only(Base.return_types(f, arg_tuple))
            catch
                Any
            end
            tree_desc = _tree_descriptor(rt)
            if tree_desc isa String
                cellfail!(p.cell_id, "tree body: $(tree_desc)")
                continue
            end
        end
        push!(survivors, (f, p, tree_desc))
    end
    isempty(survivors) && return fail("no cells compiled")

    entries = Vector{Any}()
    tree_acc_names = Set{String}()
    tree_accs = Any[]
    for (f, p, tree_desc) in survivors
        push!(entries, (f, arg_tuple, p.export_name))
        if tree_desc !== nothing
            # read-side accessors so the walker can take the value apart
            for (af, aat, anm) in tree_desc.accs
                Bridge._acc!(tree_accs, tree_acc_names, anm, af, aat)
            end
        end
    end
    append!(entries, tree_accs)
    # String→JS accessors. Closure form on purpose: the typed-declaration form
    # trips WasmTarget's sequential-compile state pollution gap when compiled
    # after string-concat functions (see WASM_FINDINGS.md).
    push!(entries, ((s::String) -> Int64(ncodeunits(s)), (String,), "_str_len"))
    push!(entries, ((s::String, i::Int64) -> Int64(codeunit(s, i)), (String, Int64), "_str_byte"))
    append!(entries, bridge_accs)

    bytes = try
        WasmTarget.compile_multi(entries; optimize)
    catch e
        return fail("module assembly (compile_multi) failed: $(sprint(showerror, e)[1:min(end, 300)])")
    end

    island = CompiledIsland(;
        bond_names=g.bond_names, arg_types=g.arg_types, initial_values=g.initial_values,
        bytes,
        cells=[(cell_id=string(p.cell_id), export_name=p.export_name,
                kind=p.body_kind === :tree ? "tree" : "string",
                desc=td === nothing ? nothing : td.desc) for (_, p, td) in survivors],
        ok=true, cell_failures=failures, arg_descs,
        transforms=isempty(g.transforms) ? Any[nothing for _ in g.bond_names] : g.transforms)

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
    finally
        env_dir !== nothing && prev_project !== nothing &&
            Pkg.activate(dirname(prev_project); io=devnull)
    end
end

"Drop cells (id ⇒ reason) from an island, recording them as failures."
function exclude_cells(island::CompiledIsland, failed::Dict{String,String})::CompiledIsland
    CompiledIsland(;
        bond_names=island.bond_names, arg_types=island.arg_types,
        initial_values=island.initial_values, bytes=island.bytes,
        cells=[c for c in island.cells if !haskey(failed, c.cell_id)],
        ok=island.ok, reasons=island.reasons,
        cell_failures=vcat(island.cell_failures,
            [(cell_id=id, reasons=[r]) for (id, r) in failed]),
        arg_descs=island.arg_descs, transforms=island.transforms)
end

"Compile every group; returns (islands, degraded) — degraded carry reasons."
function compile_islands(groups::Vector{ExtractedGroup}; kwargs...)
    islands = [compile_group(g; kwargs...) for g in groups]
    (islands=[i for i in islands if i.ok], degraded=[i for i in islands if !i.ok])
end

# ─────────────────────────────────────────────────────────────────────────────
# Tree (vector) bodies — bridge read-side
# ─────────────────────────────────────────────────────────────────────────────

const TREE_BODY_JS = read(joinpath(@__DIR__, "..", "assets", "tree_body.js"), String)

"""
Read descriptor for a tree-rendered cell value, decorated with the prefix
metadata the body renderer needs. Returns `(; desc, accs)` or a String reason.
v1 shape: `Vector` (nested) with Int/Bool/Float64/Char/String leaves.
"""
function _tree_descriptor(rt)
    rt isa DataType && isconcretetype(rt) &&
        (rt <: Vector || rt <: Tuple || rt <: NamedTuple) ||
        return "unsupported value type $(rt) (tree bodies: Vector/Tuple/NamedTuple)"
    dp = Bridge.descriptor(rt)
    dp === nothing && return "type $(rt) outside the bridge universe"
    desc = deepcopy(dp[1])
    ok = _tree_meta!(desc, rt)
    ok === nothing || return ok
    (; desc, accs=dp[2])
end

function _tree_meta!(d, T)
    if d["k"] == "vec"
        d["prefix"] = string(eltype(T))
        d["prefix_short"] = T <: Vector ? "" : string(eltype(T))
        return _tree_meta!(d["el"], eltype(T))
    elseif d["k"] == "fields" && (T <: Tuple || T <: NamedTuple)
        d["tt"] = T <: NamedTuple ? "NamedTuple" : "Tuple"
        for (i, fd) in enumerate(d["fs"])
            r = _tree_meta!(fd["d"], fieldtype(T, i))
            r === nothing || return r
        end
        return nothing
    elseif d["k"] in ("int", "char", "str")
        return nothing
    elseif d["k"] == "bits"
        # Float32 leaves print as "1.0f0" — renderer only does Float64
        return d["w"] == 64 ? nothing : "Float32 leaves unsupported in tree bodies"
    end
    return "tree leaf kind $(d["k"]) unsupported"
end

"Body comparison that tolerates representation noise: Symbol vs String keys,
tuples vs arrays, and ignores Pluto's per-render `objectid`."
function _body_match(a, b)::Bool
    if a isa AbstractString || a isa Number || a isa Bool
        return string(a) == string(b)
    elseif a isa AbstractDict
        b isa AbstractDict || return false
        ka = Set(string(k) for k in keys(a) if string(k) != "objectid")
        kb = Set(string(k) for k in keys(b) if string(k) != "objectid")
        ka == kb || return false
        return all(_body_match(_dget(a, k), _dget(b, k)) for k in ka)
    elseif a isa Union{Tuple,AbstractVector}
        (b isa Union{Tuple,AbstractVector} && length(a) == length(b)) || return false
        return all(_body_match(x, y) for (x, y) in zip(a, b))
    elseif a isa Symbol || a isa MIME
        return string(a) == string(b)
    end
    return isequal(a, b)
end
_dget(d::AbstractDict, k::String) = haskey(d, k) ? d[k] : d[Symbol(k)]

# ─────────────────────────────────────────────────────────────────────────────
# Node verification (mini-oracle at initial values; M4 samples the domain)
# ─────────────────────────────────────────────────────────────────────────────


"""
Per-cell Node verification. Returns a `String` on GLOBAL failure (module
won't instantiate etc.), else `Dict{String,String}` of failing cell ids ⇒
reason (empty = all good). Each export call is individually try/caught so
one trapping cell doesn't poison the others.
"""
function _verify_initial_bodies(island::CompiledIsland, initial_bodies::Dict{String,Any})
    # initial bond values cross via the bridge: tagged trees + in-module ctors
    atrees = [Bridge.value_to_tree(island.arg_descs[j], island.initial_values[j])
              for j in eachindex(island.arg_descs)]
    cdescs = Dict(c.cell_id => c.desc for c in island.cells if c.kind == "tree")
    calls = join([c.kind == "tree" ?
        """  try { out[$(repr(c.cell_id))] = {ok: true, body: pluto_tree_body(cdescs[$(repr(c.cell_id))], walk(cdescs[$(repr(c.cell_id))], ex.$(c.export_name)(...args)))}; }
      catch (e) { out[$(repr(c.cell_id))] = {ok: false, err: String(e && e.message || e)}; }""" :
        """  try { out[$(repr(c.cell_id))] = {ok: true, body: readStr(ex.$(c.export_name)(...args))}; }
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
      const adescs = $(JSON.json(island.arg_descs));
      const atrees = $(JSON.json(atrees));
      const cdescs = $(JSON.json(cdescs));
      $(Bridge.BUILD_JS)
      $(Bridge.WALK_JS)
      $(TREE_BODY_JS)
      const args = atrees.map((t, j) => build(adescs[j], t));
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
            elseif !_body_match(expected, r["body"])
                failed[c.cell_id] = "initial body mismatch: wasm $(repr(r["body"])[1:min(end,150)]) != original $(repr(expected)[1:min(end,150)])"
            end
        end
        failed
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Asset writing (what the M3 export step ships)
# ─────────────────────────────────────────────────────────────────────────────

# JSON-able raw form of an initial bond value — the shim feeds it through the
# same descriptor-driven coercion as runtime msgpack values.
_initial_json(v::Bool) = v
_initial_json(v::Integer) = -(2^53) <= v <= 2^53 ? Int64(v) : string(v)
_initial_json(v::AbstractFloat) = isfinite(Float64(v)) ? Float64(v) : string(Float64(v))
_initial_json(v::Char) = string(v)
_initial_json(v::String) = v
_initial_json(v::Union{Tuple,AbstractVector}) = Any[_initial_json(x) for x in v]
_initial_json(v) = isstructtype(typeof(v)) ?
    Dict(string(fieldname(typeof(v), i)) => _initial_json(getfield(v, i))
         for i in 1:fieldcount(typeof(v))) : string(v)

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
                    # never-touched bonds from staterequests. "desc" is the
                    # bridge arg descriptor the shim builds values with.
                    "bonds" => [Dict(
                        "name" => string(n),
                        "desc" => d,
                        "initial" => _initial_json(v),
                        # raw widget value ⇒ transformed value (finite widgets
                        # with non-identity transform_value); shim looks up raw
                        "transform" => t === nothing ? nothing :
                            Any[Any[_initial_json(r), _initial_json(tv)] for (r, tv) in t],
                        ) for (n, d, v, t) in zip(island.bond_names, island.arg_descs,
                                                  island.initial_values, island.transforms)],
                    "cells" => [Dict("id" => c.cell_id, "fn" => c.export_name,
                                     "kind" => c.kind, "desc" => c.desc) for c in island.cells],
                )
            end for (k, island) in enumerate(islands)
        ],
    )
    manifest_path = joinpath(dir, "islands.json")
    write(manifest_path, JSON.json(manifest))
    shim = read(joinpath(@__DIR__, "..", "assets", "shim.js"), String)
    write(joinpath(dir, "shim.js"), replace(shim, "//__TREE_BODY_JS__" => TREE_BODY_JS))
    manifest_path
end
