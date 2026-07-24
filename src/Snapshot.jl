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

    html = export_notebook("notebook.jl")

    # Portable, directly openable HTML:
    portable = export_notebook("notebook.jl"; single_file=true)

    # Legacy full-Pluto static export:
    classic_html = export_notebook("notebook.jl"; therapy=false)

    # integrators (e.g. a PlutoSliderServer-style exporter) with their own
    # run/export pipeline call the hook on a RUNNING notebook instead:
    generate_wasm_islands(session, notebook, original_state; output_dir, url_path)
"""
module Snapshot

import Pluto
import PlutoDependencyExplorer
import JSON
import NodeJS_24_jll

# Snapshot's export oracle requires WasmGC, exception references, and JS-string
# builtins. Node 24 enables that feature set by default. Keep the bundled
# runtime in one place so neither verifier can accidentally fall back to a
# user's ambient Node.
_verifier_node() = `$(NodeJS_24_jll.node())`

function _verifier_identity()
    version = try
        strip(read(`$(_verifier_node()) --version`, String))
    catch
        "version unavailable"
    end
    "Node $version from NodeJS_24_jll v$(Base.pkgversion(NodeJS_24_jll)) on $(Sys.MACHINE)"
end

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
