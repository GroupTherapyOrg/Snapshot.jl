### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> license_url = "https://github.com/JuliaPluto/featured/blob/2a6a9664e5428b37abe4957c1dca0994f4a8b7fd/LICENSES/Unlicense"
#> image = "https://github.com/JuliaPluto/featured/assets/6933510/4215e7d0-53c4-4ee7-a26d-48d36457d194"
#> title = "Images and Filtering"
#> tags = ["images", "filtering", "gaussian", "pixel", "convolution", "math"]
#> license = "Unlicense"
#> description = "Learn how convolutions are used as filters in image processing!"
#> date = "2023-07-09"
#> 
#>     [[frontmatter.author]]
#>     name = "Boshra Ariguib"
#>     url = "https://github.com/ariguiba"

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

# ╔═╡ 746ff659-88ab-4ff4-8cba-43c798cacd3e
begin
	using PlutoUI, WasmMakie
end

# ╔═╡ 04a5c6d4-f8d5-11ed-141a-35481b811ee9
md"""
## Images as Lists of numbers
Hi There! Remember when you were a kid and you used to play with legos? You probably would put tiny pieces of different colors together to form different shapes and elements.

Well, images in computers work exactly the same way! Each image is made of tiny elements we call **pixels**. Since our computers only understand numbers, these pixels are given to the computer as a list of numbers.

In the following, we will explore how images can be processed in computer science, and we will introduce a cool tool called **filtering**: a mathematical operation that modifies images by smoothing them, highlighting some parts, and much more.

To keep everything self-contained — this notebook compiles to a live interactive WebAssembly **island** — we won't load a photo from disk. Instead we **build** our image from scratch with plain Julia loops, then filter it.
"""

# ╔═╡ d07fcdb0-7afc-4a25-b68a-49fd1e3405e7
PlutoUI.TableOfContents(aside=true)

# ╔═╡ 9be00bec-59a5-478b-ada2-854f7a52d66e
md"""To keep things simple, we will only deal with black and white images for now. So, for a black and white image, each pixel is a single number between 0 (black) and 1 (white).

Try it out! Move the slider around to set the pixel below to get a different shade of gray."""

# ╔═╡ c4da04ab-f7e0-46fd-b352-e518e4733608
@bind g PlutoUI.Slider(0.0:0.05:1.0; default=0.5, show_value=true)

# ╔═╡ 7b04331a-6bcb-11eb-34fa-1f5b151e5510
md"""
## Our image: a synthetic scene

Now we can fill a grid of pixels and we already have our first image! Rather than load a photo, we **generate** one from mathematics — exactly how movie frames (think Pixar) are made. Our `scene(nr, nc)` is a grayscale image of concentric **rings** around the centre, plus a soft diagonal **gradient** and a couple of crisp blocks. Every pixel is just a function of its coordinates `(i, j)`.

This flat, column-major `Vector{Float64}` is the "photo" we will filter for the rest of the notebook.
"""

# ╔═╡ 132f6596-6bc6-11eb-29f1-1b2478c929af
"""Build a synthetic grayscale image as a flat column-major Vector{Float64}
of length nr*nc: concentric rings + a gradient + two crisp blocks."""
function scene(nr::Int, nc::Int)
	vals = Vector{Float64}(undef, nr * nc)
	ci = (nr + 1) / 2
	cj = (nc + 1) / 2
	for i in 1:nr, j in 1:nc
		di = i - ci
		dj = j - cj
		dist = sqrt(di * di + dj * dj)
		rings = 0.5 + 0.5 * cos(dist * 0.8)        # concentric rings
		grad = (i + j) / (nr + nc)                 # diagonal gradient
		v = 0.55 * rings + 0.45 * grad
		# two crisp blocks to make edge filters pop
		if i >= 12 && i <= 24 && j >= 12 && j <= 24
			v = 0.95
		end
		if i >= 44 && i <= 60 && j >= 46 && j <= 62
			v = 0.1
		end
		v < 0.0 && (v = 0.0)
		v > 1.0 && (v = 1.0)
		vals[j + (nr - i) * nc] = v
	end
	return vals
end

