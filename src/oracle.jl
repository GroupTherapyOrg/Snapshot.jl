# islands/oracle.jl — M4: export-time differential oracle
#
# Before an island ships, sample its bond domain and require the wasm island's
# body strings to BYTE-EXACTLY match a real notebook re-run (the same
# machinery a live slider server uses). Same discipline as WasmTarget's
# differential fuzzer: islands are proven equivalent on the sample, or they
# don't ship.
#
# v0 scope: samples are drawn from `Pluto.possible_bond_values` (finite
# domains — the same source the precomputed slider server trusts). Groups
# with infinite/unavailable domains keep only the initial-body verification
# and are flagged in the report.

import Pluto
import JSON
import Random
import WasmTarget


Base.@kwdef struct OracleResult
    ok::Bool                                   # no global failure AND no cell failed
    samples_run::Int
    skipped_reason::Union{Nothing,String} = nothing
    mismatch::Union{Nothing,String} = nothing  # GLOBAL failure (native run died etc.)
    # per-cell mismatches/traps — these cells get excluded from the island
    failed_cells::Dict{String,String} = Dict{String,String}()
end

# ─────────────────────────────────────────────────────────────────────────────
# Sampling
# ─────────────────────────────────────────────────────────────────────────────

"Draw up to `n` random bond-value combinations from finite possible_values."
function _sample_combinations(
    session::Pluto.ServerSession,
    notebook::Pluto.Notebook,
    g::ExtractedGroup,
    n::Int,
    rng,
)::Union{Vector{Vector{Any}},String}
    domains = Vector{Any}[]
    for name in g.bond_names
        result = try
            Pluto.possible_bond_values(session, notebook, name)
        catch e
            return "possible_bond_values($(name)) failed: $(typeof(e))"
        end
        result isa Symbol && return "possible_bond_values($(name)) → $(result)"
        vals = collect(Any, result)
        isempty(vals) && return "possible_bond_values($(name)) is empty"
        length(vals) > 10_000 && (vals = vals[1:10_000])  # don't materialize huge domains
        push!(domains, vals)
    end
    [Any[rand(rng, d) for d in domains] for _ in 1:n]
end

# ─────────────────────────────────────────────────────────────────────────────
# Native side (ground truth)
# ─────────────────────────────────────────────────────────────────────────────

"Run the notebook with the given bond values; return cell_id → new body
(String for text mimes, Dict for tree+object)."
function _native_bodies(
    session::Pluto.ServerSession,
    run::RunningNotebook,
    g::ExtractedGroup,
    combo::Vector,
)::Union{Dict{String,Any},String}
    bonds = Dict{Symbol,Any}(
        n => Dict{String,Any}("value" => v) for (n, v) in zip(g.bond_names, combo)
    )
    result = run_bonds_get_patches(session, run, bonds, nothing)
    result === nothing && return "run_bonds_get_patches returned nothing"
    bodies = Dict{String,Any}()
    for patch in result.patches
        patch isa Pluto.Firebasey.ReplacePatch || continue
        p = patch.path
        (length(p) == 4 && p[1] == "cell_results" && p[3] == "output" && p[4] == "body") || continue
        (patch.value isa String || patch.value isa AbstractDict) && (bodies[string(p[2])] = patch.value)
    end
    bodies
end

# ─────────────────────────────────────────────────────────────────────────────
# Wasm side (one Node invocation for all samples)
# ─────────────────────────────────────────────────────────────────────────────

# best-effort coercion of a possible_bond_values sample to the observed arg
# type (domains often yield Int where Float64 is observed, etc.)
_coerce_sample(T::Type, v) = v isa T ? v : try convert(T, v) catch; v end

