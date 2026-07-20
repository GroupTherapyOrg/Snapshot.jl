using Snapshot

length(ARGS) == 1 || error("usage: windows_portable_smoke.jl <output-dir>")
out = abspath(ARGS[1])
mkpath(out)
html = export_notebook(joinpath(@__DIR__, "notebooks", "demo.jl");
                       output_dir=out, single_file=true)
isfile(html) || error("portable export was not written: $html")
occursin("__snapshotEmbeddedAssets", read(html, String)) ||
    error("portable export did not embed its browser assets")
println(html)
