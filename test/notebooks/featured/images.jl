### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> chapter = 1
#> license_url = "https://github.com/mitmath/computational-thinking/blob/Fall23/LICENSE.md"
#> youtube_id = "3zTO3LEY-cM"
#> video = "https://www.youtube.com/watch?v=3zTO3LEY-cM"
#> layout = "layout.jlhtml"
#> text_license = "CC-BY-SA-4.0"
#> description = "How can an image be stored as an array of colored pixels? Can we transform this data?"
#> image = "https://user-images.githubusercontent.com/6933510/136196634-2294d0a7-e79a-40d0-bbb8-81da70f4d398.png"
#> code_license = "MIT"
#> section = 1
#> order = 1
#> title = "Images as arrays"
#> tags = ["lecture", "module1", "philip", "track_julia", "matrix", "image"]

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

# ╔═╡ 74b008f6-ed6b-11ea-291f-b3791d6d1b35
begin
	using PlutoUI
	using WasmMakie
end

# ╔═╡ ca1b507e-6017-11eb-34e6-6b85cd189002
md"""
# Images as examples of data all around us

Welcome to Computational Thinking with Julia!

An **image** is one of the most familiar kinds of **data**. In this notebook we explore the central idea: *an image is just an **array** (a grid) of numbers.* Each cell of the grid is a **pixel** — a tiny block of a single color.

To stay completely self-contained (this notebook compiles to a live interactive WebAssembly **island**), we will not load a photo from disk. Instead we **build** our images from scratch with plain Julia loops — gradients, rings, color channels — and then index, slice, brighten, flip and blur them, exactly as we would a real photo.
"""

# ╔═╡ d07fcdb0-7afc-4a25-b68a-49fd1e3405e7
PlutoUI.TableOfContents(aside=true)

# ╔═╡ 9eb6efd2-6018-11eb-2db8-c3ce41d9e337
md"""
If we open an image on our computer and zoom in enough, we see that it consists of many tiny squares, or **pixels** ("picture elements"). Each pixel is a single colour, and the pixels are arranged in a two-dimensional grid.

These pixels are stored in the computer numerically, usually in **RGB** (red, green, blue) format: three numbers between 0 and 1 giving the amount of each colour. A grayscale pixel needs just a single number between 0 (black) and 1 (white).

So: **an image is a matrix of numbers.** Let's make some.
"""

# ╔═╡ 1d02d216-705e-4d99-b7bd-351310aadde0
begin
	# ── WasmMakie display helpers ───────────────────────────────────────────
	# Both take a *flat, column-major* Vector and the (nrows, ncols) shape, so
	# nothing here builds a Matrix literal (those trap inside wasm kernels).
	# Both render through `image!` (RGBA): a grayscale value v is shown as the
	# neutral colour (v, v, v) — visually identical to a gray heatmap, but
	# routed through the wasm-stable image path.
	# Row 1 is drawn at the TOP (we flip with (nr - i)), matching image layout.

	function gray_figure(vals::Vector{Float64}, nr::Int, nc::Int; px::Int = 320)
		pix = Vector{NTuple{4,Float64}}(undef, nr * nc)
		for k in 1:(nr * nc)
			v = vals[k]
			pix[k] = (v, v, v, 1.0)          # gray = equal R, G, B
		end
		fig = Figure(size = (px, max(40, round(Int, px * nr / nc))))
		ax = Axis(fig[1, 1])
		hidedecorations!(ax)
		hidespines!(ax)
		image!(ax, (0.0, Float64(nc)), (0.0, Float64(nr)), pix,
		       Int64(nc), Int64(nr); interpolate = false)
		fig
	end

	function rgb_figure(pix::Vector{NTuple{4,Float64}}, nr::Int, nc::Int;
	                    px::Int = 320)
		fig = Figure(size = (px, max(40, round(Int, px * nr / nc))))
		ax = Axis(fig[1, 1])
		hidedecorations!(ax)
		hidespines!(ax)
		image!(ax, (0.0, Float64(nc)), (0.0, Float64(nr)), pix,
		       Int64(nc), Int64(nr); interpolate = false)
		fig
	end
end

# ╔═╡ 4504577c-64c8-11eb-343b-3369b6d10d8b
md"""
## Representing colors

We represent a colour as an **RGB triple** $(r, g, b)$: three numbers between 0 (none) and 1 (full). White is $(1,1,1)$, black is $(0,0,0)$, pure red is $(1,0,0)$.

Drag the sliders to mix a colour. The cell below builds a 1-pixel image from the three numbers — a single coloured square.
"""

