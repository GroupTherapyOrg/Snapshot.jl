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
or double-click that one file. It is useful for email attachments, downloadable
examples, and platforms that accept active HTML. It is not the preferred web
deployment format: base64 makes binary assets roughly one third larger, every
page load downloads the complete document again, and individual WASM files
cannot be cached. Some learning-management systems also sanitize scripts or
disallow WebAssembly; `single_file=true` cannot override the host's security
policy. Use the ordinary directory export for a website.

### Publishing with Therapy

The default output is already a static directory, so a Therapy application can
mount it without running Pluto or Snapshot in production. Keep the notebook
exporter and site builder in two small environments: Snapshot's Pluto stack and
Therapy currently resolve different HTTP major versions, while the generated
files form a clean boundary between them.

```julia
# snapshot-build/build_notebooks.jl — run when the notebook changes
using Snapshot
export_notebook(
    joinpath(@__DIR__, "..", "notebook.jl");
    output_dir=joinpath(@__DIR__, "..", "therapy-site", "public", "notebook"),
)
```

```julia
# therapy-site/app.jl — an ordinary Therapy application
using Therapy

app = App(
    routes_dir=joinpath(@__DIR__, "routes"),
    components_dir=joinpath(@__DIR__, "components"),
    output_dir=joinpath(@__DIR__, "dist"),
    tailwind=false,
)
staticfiles(app, joinpath(@__DIR__, "public", "notebook"), "notebook")
Therapy.build(app)
```

Run `julia --project=snapshot-build snapshot-build/build_notebooks.jl`, then
`julia --project=therapy-site therapy-site/app.jl` to build the site. The
explicit `Therapy.build(app)` call copies the HTML and its neighboring
`.islands/` directory into `dist/notebook/`
and writes the `.nojekyll` file expected by GitHub Pages. Upload `dist/` with
GitHub's standard Pages action, or deploy it unchanged to any static host.

While developing the site, use `Therapy.dev(app)` instead of
`Therapy.build(app)` to start the local server with hot reload.

For a project Pages URL such as `https://USER.github.io/REPO/`, add
`base_path="/REPO"` to `App`. Snapshot's notebook assets use relative URLs, so
the same exported directory works beneath that prefix. This separation is
intentional: Snapshot executes and compiles the notebook during the build;
Therapy composes and builds the site; the deployed result is only static HTML,
JavaScript, and WebAssembly. No Julia process runs on the host.

Only mount notebook exports you trust on the same origin as an application.
Notebook HTML is author-controlled executable content; publish untrusted
exports on a separate origin so they cannot inherit the application's browser
credentials.

A minimal Pages workflow uses Therapy as the site builder and uploads its
`dist/` directory directly:

```yaml
name: Pages
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: '1.12'
      - uses: julia-actions/cache@v2
      - run: julia --project=snapshot-build -e 'using Pkg; Pkg.instantiate()'
      - run: julia --project=therapy-site -e 'using Pkg; Pkg.instantiate()'
      - run: julia --project=snapshot-build snapshot-build/build_notebooks.jl
      - run: julia --project=therapy-site therapy-site/app.jl
      - uses: actions/configure-pages@v4
      - uses: actions/upload-pages-artifact@v3
        with:
          path: therapy-site/dist
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

Enable **GitHub Actions** as the repository's Pages source once; subsequent
pushes rebuild the notebook, build the Therapy site, and publish the static
result. Put `Snapshot` in `snapshot-build/Project.toml` and `Therapy` in
`therapy-site/Project.toml` so both build stages remain reproducible and their
dependency graphs stay independent.

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
