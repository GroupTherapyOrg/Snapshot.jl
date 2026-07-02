### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> title = "Wasm Islands: Success & Failure"
#> date = "2026-07-02"
#> tags = ["wasm", "islands", "diagnostics", "demo"]
#> description = "One slider compiles to a live WebAssembly island; one deliberately fails — showing the compiler-diagnostic card that explains exactly why."

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ bb000001-0000-4000-8000-000000000001
import AbstractPlutoDingetjes.Bonds

# ╔═╡ bb000002-0000-4000-8000-000000000002
md"""
# Wasm islands: a success and a deliberate failure

PlutoIslands compiles the cells behind each `@bind` to WebAssembly so the export
stays interactive without a server. This notebook shows **both outcomes on purpose**:

- the first slider's cells are type-stable Julia → they ship as a **live wasm island**;
- the second slider's cells contain a deliberately type-unstable helper → the compile
  is **refused loudly**, and the export shows a diagnostic card explaining exactly
  which construct failed, in which cell, and why.
"""

# ╔═╡ bb000003-0000-4000-8000-000000000003
begin
	struct RangeSlider
		max::Int
	end
	function Base.show(io::IO, ::MIME"text/html", s::RangeSlider)
		write(io, "<input type=range value=1 min=1 max=$(s.max)>")
	end
	Bonds.initial_value(::RangeSlider) = 1
	Bonds.possible_values(s::RangeSlider) = 1:s.max
end

# ╔═╡ bb000004-0000-4000-8000-000000000004
md"""
## ✅ The success: a typed Collatz walk

Everything below is concretely typed (`Int64` in, `Int64` out) — exactly the strict
subset WasmTarget compiles. Drag the slider: the step count updates live, in-browser.
"""

# ╔═╡ bb000005-0000-4000-8000-000000000005
@bind n RangeSlider(500)

# ╔═╡ bb000006-0000-4000-8000-000000000006
function collatz_steps(m::Int64)::Int64
	steps = Int64(0)
	x = m
	while x != 1
		x = iseven(x) ? x ÷ 2 : 3x + 1
		steps += 1
	end
	steps
end

# ╔═╡ bb000007-0000-4000-8000-000000000007
md"**$(n)** reaches 1 in **$(collatz_steps(Int64(n)))** Collatz steps."

# ╔═╡ bb000008-0000-4000-8000-000000000008
md"""
## ⚡ The deliberate failure: an `Any` grab-bag

The helper below stuffs a slider value, a float, and a *string* into an `Any[]`
container and folds over it — classic type instability. Native Julia shrugs;
WasmTarget **refuses to guess** and reports the exact unsupported construct.
The output cell that depends on it gets the diagnostic card in the export —
note it points back at the *helper* cell, not just the broken output.
"""

# ╔═╡ bb000009-0000-4000-8000-000000000009
@bind k RangeSlider(100)

# ╔═╡ bb00000a-0000-4000-8000-00000000000a
function grab_bag_total(j::Int64)
	items = Any[j, 2.5, "three"]
	total = 0
	for it in items
		total += it isa String ? length(it) : it
	end
	total
end

# ╔═╡ bb00000b-0000-4000-8000-00000000000b
md"the grab-bag total for **$(k)** is **$(grab_bag_total(Int64(k)))**"

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AbstractPlutoDingetjes = "6e696c72-6542-2067-7265-42206c756150"

[compat]
AbstractPlutoDingetjes = "~1.4.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "226dbf2d0529309bb65a3f38c0a4880a96939bce"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"
"""

# ╔═╡ Cell order:
# ╠═bb000001-0000-4000-8000-000000000001
# ╟─bb000002-0000-4000-8000-000000000002
# ╟─bb000003-0000-4000-8000-000000000003
# ╟─bb000004-0000-4000-8000-000000000004
# ╠═bb000005-0000-4000-8000-000000000005
# ╠═bb000006-0000-4000-8000-000000000006
# ╟─bb000007-0000-4000-8000-000000000007
# ╟─bb000008-0000-4000-8000-000000000008
# ╠═bb000009-0000-4000-8000-000000000009
# ╠═bb00000a-0000-4000-8000-00000000000a
# ╟─bb00000b-0000-4000-8000-00000000000b
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