# ╔═╡ ebb63415-2738-47f3-b0ef-0fd6e6bac259
md"""
## Using a filter

Now to make things more interesting, let's apply a **filter** to this image.

A filter is a small matrix (here a 3×3 grid) that describes how to compute the new value of a pixel. Our code goes over every pixel and applies the mathematical operation of **convolution**: the pixel and its eight neighbours are each multiplied by the matching value in the filter, and the results are added up.

It's alright if you don't follow every line of the code below — the pictures will make it clear.
"""

# ╔═╡ bd22d09a-64c7-11eb-146f-67733b8be241
"Return the grayscale value at row i, column j of a flat (nr×nc) image, clamped to the border."
function pixel_at(vals::Vector{Float64}, nr::Int, nc::Int, i::Int, j::Int)
	ii = i
	jj = j
	ii < 1 && (ii = 1)
	ii > nr && (ii = nr)
	jj < 1 && (jj = 1)
	jj > nc && (jj = nc)
	return vals[jj + (nr - ii) * nc]
end

# ╔═╡ 44d594ff-a25b-4455-be56-863345c67b68
"""Convolve a flat (nr×nc) image with a flat 3×3 kernel `k` (row-major, length 9).
Out-of-bounds neighbours are clamped to the border, so the result keeps the
original size. Values are clamped to 0..1 for display."""
function convolve(vals::Vector{Float64}, nr::Int, nc::Int, k::Vector{Float64})
	out = Vector{Float64}(undef, nr * nc)
	for i in 1:nr, j in 1:nc
		acc = 0.0
		for di in -1:1, dj in -1:1
			w = k[(di + 1) * 3 + (dj + 2)]      # row-major 3×3 index
			acc += w * pixel_at(vals, nr, nc, i + di, j + dj)
		end
		acc < 0.0 && (acc = 0.0)
		acc > 1.0 && (acc = 1.0)
		out[j + (nr - i) * nc] = acc
	end
	return out
end

# ╔═╡ d752805d-ba2c-4133-a556-46a1da734557
md"""
Below you can choose a filter and dial its **strength**. The classic kernels are:

- **Identity** — leaves the image unchanged (a 1 in the centre).
- **Box blur** — every weight equals 1/9, so each pixel becomes the average of its 3×3 neighbourhood. Blurring!
- **Sharpen** — boosts the centre and subtracts the neighbours, making edges crisper.
- **Edge detect** — the centre minus its neighbours; flat areas go dark and edges light up.
- **Sobel (vertical)** — the workhorse gradient kernel that highlights vertical edges.

In the box blur all weights are equal, so each new pixel is just the average of the pixel and its neighbours. Can you see it in the result below?
"""

# ╔═╡ d729f8b4-05e2-4863-b8c4-39b37646c36b
"""Build a flat 3×3 kernel (row-major, length 9) for filter `choice`, scaled by
`strength`. `choice` is clamped into 1..5 so any slider index is valid:
1 identity, 2 box blur, 3 sharpen, 4 edge detect, 5 Sobel vertical."""
function make_kernel(choice::Int, strength::Float64)
	c = choice
	c < 1 && (c = 1)
	c > 5 && (c = 5)
	s = strength
	k = Vector{Float64}(undef, 9)
	for t in 1:9
		k[t] = 0.0
	end
	if c == 1                       # identity
		k[5] = 1.0
	elseif c == 2                   # box blur (strength interpolates toward blur)
		w = (1.0 / 9.0) * s
		for t in 1:9
			k[t] = w
		end
		# top up the centre so the total weight stays 1 (keeps brightness)
		k[5] = k[5] + (1.0 - s)
	elseif c == 3                   # sharpen
		k[2] = -s; k[4] = -s; k[6] = -s; k[8] = -s
		k[5] = 1.0 + 4.0 * s
	elseif c == 4                   # edge detect (Laplacian)
		k[2] = -s; k[4] = -s; k[6] = -s; k[8] = -s
		k[5] = 4.0 * s
	else                            # Sobel vertical
		k[1] = s;  k[3] = -s
		k[4] = 2.0 * s; k[6] = -2.0 * s
		k[7] = s;  k[9] = -s
	end
	return k
end

# ╔═╡ 19b49665-0382-4eb1-9c70-8295e0aa819b
md"""You can also try the other filters!

Pick a filter and adjust its strength below, then watch both the **filter matrix** (shown as a small image) and the **filtered scene** change. Can you tell the blur apart from the edge detector just by looking?"""