# ╔═╡ c2907d1a-47b1-4634-8669-a68022706861
md"""
red $(@bind test_r Slider(0.0:0.05:1.0; default=0.1, show_value=true))

green $(@bind test_g Slider(0.0:0.05:1.0; default=0.5, show_value=true))

blue $(@bind test_b Slider(0.0:0.05:1.0; default=1.0, show_value=true))
"""

# ╔═╡ ff9eea3f-cab0-4030-8337-f519b94316c5
let
	r = Float64(test_r); g = Float64(test_g); b = Float64(test_b)
	# one pixel = a length-1 flat RGBA vector
	pix = Vector{NTuple{4,Float64}}(undef, 1)
	pix[1] = (r, g, b, 1.0)
	rgb_figure(pix, 1, 1; px = 120)
end

# ╔═╡ 0f35603a-64d4-11eb-3baf-4fef06d82daa
md"""
## Building an image with loops (a colour gradient)

If we want more than a few pixels, we automate the process with a **loop**. Here we sweep the red and green channels across a grid: `red` grows from left to right, `green` from bottom to top. Every pixel's colour is computed from its coordinates `(i, j)` — pure data, no photo needed.
"""

# ╔═╡ 291b04de-64d7-11eb-1ee0-d998dccb998c
let
	nr, nc = 48, 48
	pix = Vector{NTuple{4,Float64}}(undef, nr * nc)
	for i in 1:nr, j in 1:nc
		r = (j - 1) / (nc - 1)          # red increases with column
		g = (i - 1) / (nr - 1)          # green increases with row
		# store column-major with row 1 at the top
		pix[j + (nr - i) * nc] = (r, g, 0.4, 1.0)
	end
	rgb_figure(pix, nr, nc)
end

# ╔═╡ 7b04331a-6bcb-11eb-34fa-1f5b151e5510
md"""
# Model: creating a synthetic "scene"

Movie frames (think Pixar) are images generated entirely from mathematics. Let's do a tiny version: a grayscale **scene** made of concentric rings around a centre, plus a soft diagonal gradient. Everything is a function of the pixel coordinates `(i, j)`.

This `scene(nr, nc)` matrix is the "photo" we'll inspect and transform for the rest of the notebook.
"""

# ╔═╡ 132f6596-6bc6-11eb-29f1-1b2478c929af
"""Build a synthetic grayscale image as a flat column-major Vector{Float64}
of length nr*nc. Concentric rings around the centre + a gentle gradient."""
function scene(nr::Int, nc::Int)
	vals = Vector{Float64}(undef, nr * nc)
	ci = (nr + 1) / 2
	cj = (nc + 1) / 2
	maxr = sqrt(ci * ci + cj * cj)
	for i in 1:nr, j in 1:nc
		di = i - ci
		dj = j - cj
		dist = sqrt(di * di + dj * dj)
		rings = 0.5 + 0.5 * cos(dist * 0.9)        # concentric rings
		grad = (i + j) / (nr + nc)                 # diagonal gradient
		v = 0.6 * rings + 0.4 * grad
		v < 0.0 && (v = 0.0)
		v > 1.0 && (v = 1.0)
		vals[j + (nr - i) * nc] = v
	end
	return vals
end

# ╔═╡ 9fec662f-7cd1-40db-8c45-25423473db6f
let
	nr, nc = 80, 80
	gray_figure(scene(nr, nc), nr, nc)
end

# ╔═╡ cef1a95a-64c6-11eb-15e7-636a3621d727
md"""
## Inspecting your data

### Image size

The first thing we usually want to know is the **size** of the image: how many rows (height) and columns (width). For our scene that is simply the `(nr, nc)` we chose.
"""

# ╔═╡ 75c5c85a-602c-11eb-2fb1-f7e7f2c5d04b
scene_size = (80, 80)

# ╔═╡ f9244264-64c6-11eb-23a6-cfa76f8aff6d
md"""
### Locations in an image: indexing

To refer to one pixel we give two whole numbers: the **row** (from the top) and the **column** (from the left). In Julia rows and columns are numbered from **1**.

Because we store the image as a flat column-major vector with row 1 on top, the pixel at row `i`, column `j` lives at index `j + (nr - i) * nc`. The helper `pixel_at` does that arithmetic for us and returns the brightness there.
"""

# ╔═╡ bd22d09a-64c7-11eb-146f-67733b8be241
"Return the grayscale value at row i, column j of a flat (nr×nc) image."
function pixel_at(vals::Vector{Float64}, nr::Int, nc::Int, i::Int, j::Int)
	return vals[j + (nr - i) * nc]
end

# ╔═╡ 08d61afb-c641-4aa9-b995-2552af89f3b8
md"row $(@bind row_i Slider(1:80; default=40, show_value=true))"

