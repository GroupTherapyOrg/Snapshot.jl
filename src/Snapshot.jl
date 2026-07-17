"""
    Snapshot

Interactive Pluto notebook exports with **no Julia server**: `@bind`-dependent
cells compile to WebAssembly (via WasmTarget.jl) and ship as *islands* inside
a lean Therapy component by default. In the browser, a small runtime connects
the exported inputs directly to the wasm islands.

Every island is verified before it ships: original output bodies must
reproduce byte-exactly under Node, and a differential oracle compares the
wasm against real notebook re-runs on sampled bond values — per cell. Cells
whose bond group cannot compile keep their original content and are decorated
with a Pluto-native warning explaining exactly why.

# The two-level API

    export_notebook("notebook.jl")
    # → notebook.html + notebook.islands/   (serve anywhere static)

    # Legacy full-Pluto static export:
    export_notebook("notebook.jl"; therapy=false)

    # integrators (e.g. a PlutoSliderServer-style exporter) with their own
    # run/export pipeline call the hook on a RUNNING notebook instead:
    generate_wasm_islands(session, notebook, original_state; output_dir, url_path)
"""
module Snapshot

import Pluto
import PlutoDependencyExplorer
import JSON

include("types.jl")
include("analysis.jl")
include("run_bonds.jl")
include("extract.jl")
include("imagecells.jl")
include("compile.jl")
include("oracle.jl")
include("pluto_css.jl")
include("exporter.jl")

export export_notebook, generate_wasm_islands, inject_islands_script
export extract_groups, compile_group, differential_oracle, write_island_assets
export ExtractedGroup, CompiledIsland, OracleResult, RunningNotebook
export bound_variable_connections_graph

end # module
