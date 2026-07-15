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

# ╔═╡ ac000002-0000-4000-8000-000000000002
using Statistics

# ╔═╡ ac000007-0000-4000-8000-000000000007
import Base: abs as magnitude

# ╔═╡ ac000003-0000-4000-8000-000000000003
import AbstractPlutoDingetjes.Bonds

# ╔═╡ ac000004-0000-4000-8000-000000000004
begin
    struct SoftscopeSlider
        max
    end
    Base.show(io::IO, ::MIME"text/html", s::SoftscopeSlider) =
        write(io, "<input type=range value=1 min=1 max=$(s.max)>")
    Bonds.initial_value(::SoftscopeSlider) = 1
    Bonds.possible_values(s::SoftscopeSlider) = 1:s.max
end

# ╔═╡ ac000005-0000-4000-8000-000000000005
@bind x SoftscopeSlider(10)

# ╔═╡ ac000006-0000-4000-8000-000000000006
mean((x, x + 2)) + magnitude(x - 3)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AbstractPlutoDingetjes = "6e696c72-6542-2067-7265-42206c756150"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
AbstractPlutoDingetjes = "~1.4.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "82d110e841d4a894128aab99e8e9ec79318ab228"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"
"""

# ╔═╡ Cell order:
# ╠═ac000002-0000-4000-8000-000000000002
# ╠═ac000007-0000-4000-8000-000000000007
# ╠═ac000003-0000-4000-8000-000000000003
# ╠═ac000004-0000-4000-8000-000000000004
# ╠═ac000005-0000-4000-8000-000000000005
# ╠═ac000006-0000-4000-8000-000000000006
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
