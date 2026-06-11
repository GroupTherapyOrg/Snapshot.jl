### A Pluto.jl notebook ###
# v0.20.24

# E-004 test notebook: a WasmMakie figure cell driven by a bond. WasmMakie is
# unregistered, so the notebook uses Pluto's documented escape hatch — a
# Pkg.activate cell (disables nbpkg) against a prepared env. runtests.jl
# replaces @@WM_ENV@@ with that env's path before opening.

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
begin
	import Pkg
	Pkg.activate("@@WM_ENV@@"; io=devnull)
	using WasmMakie
end

# ╔═╡ bb000002-0000-4000-8000-000000000002
@bind n html"<input type=range min=1 max=5 value=2>"

# ╔═╡ bb000003-0000-4000-8000-000000000003
begin
	figk = coalesce(n, 2)
	figxs = Float64[]
	figys = Float64[]
	figt = 0.0
	while figt <= 6.3
		push!(figxs, figt)
		push!(figys, sin(figt * Float64(figk)))
		figt += 0.1
	end
	fig = WasmMakie.Figure()
	figax = WasmMakie.Axis(fig[1, 1])
	WasmMakie.lines!(figax, figxs, figys)
	fig
end

# ╔═╡ bb000004-0000-4000-8000-000000000004
md"frequency is $(n)"

# ╔═╡ Cell order:
# ╠═bb000001-0000-4000-8000-000000000001
# ╠═bb000002-0000-4000-8000-000000000002
# ╠═bb000003-0000-4000-8000-000000000003
# ╠═bb000004-0000-4000-8000-000000000004
