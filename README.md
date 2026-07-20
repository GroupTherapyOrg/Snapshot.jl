<div align="center">

# Snapshot.jl

### Pluto notebooks, interactive as Therapy components. No Julia server.

A **snapshot** of a running notebook: a static export whose interactive cells still run. `@bind`-dependent cells compile to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl). Export a notebook as a **lean [Therapy.jl](https://github.com/GroupTherapyOrg/Therapy.jl) component** (recommended) or as the classic Pluto static HTML — either way the interactive **islands** run entirely in the browser on any static host, with no slider server and no precomputed request files.

[![Docs](https://img.shields.io/badge/docs-live-blue.svg)](https://grouptherapyorg.github.io/Snapshot.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

</div>

## Installation

```julia
import Pkg
Pkg.add("Snapshot")
```

After installation, use `using Snapshot` as shown below. Do not treat notebooks
as data-only inputs: exporting executes their Julia code with the permissions of
the current process. See [Security and trust boundary](#security-and-trust-boundary).

## Quick start

```julia
using Snapshot

# default: a lean Therapy component — cells rendered to HTML at export time + wasm
# islands, no Pluto frontend / baked statefile. Drops into any static host or
# Therapy.jl app, themeable, with or without reactivity.
html = export_notebook("notebook.jl")
# → notebook.html + notebook.islands/   (deploy both together)

# portable: embed the runtime and WASM into one directly openable file
portable = export_notebook("notebook.jl"; single_file=true)
# → notebook.html

# classic: the full Pluto static export with interactive islands
classic_html = export_notebook("notebook.jl"; therapy=false)
# → notebook.html + notebook.islands/   (deploy both together)
```

The ordinary lean and classic formats are static directories rather than
single self-contained files. The classic format includes Pluto's heavier
frontend and statefile, but its Snapshot interactivity still uses the
neighboring `.islands/` directory. Deploy the HTML and that directory together
to any static host. Browsers block those neighboring WASM and JSON assets when
the HTML is opened directly through `file://`; use the portable mode below for
that workflow.

For a portable file that can be opened directly from Finder or Explorer, embed
the Snapshot runtime, island manifest, and WASM modules into the HTML:

```julia
portable = export_notebook("notebook.jl"; single_file=true)
# → notebook.html (no neighboring .islands/ directory)
```

This format trades a larger HTML file for the simplest handoff: copy, upload,
or double-click that one file. Base64 encoding makes embedded binary assets
roughly one third larger. The ordinary directory export remains the efficient
choice for a website, while `single_file=true` is intended for direct sharing.

### Browser requirements and a "moving slider, stuck output"

Snapshot's current WasmTarget modules use WasmGC and the standardized
WebAssembly JavaScript string builtins. Use Chrome or Edge 130+, Firefox 134+,
or another browser with equivalent support. Safari does not currently implement
the required string builtins. This requirement is independent of Windows,
macOS, and Linux.

An older browser can still move a plain HTML slider even though it cannot
compile the adjacent WebAssembly island. The visible symptom is therefore a
moving control with an unchanged, server-rendered plot or value. Current
exports detect the module compilation failure and show an inline browser-update
message with the original technical detail. If an export behaves that way,
first record the browser name and exact version; the Julia and Snapshot package
versions alone do not identify the browser runtime.

Directory exports also tolerate static servers that send `.wasm` with a generic
binary MIME type: Snapshot prefers streaming compilation when the server sends
`application/wasm`, then safely retries from the downloaded bytes otherwise.
This keeps local Python servers and simple educational/static hosts portable
without weakening the browser's WebAssembly validation.

### Hosting from a Therapy site

The default output is already a static directory, so a Therapy application can
serve it without running Pluto or Snapshot in production. Export into a public
directory during the site's build and mount that directory with Therapy's
static-file support:

```julia
# build step (Snapshot environment)
using Snapshot
export_notebook("notebook.jl"; output_dir="public/notebook")

# application (Therapy environment)
using Therapy
app = App()
staticfiles(app, "public/notebook", "notebook")
run(app)
```

The notebook is then available at `/notebook/notebook.html`, with its
neighboring `.islands/` directory served from the same static mount. This keeps
notebook compilation and site serving separate: Therapy does not need Pluto or
Snapshot at runtime.

## How it works

The default, `therapy=true`, emits a lean **Therapy component** — cells rendered
to HTML at export time plus the same wasm islands, no Pluto frontend or baked statefile — themeable
and droppable into any [Therapy.jl](https://github.com/GroupTherapyOrg/Therapy.jl)
app; it's what the [docs gallery](https://grouptherapyorg.github.io/Snapshot.jl/)
serves. Pass `therapy=false` explicitly for the legacy full-Pluto static export.
Both modes use the same island extraction and compilation pipeline.

The exported page uses pinned CDN resources for presentation (DaisyUI themes,
KaTeX, and Lezer syntax highlighting). Notebook content and interactive island
assets are static; if a presentation CDN is unavailable, content and controls
remain present but those enhancements may be absent.

Direct native HTML controls without an authored class or inline style inherit the
active DaisyUI theme, so plain notebook buttons and fields retain a visible,
consistent affordance. Add a class, inline style, or `data-snapshot-unstyled` when
the notebook should own a control's appearance instead.

The shared pipeline is:

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

Pre-1.0 alpha, currently open for small-community testing. Snapshot is available
from Julia's General registry. The featured-notebook gallery in the
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
Host bundles on an origin isolated from authenticated application pages.
[`snapshot.show`](https://snapshot.show) is a separate hosted service built around
Snapshot.jl; it is not part of the package or required to use exported bundles.
The service uses per-owner origins. See [SECURITY.md](SECURITY.md) for reporting
and deployment guidance.

## Related

- [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) — the Julia-to-WasmGC compiler doing the heavy lifting
- [Therapy.jl](https://github.com/GroupTherapyOrg/Therapy.jl) — signals-based Julia web framework (powers the docs site)
- [Pluto.jl](https://github.com/fonsp/Pluto.jl) — the reactive notebook environment the exports come from
- [PlutoSliderServer.jl](https://github.com/JuliaPluto/PlutoSliderServer.jl) — the inspiration: Snapshot answers the same slider-server protocol, locally from wasm instead of from a server

## License

MIT
