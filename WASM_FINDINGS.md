# WasmTarget feedback ledger (from the islands work)

The workflow this repo feeds: **improve WT.jl → re-run islands tests + survey →
new gaps land here → back into WT.jl.** Each entry has a deterministic repro
against WasmTarget @ branch `soundness-strict-mode-and-differential-fuzzer`
(local dev path), Julia 1.12.4. When a gap is fixed in WT, delete the
extractor/compiler workaround, re-run `test/islands_*.jl` + `tools/island_survey.jl`,
and strike the entry.

## 1. Sequential-compile state pollution → i64/i32 validation failure  [OPEN]

```julia
import WasmTarget
body_md(x::Int64)::String = "<p>" * string(x^2) * "</p>"   # any string-concat fn
str_len(s::String)::Int64 = Int64(ncodeunits(s))
WasmTarget.compile(body_md, (Int64,))      # OK
WasmTarget.compile(str_len, (String,))     # WasmValidationError: expected i64, found i32
```

- `compile(str_len)` alone in a fresh process: OK. Closure form
  `(s::String) -> Int64(ncodeunits(s))` survives even after the polluter.
  Also reproduces inside a single `compile_multi`.
- Suspect: task-local string-type caches (`_CHAR_ARRAY_TYPE_IDX` etc.,
  `src/codegen/strings.jl`) leaking between compilations.
- The differential fuzzer can't see this class — each differential compiles
  fresh. Suggests a **paired-compile fuzz mode** (compile N functions
  sequentially in one task, validate all).
- Workaround here: closure-form accessors (`src/islands/compile.jl`).

## 2. n-ary string `*` (≥4 operands) traps `unreachable` at runtime  [OPEN]

```julia
f = (x::Int64) -> "doubled is " * string(2x) * ", tripled is " * string(3x)
# compiles + validates fine; TRAPS (unreachable) when called in wasm.
# 3-operand: "a " * string(2x) * " b"            → works
# left-fold:  (("a" * s1) * "b") * s2 …          → works
```

- Caught by the M2 Node initial-body verification (the judgement refused to
  ship it) — exactly the soundness net working.
- NB: this is a *runtime* trap behind a clean validation — wasm-opt
  traps-never-happen would turn it into silent garbage. High-value fuzz
  target: the fuzzer's generator should weight n-ary `string(...)`/`*`
  with ≥4 operands.
- Workaround here: `extract.jl` emits md-splice concats as a left-fold of
  binary `*`.

## 3. PlutoUI `y` group: runtime `unreachable` behind clean validation  [OPEN, unminimized]

The `y` bond group of `test/notebooks/featured/PlutoUI.jl.jl` compiles and
validates, then traps `unreachable` at the Node initial-body verification
(`Node initial-body verification failed: node failed: unreachable`). Caught
and degraded by the judgement. Not yet minimized — reproduce via
`generate_wasm_islands` on that notebook and dump the group's `fn_expr`s.
Same *class* as gap #2 (validates-then-traps), reinforcing the
traps-never-happen hazard note there.

## Survey-ranked WT/extractor work items (from tools/ISLAND_SURVEY.md)

Baseline 2026-06-10: **16/64 bond groups extraction-ok** over 12 featured
notebooks. Ranked blockers:

1. `missing` initial bond values — notebooks whose `@bind` elements lack
   `AbstractPlutoDingetjes.initial_value` (raw-HTML binds) run headless with
   `missing`. Extractor-side: take `first(possible_bond_values)` as the
   initial sample / observe type from `possible_values` eltype. Not a WT gap.
2. NamedTuple / Vector{String} bond values (PlutoUI `combine`, `MultiSelect`)
   — extractor (marshal into args) + WT (struct/vector params at the
   boundary — WasmGC structs exist; needs arg-side constructor wrappers like
   the fuzzer bridge's).
3. Output mimes: `application/vnd.pluto.tree+object` (arrays/dicts — body is
   a STRUCTURED object, needs a tree-body builder, not a string),
   general `text/html` (non-md HTML cells), `image/svg+xml` (plots —
   WasmPlot.jl tier).
