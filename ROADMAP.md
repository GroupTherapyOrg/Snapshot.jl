> **ARCHIVED DESIGN RECORD (2026-07-12):** this is not the current release
> plan or a source of implementation status. It is the historical roadmap of the
> PlutoSliderServer.jl fork the islands engine was born in (M0–M5). The fork
> has since been retired; the engine lives here as Snapshot.jl. Kept for
> architectural context only. Repo paths, versions, coverage figures, `OPEN`
> labels, and milestone states below are historical. Current behavior is locked
> by `test/runtests.jl`; current per-export capability is recorded in
> `report.json` and `coverage.json`.

# Therapy Islands Roadmap — Precomputed Slider Servers Without the Precompute

> **Goal.** Exported Pluto notebooks that are interactive with **no Julia server and no
> precomputed file tree**: the `@bind`-dependent slice of the notebook compiles to
> WasmGC via WasmTarget.jl, ships as Therapy.jl-style islands, and runs in the visitor's
> browser. Everything else stays exactly what it is today — a static Pluto HTML export.
> Agreed with Fons (Pluto.jl) 2026-06: fork PlutoSliderServer.jl, reuse all of its
> bind/dependency-tracking machinery, replace the *backend of interactivity*.

This file is a **map, not a script** (same convention as WasmTarget's
`test/fuzz/PHASE1_ROADMAP.md`). Verify claims against the code; some were written
mid-investigation.

---

## STATUS (2026-06-10): M0–M4 DONE, M5 in progress

- **M0 ✅** hand-wired spike PASSES (`demo/m0/`, findings in `demo/m0/FINDINGS.md`).
  Architecture locked: fetch-interception shim, protocol-exact patches, stock
  Pluto frontend untouched.
- **M1 ✅** extraction engine (`src/islands/extract.jl`, `test/islands_extract.jl`).
- **M2 ✅** island compiler + manifest + generalized shim (`src/islands/compile.jl`,
  `src/islands/shim.js`, `test/islands_compile.jl`).
- **M3 ✅** export integration: `export_notebook(…; WasmIslands_enabled=true)`
  works end-to-end, browser-verified (`[WasmIslands]` settings,
  `src/islands/export.jl`, `test/islands_e2e.jl`).
- **M4 ✅** differential oracle (sampled, byte-exact, tamper-proven) + hybrid
  fallback (full bond graph in manifest, shim passthrough for non-island groups,
  `report.json` judgement record) (`src/islands/oracle.jl`, `test/islands_oracle.jl`).
- **WT feedback ledger**: `WASM_FINDINGS.md` — 2 deterministic WT gap repros
  (sequential-compile state pollution; n-ary string concat trap) + survey-ranked
  work items.
- **Corpus + metric**: 12 featured notebooks vendored (`test/notebooks/featured/`),
  `tools/island_survey.jl` → `tools/ISLAND_SURVEY.md`. Baseline: 16/64 groups
  extraction-ok. Ranked movers: (1) NamedTuple/Vector bonds (PlutoUI combine ×
  many), (2) tree+object mime bodies, (3) raw-HTML widget introspection (no
  initial_value/possible_values — un-introspectable even for precompute),
  (4) non-md text/html cells.
- **M5 ✅** (docs milestone, called success 2026-06-10): two-page Therapy.jl docs
  site + featured-notebook gallery LIVE at
  https://dale-black.github.io/PlutoSliderServer.jl/ — notebooks open inside the
  webapp (`NotebookPage` iframe routes, BasisSimulator pattern), frontmatter
  cover images, Pages CI on `Dale-Black/PlutoSliderServer.jl` (push both
  remotes). Exports pre-rendered + committed (`docs/export_notebooks.jl`,
  hash-cached); gallery: 3 interactive (PlutoUI = 10 islands) · 11 static.
  **Name stays PlutoSliderServer.jl** — rename remains deferred, user's call.
