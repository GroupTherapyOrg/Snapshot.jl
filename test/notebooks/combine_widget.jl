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

# ╔═╡ bb000001-0000-4000-8000-000000000001
import AbstractPlutoDingetjes.Bonds

# ╔═╡ bb000002-0000-4000-8000-000000000002
begin
	# combine()-shaped widget: multiple <input> children, the client sends a
	# Vector of child values, transform_value reshapes it server-side. No
	# usable initial_value → the pipeline must introspect the rendered html
	# (and the defining cell below SUPPRESSES its output with `;`, so the html
	# can only come from the workspace's bond registry).
	struct DuoWidget end
	function Base.show(io::IO, ::MIME"text/html", ::DuoWidget)
		write(io, "<span><input type=color value=\"#aabbcc\"><input type=range min=1 max=3 value=2></span>")
	end
	Bonds.initial_value(::DuoWidget) = missing
	Bonds.transform_value(::DuoWidget, raw) = raw === missing ? missing : (color=string(raw[1]), n=Int(raw[2]))
end

# ╔═╡ bb000003-0000-4000-8000-000000000003
duo_widget = @bind duo DuoWidget();

# ╔═╡ bb000004-0000-4000-8000-000000000004
duo === missing ? "color #aabbcc n 2" : "color $(duo.color) n $(duo.n)"

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
# ╠═bb000002-0000-4000-8000-000000000002
# ╠═bb000003-0000-4000-8000-000000000003
# ╠═bb000004-0000-4000-8000-000000000004
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