# ╔═╡ 6511a498-7ac9-445b-9c15-ec02d09783fe
md"column $(@bind col_i Slider(1:80; default=40, show_value=true))"

# ╔═╡ ff762861-b186-4eb0-9582-0ce66ca10f60
let
	nr, nc = 80, 80
	v = pixel_at(scene(nr, nc), nr, nc, row_i, col_i)
	# show that single pixel as a grayscale square
	one = Vector{Float64}(undef, 1)
	one[1] = v
	gray_figure(one, 1, 1; px = 120)
end

# ╔═╡ 94b77934-713e-11eb-18cf-c5dc5e7afc5b
md"The pixel at row $(row_i), column $(col_i) has brightness shown above."

# ╔═╡ c9ed950c-dcd9-4296-a431-ee0f36d5b557
md"""
### Range indexing: slicing a sub-region

Instead of one pixel we can grab a **block** of rows and columns — a *crop*. With a real array we'd write `img[r0:r1, c0:c1]`. Here we copy the chosen rectangle into a new, smaller flat image with `crop`.

Use the slider to change how big a square we cut out of the **centre** of the scene.
"""

# ╔═╡ c926435c-c648-419c-9951-ac8a1d4f3b92
"""Copy the rectangle rows r0:r1, cols c0:c1 out of a flat (nr×nc) image into
a new flat image of size (r1-r0+1)×(c1-c0+1)."""
function crop(vals::Vector{Float64}, nr::Int, nc::Int,
              r0::Int, r1::Int, c0::Int, c1::Int)
	on = r1 - r0 + 1
	om = c1 - c0 + 1
	out = Vector{Float64}(undef, on * om)
	for i in 1:on, j in 1:om
		src = pixel_at(vals, nr, nc, r0 + i - 1, c0 + j - 1)
		out[j + (on - i) * om] = src
	end
	return out
end

# ╔═╡ 4b64e1f2-d0ca-4e22-a89d-1d9a16bd6788
md"crop size $(@bind crop_half Slider(4:2:38; default=20, show_value=true))"

# ╔═╡ 93b18ee8-f11c-40e2-b292-562798100ba4
let
	nr, nc = 80, 80
	mid = 40
	r0 = mid - crop_half; r1 = mid + crop_half
	c0 = mid - crop_half; c1 = mid + crop_half
	on = r1 - r0 + 1; om = c1 - c0 + 1
	sub = crop(scene(nr, nc), nr, nc, r0, r1, c0, c1)
	gray_figure(sub, on, om)
end

# ╔═╡ 5a0cc342-64c9-11eb-1211-f1b06d652497
md"""
# Process: modifying an image

Now that an image is just numbers, we can **process** it. Every operation below is a loop that reads pixels and writes new ones.
"""

# ╔═╡ 2ee543b2-64d6-11eb-3c39-c5660141787e
md"""
## Brightness

The simplest transform: **scale every pixel** by a factor. A factor below 1 darkens the image, above 1 brightens it (clamped to 1). Drag the slider.
"""

# ╔═╡ 53bad296-4c7b-471f-b481-0e9423a9288a
md"brightness $(@bind brightness Slider(0.2:0.1:2.0; default=1.0, show_value=true))"

# ╔═╡ ab9af0f6-64c9-11eb-13d3-5dbdb75a69a7
let
	nr, nc = 80, 80
	base = scene(nr, nc)
	out = Vector{Float64}(undef, nr * nc)
	f = Float64(brightness)
	for k in 1:(nr * nc)
		v = base[k] * f
		v > 1.0 && (v = 1.0)
		out[k] = v
	end
	gray_figure(out, nr, nc)
end

# ╔═╡ f2ad501a-64cb-11eb-1707-3365d05b300a
md"""
## Flipping

Flipping is pure index gymnastics: to flip **left↔right** we read column `nc - j + 1` instead of column `j`; to flip **top↕bottom** we read row `nr - i + 1`. No pixel values change — only *where* they go.
"""

# ╔═╡ 4f03f651-56ed-4361-b954-e6848ac56089
md"""
flip left↔right $(@bind flip_lr CheckBox(default=true))

flip top↕bottom $(@bind flip_tb CheckBox(default=false))
"""

# ╔═╡ 1bd53326-d705-4d1a-bf8f-5d7f2a4e696f
let
	nr, nc = 80, 80
	base = scene(nr, nc)
	out = Vector{Float64}(undef, nr * nc)
	for i in 1:nr, j in 1:nc
		si = flip_tb ? (nr - i + 1) : i
		sj = flip_lr ? (nc - j + 1) : j
		out[j + (nr - i) * nc] = pixel_at(base, nr, nc, si, sj)
	end
	gray_figure(out, nr, nc)
