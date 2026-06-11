<div align="center">

# PlutoIslands.jl

### Interactive Pluto Exports. No Julia Server.

`@bind`-dependent cells compile to WebAssembly via [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) and ship as **interactive islands** inside the classic static HTML export — sliders work on any static host, with no slider server and no precomputed request files.

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://grouptherapyorg.github.io/PlutoIslands.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

</div>

## Quick start

```julia
using PlutoIslands

export_notebook("notebook.jl")
# → notebook.html + notebook.islands/   (serve anywhere static)
```

## How it works

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

Young and moving fast. The featured-notebook gallery in the
[docs](https://grouptherapyorg.github.io/PlutoIslands.jl/) doubles as the
public scoreboard: which real notebooks ship how many islands, and exactly
why the rest don't yet. Coverage grows with
[WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) — every
fallback reason is a ranked work item (`WASM_FINDINGS.md`).

## Related

- [WasmTarget.jl](https://github.com/GroupTherapyOrg/WasmTarget.jl) — the Julia-to-WasmGC compiler doing the heavy lifting
- [Therapy.jl](https://github.com/GroupTherapyOrg/Therapy.jl) — signals-based Julia web framework (powers the docs site)
- [Pluto.jl](https://github.com/fonsp/Pluto.jl) / [PlutoSliderServer.jl](https://github.com/JuliaPluto/PlutoSliderServer.jl) — the beautiful foundations

## License

MIT