- **Per-cell granularity + fallback warnings (post-M5, Dale's ask)**: compile,
  Node-verify, and oracle are now PER-CELL — partial islands ship (surviving
  cells update live; failed cells keep original content). The shim decorates
  exactly the failed cells with Pluto-native `!!! warning` admonitions
  (admonition CSS Pluto already ships) + a "why?" expander showing the real
  compile/oracle reasons from report.json. Gated by manifest
  `fallback_warnings` (auto-false when a precompute/live backend serves those
  groups). Registry deps: WasmTarget 0.2 + Therapy 0.1.1 (no more dev paths /
  URL sources).
- **NEXT (M6 breadth — the island-rate movers, survey/report-ranked)**:
  NamedTuple bonds (PlutoUI `combine`; pairs with WT struct-boundary work) →
  String bonds → tree+object output bodies → non-md text/html cells → WT gap
  fixes #1–#3 (`WASM_FINDINGS.md`) → re-export, watch the interactive count
  climb on the live gallery.

## 0. Where this branch starts

`therapy-islands` is based on **upstream PR #29** (`static-export-1`, "Precompute all
possible slider states") — the precompute machinery is in-tree and is our scaffold:

| Existing piece (this repo) | What it does | Fate under wasm islands |
|---|---|---|
| `src/MoreAnalysis.jl` `bound_variable_connections_graph` | groups co-dependent bound vars via notebook topology | **reused verbatim** — islands are per-group |
| `src/run_bonds.jl` `run_bonds_get_patches` | set bonds → reactively rerun → Firebasey diff vs original state | reused at *export time* for validation oracle + fallback precompute |
| `src/precomputed/index.jl` | enumerates `Pluto.possible_bond_values` cartesian products per group, writes `staterequest/<hash>/<b64url(pack(bonds))>` files | becomes the **fallback tier**; wasm islands replace it for compilable groups |
| `src/precomputed/types.jl` `Judgement` | per-group decision: precompute-all vs too big vs unavailable | **pattern extended**: a new `IslandJudgement` (compilable / fallback-precompute / fallback-live / static) |
| `src/Actions.jl` `generate_static_export` | runs notebook, renders Pluto HTML export + statefile | extended to also emit island bundles + loader injection |
| `src/HTTPRouter.jl` | live slider server (`staterequest`, `bondconnections` endpoints) | untouched; live mode remains an option |

Key upstream facts (verified in source):

- **The wire protocol** (`Pluto.jl/frontend/common/SliderServerClient.js`): client computes
  the explicit-bond downstream closure from `cell_dependencies`, fetches
  `staterequest/<notebook_hash>/<base64url(msgpack(filtered_bonds))>`, receives
  `{patches}` (Firebasey/immer JSON-patch against the *original statefile state*), applies
  them with a reset-to-original trick for affected cells. `set_bond` is the single entry
  point. **This is the seam we swap.**
- **Bond enumeration**: `AbstractPlutoDingetjes.Bonds.possible_values` (finite or
  `InfinitePossibilities`) is only needed by the precompute tier. Wasm islands have **no
  finite-domain requirement** — continuous sliders, text inputs, infinite domains all work,
  which precompute fundamentally cannot do.
- **Cell outputs are MIME bodies** in `cell_results[id].output.body` (text/html or
  text/plain). Whoever produces a new body string can drive Pluto's own renderer via
  the existing patch path. We do NOT need Therapy's DOM hydration to repaint outputs.

## 1. The architecture in one paragraph

At export time the notebook is **running** in Pluto on the build machine (PSS already does
this). For each bond-connection group, we extract the dependent cell chain as a pure Julia
function `group_fn(bond_values...) -> (output_body_strings...)` — upstream non-bound
dependencies are baked in as constants from the live workspace. We compile `group_fn` plus
a Therapy-style reactive shell (bond signals → per-cell memos → string outputs) to a small
WasmGC module via WasmTarget. The exported HTML loads a thin JS shim that implements the
`slider_server_actions` interface: `set_bond` writes the signal in WASM, reads back the
recomputed output bodies, wraps them into the *same* `{patches}` shape, and feeds Pluto's
`apply_notebook_patches`. Pluto's editor renders exactly as if a slider server had
responded — but the round-trip is a local WASM call. Groups that fail island compilation
fall back per-group to precompute (PR #29) or a live server; the export is a **hybrid**.

```
                       ┌──────────── export time (Julia, build machine) ───────────┐
 notebook.jl ─ Pluto ──┤ original_state ──► HTML + statefile   (unchanged)          │
                       │ bond_connections ──► groups                                │
                       │ per group: extract group_fn ─ WasmTarget ─► island.wasm/js │
                       │           └─ IslandJudgement: compilable? else precompute  │
                       └────────────────────────────────────────────────────────────┘
                       ┌──────────── visit time (browser, no Julia) ────────────────┐
 slider moved ─ set_bond ─► WASM signal set ─► memos recompute ─► body strings      │
              ◄─ {patches} shaped like a staterequest response ─ JS shim            │
 Pluto editor applies patches, repaints cells (same code path as today)             │
                       └────────────────────────────────────────────────────────────┘
```

## 2. Why the pieces already exist (the bet)

- **WasmTarget.jl** compiles real Base Julia (176+ fns, closures, structs, strings,
  collections, control flow, try/catch) and is being driven to *full core-1.12 compat* by
  the differential fuzzer (Phase 2, 23 open gaps at time of writing). Crucially its
  **strict mode refuses to emit unsound code** — compile failure is detectable, which is
  what makes the per-group fallback judgement *trustworthy* rather than hopeful.
- **Therapy.jl** already has: signals-as-WASM-globals, the Leptos-parity reactive runtime
  *itself compiled by WasmTarget* (`WasmReactiveRuntime.jl`), deferred JS import proxies
  for string outputs (`str_fns` pattern — exactly what cell bodies need), the
  `prebaked_dir` manifest format for shipping baked island bundles, and
  `compile_closure_body`/`compile_function_into!` plumbing against typed IR.
- **PlutoSliderServer** already has: group analysis, downstream-closure computation
  (mirrored in JS!), the patch protocol, export orchestration, CI templates.

What does NOT exist anywhere yet: cell-chain → function extraction, workspace-constant
baking, MIME rendering inside WASM, and the JS shim. That's the new work.

## 3. Workstreams

### 3A. Cell-chain extraction (`group_fn` codegen) — the heart
For a bond group `G` with bound vars `bs` and dependent cells `C₁..Cₙ` (topological
order from `PlutoDependencyExplorer`):
- Parse each cell's expr (we have the .jl source and the live topology). Strip the
  `@bind` macro from defining cells — the bound var becomes a function parameter.
- Classify every free variable of the chain: (a) bound in `G` → parameter; (b) defined
  by an upstream non-bond cell → **bake as constant** by fetching its *value* from the
  live workspace; (c) module/global (Base etc.) → leave to WT's resolution.
- Emit `function group_fn(b1::T1, …) … return (body₁, …, bodyₙ) end` where each `bodyᵢ`
  is the *rendered output* of cell `i` (see 3C) and `Tᵢ` are concrete types observed from
  the initial bond values (`transform_value` applied — see 3D).
- **Open question**: constant baking needs values to be WT-compilable constants
  (isbits, strings, arrays/structs thereof). A `DataFrame` upstream of a slider chain
  → group is not island-compilable → fallback. The judgement must detect this cheaply.
- **Open question**: where does compilation run? PSS workspaces live in Malt worker
  processes. Either fetch values into the PSS process and compile there (needs the cell
  exprs re-evaluated — wrong for stateful cells), or inject WasmTarget into the worker
  and compile in-workspace (`WorkspaceManager.eval_fetch_in_workspace` returning wasm
  bytes). The latter is more correct; start with the former for the prototype.

### 3B. The reactive shell (Therapy machinery, minus the VNode part)
Per island: one signal per bound var in the group, one memo per dependent cell
(the cell's body-string computation), the i64-bitset reactive runtime from Therapy's
`WasmReactiveRuntime.jl`. No DOM bindings, no hydration cursor — the only output channel
is "memo recomputed → hand the string to JS" via a `str_fns`-style deferred import.
This is a *simpler* island than Therapy's `@island` (no VNode tree, no event wiring —
Pluto's bond widgets fire events, the shim calls exports). Likely shape: a new
`Therapy.compile_headless_island(signals, memos) -> bytes + loader` API, or a local
copy in this repo first and upstream to Therapy.jl once stable.

### 3C. Output rendering inside WASM (tiered)
Native Pluto renders cell values via MIME show on the server. Client-side we must
reproduce the body string:
- **Tier 1 — text/plain**: `repr(value)` for numbers/strings/simple structs. Needs WT's
  `string(::Float64)` (Ryu — already landed in Phase 2 batches), `string(::Int)`, etc.
- **Tier 2 — text/html via interpolation**: `md"x is $(x)"` / `html"…"` / HTML string
  building. Markdown *structure* is static per cell; only interpolated slots change →
  precompute the static HTML skeleton at export, compile just the slot expressions, do
  string splicing in WASM (cheap, robust, avoids compiling Markdown.jl).
- **Tier 3 — plots**: WasmPlot.jl for supported plot types (canvas via externref).
  Out of scope for v0; design the body-string channel so a canvas-painting island can
  slot in later (`<canvas>` body + post-patch paint hook).
- **Tier 4 — everything else**: not island-compilable → fallback tier.

### 3D. Bond value semantics
- `transform_value` (AbstractPlutoDingetjes) runs between the raw JS widget value and
  the Julia variable. Compile it into the island (it's Julia), or evaluate its effect
  at export for the identity/known-widget cases (PlutoUI Slider sends the actual value).
- Bond-defines-bond (`@bind y Slider(x:100)`) — upstream handles this with the
  `explicit` query param and bond-reset patches (#163/#3158). Island equivalent: the
  shim must re-read *recreated* bond definitions after a run. v0: detect such groups
  and route them to fallback; revisit after the basic path is solid.
- Initial values: `Bonds.initial_value` gives the signal init; types observed there
  fix the WT signature.

### 3E. The JS shim (`WasmIslandClient.js`)
A sibling of `SliderServerClient.js` (~250 lines, well understood):
- Same `set_bond` debounce + downstream-closure bookkeeping (copy it).
- Instead of `fetch(staterequest/…)`: `island.exports.set_<bond>(value)` (or setter
  index), collect changed `(cell_id, body)` pairs from the str_fns callbacks, build
  `{patches: [{op:"replace", path:["cell_results", id, "output", "body"], value: body}, …]}`
  plus `last_run_timestamp` touches, then the existing immer apply.
- Loader: Therapy's island loader pattern (inline-WASM-bytes JS, instantiate, wire
  deferred imports), keyed by group id in a manifest next to the statefile:
  `<notebook>.islands/{manifest.toml, group_<k>.js}`.
- Injection: `generate_static_export` already controls `Pluto.generate_html(...)`
  params. Add `wasm_islands_js` analogous to `slider_server_url_js`; needs a small
  upstream Pluto PR (Fons is on board) — or v0: post-process the HTML string to inject
  a `<script type=module>` that registers the actions object before the editor boots.
  **Decision: post-process first, upstream PR once the shape is proven.**

### 3F. The judgement & hybrid export
Extend `precomputed/types.jl` pattern:
```
IslandJudgement per group =
    island        (group_fn extracted + WT strict-compiles + oracle check passes)
  | precompute    (finite possibilities && within filesize budget)   [PR #29 path]
  | live          (slider server configured)
  | static        (none of the above — cells just don't update)
```
**Oracle check (non-negotiable):** at export time, for a sample of bond combinations
(reuse the precompute sampler in `precomputed/index.jl`), run the value through BOTH the
live notebook (`run_bonds_get_patches`) and the compiled island (via Node, the same
harness WT's differential fuzzer uses) and compare body strings. A mismatch demotes the
group to fallback. This is the same native-vs-wasm differential discipline as
WasmTarget's fuzzer — islands ship only when *proven* equivalent on the sample.

### 3G. Config & CLI surface
New `[WasmIslands]` section in `PlutoDeployment.toml` mirroring `[Precompute]`:
`enabled`, `fallback` (`precompute|live|static`), `oracle_sample_size`,
`max_island_size`, `exclude` globs. `export_notebook`/`export_directory` keywords:
`WasmIslands_enabled=true`. Keep defaults conservative (off) until M5.

## 4. Milestones (sequenced)

1. **M0 — spike, zero plumbing (1 notebook, by hand).** A 3-cell notebook
   (`@bind x Slider(1:100)`; `y = x^2`; `md"**y** is $(y)"`). Hand-write `group_fn`,
   compile with WT + a hand-rolled signal global, hand-inject the shim into the
   exported HTML, verify the slider updates the markdown cell offline in a browser.
   *Proves the seam end-to-end; surfaces the first WT gaps.* Deliverable: a `demo/`
   dir in this repo + a findings note.
2. **M1 — extraction engine.** `src/islands/extract.jl`: topology → group_fn expr,
   constant baking with compilability check, concrete type observation. Tested against
   the PR #29 test notebooks (`test/notebooks/basic3.jl`, `parallelpaths4.jl`) — these
   already encode the gnarly dependency shapes.
3. **M2 — headless island compiler.** `src/islands/compile.jl` (or
   `Therapy.compile_headless_island`): signals + per-cell memos + str_fns outputs +
   reactive runtime → `.wasm` + loader JS + manifest. Round-trip test under Node
   (reuse WT's `wasm_runner` harness pattern).
4. **M3 — shim + export integration.** `WasmIslandClient.js`, HTML post-processing in
   `generate_static_export`, manifest discovery, `set_bond` → patches → repaint. E2E
   test with Playwright (Therapy already has the harness pattern) — *no network, no
   Julia*: assert interaction works with the file served statically.
5. **M4 — judgement + hybrid + oracle.** `IslandJudgement`, per-group fallback to
   precompute/live/static, export-time differential oracle, report printing (reuse
   `PrecomputedSampleReport` rendering).
6. **M5 — breadth.** Tier-2 markdown splicing generalized; PlutoUI widget matrix
   (Slider, NumberField, CheckBox, TextField, Select, Button-as-counter…);
   `transform_value` compilation; docs + a public template repo
   (static-export-template fork) → demo site on GitHub Pages; upstream conversation
   with Fons re: `generate_html` param + possibly moving the shim into Pluto.
7. **M6 — stretch.** WasmPlot Tier-3 outputs; bond-defines-bond; `Resource`-style async
   cells; upstreaming the headless island API into Therapy.jl proper.

## 5. Definition of done (v0 = end of M5)

- [ ] `export_notebook(nb; WasmIslands_enabled=true)` produces either a directory
  served by any HTTP static host or a portable `single_file=true` export opened
  through `file://`, with working sliders and **zero** Julia
  processes and **zero** precomputed staterequest files for island-judged groups.
- [ ] Every shipped island passed the export-time differential oracle on a random
  sample of its bond domain; non-passing groups visibly fell back (report says why).
- [ ] The PR #29 precompute path still works and is the automatic fallback.
- [ ] The classic MIT computational-thinking demo notebook (or equivalent
  slider-heavy notebook) exports with ≥1 real group as an island.
- [ ] CI: extraction unit tests + Node round-trip + one Playwright E2E, all green.

## 6. Risks / open questions (carry into M0)

- **WT coverage vs notebook reality.** Real notebooks lean on Base breadth; the Phase-2
  fuzzer ledger is the ground truth for what compiles soundly. The judgement turns
  coverage holes into fallbacks, not bugs — but if *most* real groups fall back, the
  feature underwhelms. M0/M1 should measure: take 10 featured Pluto notebooks, report
  the would-be island rate. This number drives WT Phase-2 prioritization too —
  a virtuous loop (notebook corpus → WT gap ledger).
- **Workspace value extraction** (3A): stateful/large upstream values. Mitigation:
  strict isbits/string/array allowlist for baked constants in v0.
- **Pluto frontend coupling**: the shim mimics an internal interface
  (`slider_server_actions`). Pin the Pluto version in exports (PSS already bakes
  `pluto_version` into the HTML); coordinate the seam with Fons early (he proposed
  this collaboration — use it).
- **Module init cost in browser**: WT modules are 1–5 KB for Therapy islands but
  group_fns with string/Dict machinery pull in more of the runtime. Budget per island
  (`max_island_size`), measure in M0.
- **Naming**: this fork may deserve a new name (PlutoWasmServer? Snapshot.jl) once
  it diverges — defer until after M3; staying a fork keeps upstream merges cheap.
