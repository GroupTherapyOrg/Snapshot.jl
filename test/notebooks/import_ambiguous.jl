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

# ╔═╡ af000001-0000-4000-8000-000000000001
using SnapshotGoodClashFixture

# ╔═╡ af000002-0000-4000-8000-000000000002
using SnapshotPoisonFixture

# ╔═╡ af000003-0000-4000-8000-000000000003
import AbstractPlutoDingetjes.Bonds

# ╔═╡ af000004-0000-4000-8000-000000000004
begin
    struct AmbiguousSlider
        max
    end
    Base.show(io::IO, ::MIME"text/html", s::AmbiguousSlider) =
        write(io, "<input type=range value=1 min=1 max=$(s.max)>")
    Bonds.initial_value(::AmbiguousSlider) = 1
    Bonds.possible_values(s::AmbiguousSlider) = 1:s.max
end

# ╔═╡ af000005-0000-4000-8000-000000000005
@bind x AmbiguousSlider(10)

# ╔═╡ af000006-0000-4000-8000-000000000006
x + 1

# ╔═╡ af000007-0000-4000-8000-000000000007
clash(x)

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
# ╠═af000001-0000-4000-8000-000000000001
# ╠═af000002-0000-4000-8000-000000000002
# ╠═af000003-0000-4000-8000-000000000003
# ╠═af000004-0000-4000-8000-000000000004
# ╠═af000005-0000-4000-8000-000000000005
# ╠═af000006-0000-4000-8000-000000000006
# ╠═af000007-0000-4000-8000-000000000007
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
