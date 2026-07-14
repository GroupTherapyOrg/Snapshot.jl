<div align="center">

# Snapshot.jl

### Pluto notebooks, interactive as Therapy components. No Julia server.

A **snapshot** of a running notebook: a static export whose interactive cells still run. `@bind`-dependent cells compile to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl). Export a notebook as a **lean, self-contained [Therapy.jl](https://github.com/GroupTherapyOrg/Therapy.jl) component** (recommended) or as the classic Pluto static HTML — either way the interactive **islands** run entirely in the browser on any static host, with no slider server and no precomputed request files.

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://grouptherapyorg.github.io/Snapshot.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

</div>

## Quick start

```julia
using Snapshot

# recommended: a lean, self-contained Therapy component — SSR'd cells + wasm
# islands, no Pluto frontend / baked statefile. Drops into any static host or
# Therapy.jl app, themeable, with or without reactivity.
export_notebook("notebook.jl"; therapy=true)

# classic: the full Pluto static export with interactive islands
export_notebook("notebook.jl")
# → notebook.html + notebook.islands/   (serve anywhere static)
```

## How it works

`therapy=true` (recommended) emits a lean **Therapy component** — server-rendered
cells plus the same wasm islands, no Pluto frontend or baked statefile — themeable
and droppable into any [Therapy.jl](https://github.com/GroupTherapyOrg/Therapy.jl)
app; it's what the [docs gallery](https://grouptherapyorg.github.io/Snapshot.jl/)
serves. The default `export_notebook(...)` produces the classic full-Pluto static
export, which works the same way under the hood:

1. **Export time** — the notebook runs once in Pluto. Each group of co-dependent
   `@bind` variables is extracted into pure Julia functions (one per dependent
   cell, upstream code inlined) and compiled to a small WasmGC module.
2. **Verified before shipping** — per cell: original output bodies must
   reproduce byte-exactly under Node, and a **differential oracle** re-runs the
   notebook on sampled bond values and compares against the wasm. Mismatching
   cells don't ship.
3. **In the browser** — a small shim intercepts `fetch` and answers Pluto's
   standard slider-server protocol locally from the wasm. The stock Pluto
   frontend is untouched; slider moves are local WASM calls.
4. **Honest fallbacks** — cells whose bond group can't compile keep their
   original content and are decorated with a Pluto-native `!!! warning`
   admonition explaining exactly why (expandable reasons). Partial islands are
   fine: compiled cells update live, failed cells warn.

### Interactive canvas frame contract

Lean Therapy exports present WasmMakie output with the browser's standard
buffered-rendering model: each cell owns one permanently mounted visible
`<canvas>`, wasm draws a complete frame into a detached `OffscreenCanvas` (or a
detached canvas fallback), and the host copies only the newest complete frame
during `requestAnimationFrame`. Rapid bond updates coalesce to the latest whole
bond snapshot; stale renders are discarded before presentation. The visible
canvas is never replaced or converted to a PNG, so recomputation cannot expose
an empty intermediate DOM state.

This is an implementation of established platform and Makie contracts, not a
Snapshot-specific animation trick:

- [WHATWG Canvas and OffscreenCanvas](https://html.spec.whatwg.org/multipage/canvas.html)
  define the front/back canvas primitives.
- [WHATWG animation frames](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frames)
  define presentation aligned with the browser rendering cycle.
- [Makie Observables and `update!`](https://docs.makie.org/dev/explanations/observables)
  define complete logical updates; Snapshot maps one complete bond snapshot to
  one presented frame.

The wasm module and WasmMakie canvas-import ABI remain host-agnostic. Snapshot
owns scheduling and DOM presentation, just as another embedding host would.

## Integrator API

Exporters with their own run pipeline (e.g. a
[PlutoSliderServer.jl](https://github.com/JuliaPluto/PlutoSliderServer.jl)-style
setup) call the hook on a running notebook instead:

```julia
islands_dirname = generate_wasm_islands(session, notebook, original_state;
                                        output_dir, url_path)
html = inject_islands_script(html, islands_dirname)
```

The non-island bond groups still reach whatever backend you run (precomputed
staterequest files, a live slider server) — the shim passes their requests
through, and `fallback_warnings=false` disables the warnings since those
groups are interactive after all.

## Status

Alpha. The featured-notebook gallery in the
[docs](https://grouptherapyorg.github.io/Snapshot.jl/) shows which notebooks
ship how many islands, and lists the reason for every cell that falls back to
static. Coverage grows with
[WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl); fallback
reasons are tracked as work items in `WASM_FINDINGS.md`.

## Security and trust boundary

`export_notebook` **executes the notebook** in a Pluto workspace before it
compiles and verifies browser islands. Snapshot.jl is an exporter, not a
sandbox: notebook code has the Julia process's filesystem, network, environment,
and subprocess permissions. Export only notebooks and package environments you
trust, use an isolated CI runner with least-privilege credentials, and do not
make secrets available to an untrusted notebook build.

The generated browser bundle contains static HTML, JavaScript, and WebAssembly.
Host bundles on an origin isolated from authenticated application pages; the
snapshot.show service does this with per-owner origins. See [SECURITY.md](SECURITY.md)
for reporting and deployment guidance.

## Related

- [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) — the Julia-to-WasmGC compiler doing the heavy lifting
- [Therapy.jl](https://github.com/GroupTherapyOrg/Therapy.jl) — signals-based Julia web framework (powers the docs site)
- [Pluto.jl](https://github.com/fonsp/Pluto.jl) — the reactive notebook environment the exports come from
- [PlutoSliderServer.jl](https://github.com/JuliaPluto/PlutoSliderServer.jl) — the inspiration: Snapshot answers the same slider-server protocol, locally from wasm instead of from a server

## License

MIT
