### A Pluto.jl notebook ###
# v0.20.28

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

# ╔═╡ dd000001-0000-4000-8000-000000000001
import AbstractPlutoDingetjes.Bonds

# ╔═╡ dd000002-0000-4000-8000-000000000002
begin
	struct MatrixWidget end
	function Base.show(io::IO, ::MIME"text/html", ::MatrixWidget)
		write(io, "<input type=hidden value=m>")
	end
	Bonds.initial_value(::MatrixWidget) = [1.0 2.0 3.0; 4.0 5.0 6.0]
	Bonds.possible_values(::MatrixWidget) = [[1.0 2.0 3.0; 4.0 5.0 6.0], [0.5 0.0; -1.5 2.0], [9.0 -8.0 7.0; 6.0 5.0 -4.0]]
end

# ╔═╡ dd000003-0000-4000-8000-000000000003
@bind M MatrixWidget()

# ╔═╡ dd000004-0000-4000-8000-000000000004
md"""rows=**$(size(M,1))** cols=**$(size(M,2))** first=**$(M[1,1])** last=**$(M[end,end])** sum=**$(sum(M))**"""

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
# ╠═dd000001-0000-4000-8000-000000000001
# ╟─dd000002-0000-4000-8000-000000000002
# ╠═dd000003-0000-4000-8000-000000000003
# ╠═dd000004-0000-4000-8000-000000000004
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