"Evaluate every (sample, cell) under Node; returns sample_idx ⇒ cell_id ⇒ body."
function _wasm_bodies(
    island::CompiledIsland,
    samples::Vector{Vector{Any}},
)::Union{Vector{Dict{String,Any}},String}
    # one tagged tree per (sample, bond); built in-module via bridge ctors
    sample_trees = [
        Any[WasmTarget.Bridge.value_to_tree(island.arg_descs[j],
                _coerce_sample(island.arg_types[j], combo[j]))
            for j in eachindex(island.arg_descs)]
        for combo in samples
    ]
    cdescs = Dict(c.cell_id => c.desc for c in island.cells if c.kind == "tree")
    calls = String[]
    for (si, _) in enumerate(samples)
        for c in island.cells
            body_js = c.kind == "tree" ?
                "pluto_tree_body(cdescs[$(repr(c.cell_id))], walk(cdescs[$(repr(c.cell_id))], ex.$(c.export_name)(...args)))" :
                "readStr(ex.$(c.export_name)(...args))"
            push!(calls, """  { const args = strees[$(si - 1)].map((t, j) => build(adescs[j], t));
      try { out[$(si - 1)][$(repr(c.cell_id))] = {ok: true, body: $(body_js)}; }
      catch (e) { out[$(si - 1)][$(repr(c.cell_id))] = {ok: false, err: String(e && e.message || e)}; } }""")
        end
    end
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
      const strees = $(JSON.json(sample_trees));
      const cdescs = $(JSON.json(cdescs));
      $(WasmTarget.Bridge.BUILD_JS)
      $(WasmTarget.Bridge.WALK_JS)
      $(TREE_BODY_JS)
      const out = Array.from({length: $(length(samples))}, () => ({}));
    $(join(calls, "\n"))
      console.log(JSON.stringify(out));
    })().catch(e => { console.error(String(e && e.stack || e)); process.exit(1); });
    """
    mktempdir() do dir
        wasm_path = joinpath(dir, "island.wasm")
        js_path = joinpath(dir, "oracle.cjs")
        write(wasm_path, island.bytes)
        write(js_path, script)
        out = IOBuffer(); errio = IOBuffer()
        ok = success(pipeline(`node $js_path $wasm_path`; stdout=out, stderr=errio))
        ok || return "node failed: $(String(take!(errio))[1:min(end, 300)])"
        raw = JSON.parse(String(take!(out)))
        [Dict{String,Any}(k => v for (k, v) in sample) for sample in raw]
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# The oracle
# ─────────────────────────────────────────────────────────────────────────────

"""
    differential_oracle(session, notebook, original_state, connections, g, island;
                        samples=5, rng) -> OracleResult

Compare wasm island bodies against real notebook re-runs on sampled bond
combinations. Restores initial bond values afterwards.
"""
function differential_oracle(
    session::Pluto.ServerSession,
    notebook::Pluto.Notebook,
    original_state::Dict,
    connections::Dict{Symbol,Vector{Symbol}},
    g::ExtractedGroup,
    island::CompiledIsland;
    samples::Int=5,
    rng=Random.Xoshiro(0x15ADD5),
)::OracleResult
    combos = _sample_combinations(session, notebook, g, samples, rng)
    combos isa String &&
        return OracleResult(; ok=true, samples_run=0, skipped_reason=combos)

    wasm = _wasm_bodies(island, combos)
    wasm isa String &&
        return OracleResult(; ok=false, samples_run=0, mismatch="wasm eval failed: $(wasm)")

    run = RunningNotebook(;
        path=notebook.path, notebook, original_state, bond_connections=connections)

    # per-cell verdicts: collect every failing cell across all samples
    failed_cells = Dict{String,String}()
    global_mismatch = nothing
    samples_run = 0
    for (si, combo) in enumerate(combos)
        native = _native_bodies(session, run, g, combo)
        if native isa String
            global_mismatch = "native run failed at sample $(si) $(combo): $(native)"
            break
        end
        samples_run = si
        for c in island.cells
            haskey(failed_cells, c.cell_id) && continue
            r = get(wasm[si], c.cell_id, nothing)
            if r === nothing || !r["ok"]
                failed_cells[c.cell_id] =
                    "wasm trapped at $(g.bond_names)=$(combo): $(r === nothing ? "missing" : r["err"])"
                continue
            end
            real = get(native, c.cell_id, nothing)
            # native may omit a cell whose body didn't change vs current state;
            # only compare when ground truth is present
            real === nothing && continue
            if !_body_match(real, r["body"])
                failed_cells[c.cell_id] =
                    "oracle mismatch at $(g.bond_names)=$(combo): wasm $(repr(r["body"])[1:min(end,120)]) != native $(repr(real)[1:min(end,120)])"
            end
        end
    end
    result = OracleResult(;
        ok=global_mismatch === nothing && isempty(failed_cells),
        samples_run, mismatch=global_mismatch, failed_cells)

    # restore initial bond values (politeness for keep_running / later groups)
    try
        _native_bodies(session, run, g, Vector{Any}(g.initial_values))
    catch
    end

    result
end