# ╔═╡ adc154cf-7059-4f1d-9bac-56b9a93cc47f
@bind filter_choice PlutoUI.Slider(1:5; default=2, show_value=true)

# ╔═╡ a174850b-91cc-4463-ab28-61ca0a7221c6
md"filter strength $(@bind filter_strength PlutoUI.Slider(0.0:0.1:2.0; default=1.0, show_value=true))"

# ╔═╡ f844bca2-edb7-45ec-b860-5f1e0b8b6bc0
md"""The names match the slider, in order: **1** = Identity, **2** = Box Blur, **3** = Sharpen, **4** = Edge Detect, **5** = Sobel (vertical edges)."""

# ╔═╡ 5e52d12e-64d7-11eb-0905-c9038a404e24
md"""
## Blur radius

The box blur above averages over the 3×3 neighbourhood. A bigger window means
a blurrier image. Below we slide the **blur radius**: radius 0 is the original
scene, larger radii average over a wider square of neighbours. This is the
simplest convolution of all — pure averaging.
"""

# ╔═╡ b37c9868-64d7-11eb-3033-a7b5d3065f7f
md"blur radius $(@bind blur_radius PlutoUI.Slider(0:1:6; default=2, show_value=true))"

# ╔═╡ 4e6a31d6-1ef8-4a69-b346-ad58cfc4d8a5
md"""
## Filtering in colour

A colour image is really **three** grayscale images stacked: one for red, one
for green, one for blue. Here we build an RGB scene and blur it — convolution
runs on each channel independently. Toggle the blur on and off to compare.
"""

# ╔═╡ 9e447eab-14b6-45d8-83ab-1f7f1f1c70d2
md"""blur the colour image $(@bind color_blur CheckBox(default=true))"""

# ╔═╡ ace86c8a-60ee-11eb-34ef-93c54abc7b1a
md"""
# Summary

- Images are **arrays** of numbers: a grayscale image is a grid of brightnesses; a colour image stacks three (red, green, blue) channels.
- A **filter** (kernel) is a tiny matrix. **Convolution** slides it over the image, multiplying each pixel and its neighbours by the kernel weights and summing.
- Different kernels do different jobs: a **box blur** averages (smooths), a **sharpen** boosts the centre, and **edge / Sobel** kernels light up where the image changes.
- We can **build** images directly from their coordinates (rings, gradients — a synthetic scene), with no photo required.

Every figure above is a live **WebAssembly island** rendered with WasmMakie, recomputed in your browser as you move the sliders.
"""

# ╔═╡ 08313de6-4927-47dd-a7e4-5094c7967ad1
begin
	# ── WasmMakie display helpers ───────────────────────────────────────────
	# Both take a *flat, column-major* Vector and the (nrows, ncols) shape, so
	# nothing here builds a Matrix literal (those trap inside wasm kernels).
	# `gray_figure` renders a grayscale value v as the neutral colour (v, v, v)
	# through `image!` (the wasm-stable RGBA path — heatmap! is not wasm-safe).
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

# ╔═╡ 96a4b35a-5a3a-4ad0-9ffe-306db46d1c03
let
	gv = Float64(g)
	one = Vector{Float64}(undef, 1)
	one[1] = gv
	gray_figure(one, 1, 1; px = 80)
end

# ╔═╡ 9fec662f-7cd1-40db-8c45-25423473db6f
let
	nr, nc = 72, 72
	gray_figure(scene(nr, nc), nr, nc)
end

# ╔═╡ 702ab37f-bbeb-4197-807a-b45207598cb1
let
	# show the chosen 3×3 kernel as a tiny image (normalised to 0..1)
	k = make_kernel(Int(filter_choice), Float64(filter_strength))
	lo = k[1]; hi = k[1]
	for t in 2:9
		k[t] < lo && (lo = k[t])
		k[t] > hi && (hi = k[t])
	end
	span = hi - lo
	span <= 0.0 && (span = 1.0)
	disp = Vector{Float64}(undef, 9)
	# kernel is row-major 3×3; gray_figure wants column-major with row 1 on top
	for r in 1:3, cc in 1:3
		v = (k[(r - 1) * 3 + cc] - lo) / span
		disp[cc + (3 - r) * 3] = v
	end
	gray_figure(disp, 3, 3; px = 150)