end

# ╔═╡ 647fddf2-60ee-11eb-124d-5356c7014c3b
md"""
## Joining images (concatenation)

We often place images side by side. Here we build the four-up mosaic
`[ A  flip-LR ; flip-TB  flip-both ]` — the classic "kaleidoscope" you get by
mirroring an image into a 2×2 block.
"""

# ╔═╡ 7d9ad134-60ee-11eb-1b2a-a7d63f3a7a2d
let
	nr, nc = 64, 64
	base = scene(nr, nc)
	on = 2 * nr; om = 2 * nc
	out = Vector{Float64}(undef, on * om)
	for i in 1:nr, j in 1:nc
		v = pixel_at(base, nr, nc, i, j)
		# top-left: original
		out[j + (on - i) * om] = v
		# top-right: mirror left↔right
		out[(j + nc) + (on - i) * om] = v
		# bottom-left: mirror top↕bottom
		out[j + (on - (i + nr)) * om] = v
		# bottom-right: mirror both
		out[(j + nc) + (on - (i + nr)) * om] = v
	end
	# now actually mirror the right/bottom halves by re-reading flipped sources
	for i in 1:nr, j in 1:nc
		out[(j + nc) + (on - i) * om] = pixel_at(base, nr, nc, i, nc - j + 1)
		out[j + (on - (i + nr)) * om] = pixel_at(base, nr, nc, nr - i + 1, j)
		out[(j + nc) + (on - (i + nr)) * om] =
			pixel_at(base, nr, nc, nr - i + 1, nc - j + 1)
	end
	gray_figure(out, on, om; px = 360)
end

# ╔═╡ 4e6a31d6-1ef8-4a69-b346-ad58cfc4d8a5
md"""
# Colour channels

A colour image is really **three** grayscale images stacked: one for red, one
for green, one for blue. Here we build an RGB scene from three different
synthetic patterns, then let you switch a channel on or off to see its
contribution.
"""

# ╔═╡ 9e447eab-14b6-45d8-83ab-1f7f1f1c70d2
md"""
show red $(@bind show_r CheckBox(default=true))
show green $(@bind show_g CheckBox(default=true))
show blue $(@bind show_b CheckBox(default=true))
"""

# ╔═╡ d1174f21-5c74-4934-acdf-716671cfc2db
let
	nr, nc = 80, 80
	ci = (nr + 1) / 2; cj = (nc + 1) / 2
	pix = Vector{NTuple{4,Float64}}(undef, nr * nc)
	for i in 1:nr, j in 1:nc
		di = i - ci; dj = j - cj
		dist = sqrt(di * di + dj * dj)
		r = show_r ? (j - 1) / (nc - 1) : 0.0                 # red: horizontal ramp
		g = show_g ? (i - 1) / (nr - 1) : 0.0                 # green: vertical ramp
		b = show_b ? (0.5 + 0.5 * cos(dist * 0.6)) : 0.0      # blue: rings
		pix[j + (nr - i) * nc] = (r, g, b, 1.0)
	end
	rgb_figure(pix, nr, nc)
end

# ╔═╡ 5e52d12e-64d7-11eb-0905-c9038a404e24
md"""
# A simple blur (convolution)

A **blur** replaces each pixel with the **average** of itself and its
neighbours. We slide a small square window (the *kernel*) over the image; the
bigger the window, the blurrier the result. This averaging is the simplest
example of a **convolution** — the workhorse of image processing.

Drag the **blur radius** slider: radius 0 is the original scene, larger radii
average over wider neighbourhoods.
"""

# ╔═╡ b37c9868-64d7-11eb-3033-a7b5d3065f7f
md"blur radius $(@bind blur_radius Slider(0:1:5; default=2, show_value=true))"

# ╔═╡ 88933746-6028-11eb-32de-13eb6ff43e29
let
	nr, nc = 80, 80
	base = scene(nr, nc)
	rad = blur_radius
	out = Vector{Float64}(undef, nr * nc)
	for i in 1:nr, j in 1:nc
		acc = 0.0
		cnt = 0
		for di in -rad:rad, dj in -rad:rad
			ii = i + di
			jj = j + dj
			if ii >= 1 && ii <= nr && jj >= 1 && jj <= nc
				acc += pixel_at(base, nr, nc, ii, jj)
				cnt += 1
			end
		end
		out[j + (nr - i) * nc] = acc / cnt
	end
	gray_figure(out, nr, nc)
end

