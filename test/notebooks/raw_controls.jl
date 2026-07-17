### A Pluto.jl notebook ###
# v0.20.28

using Markdown
using InteractiveUtils

# ╔═╡ d1000000-0000-4000-8000-000000000001
interpolation_value = 3

# ╔═╡ d1000001-0000-4000-8000-000000000001
Base.HTML("""
<button>Click me!</button>
<button disabled>Disabled</button>
<input type="text" value="Raw text input">
<input type="checkbox" checked> Raw checkbox
<input type="radio" name="raw-radio" checked> Raw radio
<select><option>Raw select</option></select>
<textarea>Raw textarea</textarea>
<div><button id="wrapped-raw-button">Wrapped raw button</button></div>
<bond><div><button id="bond-wrapped-raw-button">Bond-wrapped raw button</button></div></bond>
<button class="custom-button">Authored class</button>
<div class="custom-widget"><button>Nested widget button</button></div>
<div><div class="custom-widget-deep"><button>Deep nested widget button</button></div></div>
<div style="padding: 1px"><button>Styled wrapper button</button></div>
<div data-snapshot-unstyled><button>Opt-out wrapper button</button></div>
<button style="background: rgb(1, 2, 3)">Inline style</button>
<button data-snapshot-unstyled>Explicitly unstyled</button>
<span>$(interpolation_value)</span>
<script>const nestedJavascript = $(interpolation_value); window.__rawOutputRuns = (window.__rawOutputRuns || 0) + 1;</script>
""")

# ╔═╡ d1000002-0000-4000-8000-000000000001
"""<script>const plainJuliaString = true;</script>"""

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
# ╠═d1000000-0000-4000-8000-000000000001
# ╠═d1000001-0000-4000-8000-000000000001
# ╠═d1000002-0000-4000-8000-000000000001
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
