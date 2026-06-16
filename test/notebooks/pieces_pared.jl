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

# ╔═╡ cc000001-0000-4000-8000-000000000001
function pieces(n)
	return n
end

# ╔═╡ cc000002-0000-4000-8000-000000000002
begin
	correct(text=md"Great! You got the right answer!") = Markdown.MD(Markdown.Admonition("correct", "Got it!", [text]))
	keep_working(text=md"The answer is not quite right.") = Markdown.MD(Markdown.Admonition("danger", "Keep working on it!", [text]))
end

# ╔═╡ cc000003-0000-4000-8000-000000000003
md"""Move the slider to change the number of cuts:

$(@bind n html"<input type=range max=50>")"""

# ╔═╡ cc000004-0000-4000-8000-000000000004
if pieces(n) ==  n * (n + 1) / 2 + 1
	md"""_Testing..._

	**For $n cuts, you predict $(pieces(n)) pieces.**

	$(correct(md"Well done!"))"""
else
	md"""_Testing..._

	**For $n cuts, you predict $(pieces(n)) pieces.**

	$(keep_working(md"The answer should be $(Int(n*(n+1)/2+1))."))"""
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "71853c6197a6a7f222db0f1978c7cb232b87c5ee"

[deps]
"""

# ╔═╡ Cell order:
# ╟─cc000001-0000-4000-8000-000000000001
# ╟─cc000002-0000-4000-8000-000000000002
# ╠═cc000003-0000-4000-8000-000000000003
# ╠═cc000004-0000-4000-8000-000000000004
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