# ╔═╡ ace86c8a-60ee-11eb-34ef-93c54abc7b1a
md"""
# Summary

- Images are **arrays** of colours: a grayscale image is a `Matrix` of numbers; a colour image stacks three (red, green, blue) channels.
- We **inspect** and **modify** arrays with **indexing** (one pixel), **range indexing / cropping** (a sub-region), and whole-array loops.
- We can **build** images directly from their coordinates (gradients, rings — a synthetic scene), with no photo required.
- Classic transforms — **brightness** scaling, **flips**, **concatenation**, splitting into **colour channels**, and a **blur** (the simplest convolution) — are all just loops over the grid.

Every figure above is a live **WebAssembly island** rendered with WasmMakie, recomputed in your browser as you move the sliders.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

[sources]
WasmMakie = {url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"}

[compat]
PlutoUI = "~0.7.83"
WasmMakie = "~0.1.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "528a15ccaaea2a8f2cfb8a3b8ef12bd3bc6e7ee4"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "d1a86724f81bcd184a38fd284ce183ec067d71a0"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "1.0.0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.15.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.WasmMakie]]
deps = ["Base64"]
git-tree-sha1 = "de6c9a45585e892ac96fa7ad9fd3b1d3d61277ec"
repo-url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"
uuid = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"
version = "0.1.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"
"""

# ╔═╡ Cell order:
# ╟─ca1b507e-6017-11eb-34e6-6b85cd189002
# ╠═74b008f6-ed6b-11ea-291f-b3791d6d1b35
# ╟─d07fcdb0-7afc-4a25-b68a-49fd1e3405e7
# ╟─9eb6efd2-6018-11eb-2db8-c3ce41d9e337
# ╟─1d02d216-705e-4d99-b7bd-351310aadde0
# ╟─4504577c-64c8-11eb-343b-3369b6d10d8b
# ╟─c2907d1a-47b1-4634-8669-a68022706861
# ╠═ff9eea3f-cab0-4030-8337-f519b94316c5
# ╟─0f35603a-64d4-11eb-3baf-4fef06d82daa
# ╠═291b04de-64d7-11eb-1ee0-d998dccb998c
# ╟─7b04331a-6bcb-11eb-34fa-1f5b151e5510
# ╠═132f6596-6bc6-11eb-29f1-1b2478c929af
# ╠═9fec662f-7cd1-40db-8c45-25423473db6f
# ╟─cef1a95a-64c6-11eb-15e7-636a3621d727
# ╠═75c5c85a-602c-11eb-2fb1-f7e7f2c5d04b
# ╟─f9244264-64c6-11eb-23a6-cfa76f8aff6d
# ╠═bd22d09a-64c7-11eb-146f-67733b8be241
# ╟─08d61afb-c641-4aa9-b995-2552af89f3b8
# ╟─6511a498-7ac9-445b-9c15-ec02d09783fe
# ╠═ff762861-b186-4eb0-9582-0ce66ca10f60
# ╟─94b77934-713e-11eb-18cf-c5dc5e7afc5b
# ╟─c9ed950c-dcd9-4296-a431-ee0f36d5b557
# ╠═c926435c-c648-419c-9951-ac8a1d4f3b92
# ╟─4b64e1f2-d0ca-4e22-a89d-1d9a16bd6788
# ╠═93b18ee8-f11c-40e2-b292-562798100ba4
# ╟─5a0cc342-64c9-11eb-1211-f1b06d652497
# ╟─2ee543b2-64d6-11eb-3c39-c5660141787e
# ╟─53bad296-4c7b-471f-b481-0e9423a9288a
# ╠═ab9af0f6-64c9-11eb-13d3-5dbdb75a69a7
# ╟─f2ad501a-64cb-11eb-1707-3365d05b300a
# ╟─4f03f651-56ed-4361-b954-e6848ac56089
# ╠═1bd53326-d705-4d1a-bf8f-5d7f2a4e696f
# ╟─647fddf2-60ee-11eb-124d-5356c7014c3b
# ╠═7d9ad134-60ee-11eb-1b2a-a7d63f3a7a2d
# ╟─4e6a31d6-1ef8-4a69-b346-ad58cfc4d8a5
# ╟─9e447eab-14b6-45d8-83ab-1f7f1f1c70d2
# ╠═d1174f21-5c74-4934-acdf-716671cfc2db
# ╟─5e52d12e-64d7-11eb-0905-c9038a404e24
# ╟─b37c9868-64d7-11eb-3033-a7b5d3065f7f
# ╠═88933746-6028-11eb-32de-13eb6ff43e29
# ╟─ace86c8a-60ee-11eb-34ef-93c54abc7b1a
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