end

# ╔═╡ 4b560bf2-00d9-4440-9589-834cd9177f66
let
	nr, nc = 72, 72
	base = scene(nr, nc)
	k = make_kernel(Int(filter_choice), Float64(filter_strength))
	out = convolve(base, nr, nc, k)
	gray_figure(out, nr, nc; px = 360)
end

# ╔═╡ 88933746-6028-11eb-32de-13eb6ff43e29
let
	nr, nc = 72, 72
	base = scene(nr, nc)
	rad = Int(blur_radius)
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

# ╔═╡ d1174f21-5c74-4934-acdf-716671cfc2db
let
	nr, nc = 72, 72
	ci = (nr + 1) / 2; cj = (nc + 1) / 2
	# build three channels as flat vectors
	rr = Vector{Float64}(undef, nr * nc)
	gg = Vector{Float64}(undef, nr * nc)
	bb = Vector{Float64}(undef, nr * nc)
	for i in 1:nr, j in 1:nc
		di = i - ci; dj = j - cj
		dist = sqrt(di * di + dj * dj)
		idx = j + (nr - i) * nc
		rr[idx] = (j - 1) / (nc - 1)
		gg[idx] = (i - 1) / (nr - 1)
		bb[idx] = 0.5 + 0.5 * cos(dist * 0.6)
	end
	if color_blur
		k = make_kernel(2, 1.0)             # box blur
		rr = convolve(rr, nr, nc, k)
		gg = convolve(gg, nr, nc, k)
		bb = convolve(bb, nr, nc, k)
	end
	pix = Vector{NTuple{4,Float64}}(undef, nr * nc)
	for k2 in 1:(nr * nc)
		pix[k2] = (rr[k2], gg[k2], bb[k2], 1.0)
	end
	rgb_figure(pix, nr, nc)
end

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
# ╟─04a5c6d4-f8d5-11ed-141a-35481b811ee9
# ╠═746ff659-88ab-4ff4-8cba-43c798cacd3e
# ╟─d07fcdb0-7afc-4a25-b68a-49fd1e3405e7
# ╟─9be00bec-59a5-478b-ada2-854f7a52d66e
# ╠═c4da04ab-f7e0-46fd-b352-e518e4733608
# ╠═96a4b35a-5a3a-4ad0-9ffe-306db46d1c03
# ╟─7b04331a-6bcb-11eb-34fa-1f5b151e5510
# ╠═132f6596-6bc6-11eb-29f1-1b2478c929af
# ╠═9fec662f-7cd1-40db-8c45-25423473db6f
# ╟─ebb63415-2738-47f3-b0ef-0fd6e6bac259
# ╠═bd22d09a-64c7-11eb-146f-67733b8be241
# ╠═44d594ff-a25b-4455-be56-863345c67b68
# ╟─d752805d-ba2c-4133-a556-46a1da734557
# ╠═d729f8b4-05e2-4863-b8c4-39b37646c36b
# ╟─19b49665-0382-4eb1-9c70-8295e0aa819b
# ╠═adc154cf-7059-4f1d-9bac-56b9a93cc47f
# ╟─a174850b-91cc-4463-ab28-61ca0a7221c6
# ╟─f844bca2-edb7-45ec-b860-5f1e0b8b6bc0
# ╠═702ab37f-bbeb-4197-807a-b45207598cb1
# ╠═4b560bf2-00d9-4440-9589-834cd9177f66
# ╟─5e52d12e-64d7-11eb-0905-c9038a404e24
# ╟─b37c9868-64d7-11eb-3033-a7b5d3065f7f
# ╠═88933746-6028-11eb-32de-13eb6ff43e29
# ╟─4e6a31d6-1ef8-4a69-b346-ad58cfc4d8a5
# ╟─9e447eab-14b6-45d8-83ab-1f7f1f1c70d2
# ╠═d1174f21-5c74-4934-acdf-716671cfc2db
# ╟─ace86c8a-60ee-11eb-34ef-93c54abc7b1a
# ╠═08313de6-4927-47dd-a7e4-5094c7967ad1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
