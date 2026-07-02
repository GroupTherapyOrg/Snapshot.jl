# Featured-notebook corpus

Vendored from [JuliaPluto/featured](https://github.com/JuliaPluto/featured) at commit
`a1b1a0f456015eaec6ec49fe39aa65b696c0129c` (2026-06). Each notebook carries its own
licence in its frontmatter (`#> license = ...`, predominantly Unlicense — see the
upstream `LICENSES/` directory).

This is the **standing test corpus for the wasm-islands work** (see
`THERAPY_ISLANDS_ROADMAP.md`): real, slider-heavy notebooks used to

1. measure the **island-compilable rate** — what fraction of bond groups the
   extraction engine (M1) + WasmTarget can compile, vs falling back to
   precompute/live/static;
2. drive the **WasmTarget feedback loop** — every group that fails to compile or
   fails the differential oracle is a concrete WT Phase-2 work item;
3. eventually run **interactively as wasm islands in the Snapshot.jl docs site**
   (M5).

Selection spans difficulty tiers: plain-arithmetic binds (`Basic mathematics`,
`CollatzConjecture`), markdown/string interpolation (`newton`), array/image kernels
(`convolution_1d/2d`, `images`, `dither`, `fractals`), widget breadth (`PlutoUI.jl`),
dependency-free HTML binds (`Interactivity with HTML`), package-heavy
(`turtles-art`, `Titration`).

Re-vendor with a newer upstream commit deliberately, not casually — coverage-rate
numbers are only comparable against a fixed corpus.
