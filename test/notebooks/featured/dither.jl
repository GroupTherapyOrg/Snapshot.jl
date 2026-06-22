### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> license_url = "https://github.com/JuliaPluto/featured/blob/2a6a9664e5428b37abe4957c1dca0994f4a8b7fd/LICENSES/Unlicense"
#> image = "https://github.com/JuliaPluto/PlutoUI.jl/assets/6933510/fb234dbf-4bc7-4b43-8630-3ba29eed6e1c"
#> title = "Image dithering"
#> tags = ["dithering", "quantization", "Floyd-Steinberg", "PlutoUI", "images", "interactive"]
#> date = "2024-05-06"
#> description = "How does dithering turn a smooth gradient into just a few shades of gray? Build the algorithms from scratch and watch them run live in your browser as WebAssembly."
#> license = "Unlicense"
#> 
#>     [[frontmatter.author]]
#>     name = "Adrian Hill"
#>     url = "https://github.com/adrhill"

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

# ╔═╡ 5627c4c8-5c3c-11ec-3a25-fdc505adbe69
begin
	using PlutoUI, WasmMakie
end

# ╔═╡ 9258ccd2-c6ef-4fff-b7bf-13f09dfd5b42
md"""
# Dithering ❤️ Pluto!

**Dithering** is a technique for *image quantization*: it lets us represent an
image faithfully using only a handful of colors (or shades of gray).

Everything below the sliders runs **in your browser as WebAssembly** — no Julia
server, no install. We don't load any real image files; instead we *build* a
synthetic grayscale image with plain `for` loops and then dither it with code we
write from scratch.
"""

# ╔═╡ 43744742-b8c7-4506-8ed6-1729fcd19321
md"""
## A synthetic test image

Each image here is just a flat `Vector{Float64}` of pixel brightnesses between
`0.0` (black) and `1.0` (white), stored **column by column** with `nc` columns and
`nr` rows. The helper `make_gradient` fills it with a smooth diagonal ramp plus a
soft circular bump in the middle — enough structure to make dithering interesting.
"""

# ╔═╡ 1e9359f2-59c1-4910-b00f-81dc74f889ae
"Build an `nr × nc` grayscale image (flat, column-major) with a smooth gradient and a soft central bump. Values lie in `[0, 1]`."
function make_gradient(nr::Int64, nc::Int64)
	img = Vector{Float64}(undef, nr * nc)
	cx = (nc + 1) / 2.0
	cy = (nr + 1) / 2.0
	rad = 0.5 * sqrt(Float64(nr * nr + nc * nc)) / 2.0
	for j in 1:nc
		for i in 1:nr
			ramp = ((i - 1) + (j - 1)) / (nr + nc - 2)
			dx = (Float64(j) - cx) / rad
			dy = (Float64(i) - cy) / rad
			bump = 0.35 * exp(-(dx * dx + dy * dy))
			v = ramp + bump
			if v < 0.0
				v = 0.0
			elseif v > 1.0
				v = 1.0
			end
			img[i + (j - 1) * nr] = v
		end
	end
	return img
end

# ╔═╡ b72d08fd-58b2-4e75-a5a6-e5be5d4438dd
"""
Render a flat column-major `Vector{Float64}` image (`nr` rows, `nc` cols, pixel
`idx = i + (j-1)*nr`) as a grayscale WasmMakie figure. Each brightness `v` is
shown as the neutral colour `(v, v, v)`, drawn through the wasm-stable `image!`
path (the `heatmap!` codegen path traps in compiled islands).
"""
function gray_figure(img::Vector{Float64}, nr::Int64, nc::Int64; px::Int64=320)
	# repack column-major (row stride nr) into image! layout (row stride nc),
	# flipping rows so image row 1 renders at the TOP, and map gray → RGBA
	pix = Vector{NTuple{4,Float64}}(undef, nr * nc)
	for i in 1:nr
		for j in 1:nc
			v = img[i + (j - 1) * nr]
			pix[j + (nr - i) * nc] = (v, v, v, 1.0)
		end
	end
	fig = Figure(size = (px, px))
	ax = Axis(fig[1, 1])
	hidedecorations!(ax)
	hidespines!(ax)
	image!(ax, (0.0, Float64(nc)), (0.0, Float64(nr)), pix,
	       Int64(nc), Int64(nr); interpolate = false)
	return fig
end

# ╔═╡ a4a610a0-2034-4548-b9b1-283eaba05b59
md"""
Pick the image size — smaller images make the individual dithered pixels easier to
see: $(@bind imgsize Slider(16:8:64, default=48, show_value=true))
"""

# ╔═╡ b509f437-be95-4272-a675-2d1e6af498ca
md"""
### The original (continuous) image

This is the smooth, full-precision image before any quantization.
"""

# ╔═╡ 09cbe381-c39e-4431-a9d3-624091ea42d0
let
	n = imgsize
	img = make_gradient(n, n)
	gray_figure(img, n, n)
end

# ╔═╡ 53d3af8c-88b5-4409-bf6a-9e1b22ac34a0
md"""
## Step 1: Just round each pixel

The simplest way to quantize is to **snap every pixel to its nearest allowed
level**. With 2 levels that means black or white; with more levels we get a few
shades of gray.

`quantize` does exactly this: it rounds each pixel to the closest of `levels`
evenly-spaced values. **A lot of detail gets lost** — large flat bands appear where
the smooth gradient used to be. 🥲
"""

# ╔═╡ 0c6aff98-350e-4935-834c-6b9aa9fa3a38
"Snap a brightness `v ∈ [0,1]` to the nearest of `levels` evenly-spaced values."
function snap(v::Float64, levels::Int64)
	steps = levels - 1
	q = round(v * steps) / steps
	if q < 0.0
		q = 0.0
	elseif q > 1.0
		q = 1.0
	end
	return q
end

# ╔═╡ dc829cc3-213b-4f8f-b1e0-ad705be35edb
"Quantize a flat image to `levels` shades by rounding each pixel independently."
function quantize(img::Vector{Float64}, levels::Int64)
	out = Vector{Float64}(undef, length(img))
	for k in 1:length(img)
		out[k] = snap(img[k], levels)
	end
	return out
end

# ╔═╡ 3ed9b4fd-2da0-419e-986c-16faa80ad536
md"""
Number of gray levels = $(@bind levels Slider(2:6, default=2, show_value=true))
"""

# ╔═╡ 8a718f57-740b-43a8-9f05-6c699f982220
let
	n = imgsize
	img = make_gradient(n, n)
	q = quantize(img, levels)
	gray_figure(q, n, n)
end

# ╔═╡ 7de553b7-e19f-4482-9b5e-d4c8755a033a
md"""
## Step 2: Dither with error diffusion

Dithering does much better. Instead of throwing away the rounding error at each
pixel, **Floyd–Steinberg error diffusion** spreads that error onto the
not-yet-visited neighbours. The errors cancel out on average, so a region that is
*half-way* between two levels gets a 50/50 sprinkle of the two — your eye blends
them into the in-between shade.

The classic weights push the error to the right (`7/16`) and to the three pixels
below (`3/16`, `5/16`, `1/16`):
"""

# ╔═╡ 44d594ff-a25b-4455-be56-863345c67b68
"""
Floyd–Steinberg dithering on a flat column-major image (`nr` rows, `nc` cols)
quantized to `levels` shades. Returns a new flat `Vector{Float64}`.
"""
function floyd_steinberg(img::Vector{Float64}, nr::Int64, nc::Int64, levels::Int64)
	# work on a mutable copy so we can accumulate diffused error in place
	buf = Vector{Float64}(undef, nr * nc)
	for k in 1:length(img)
		buf[k] = img[k]
	end
	out = Vector{Float64}(undef, nr * nc)
	for i in 1:nr
		for j in 1:nc
			idx = i + (j - 1) * nr
			old = buf[idx]
			new = snap(old, levels)
			out[idx] = new
			err = old - new
			# right neighbour (same row, next column): 7/16
			if j < nc
				r = i + j * nr
				buf[r] = buf[r] + err * 7.0 / 16.0
			end
			# below-left (next row, previous column): 3/16
			if i < nr && j > 1
				bl = (i + 1) + (j - 2) * nr
				buf[bl] = buf[bl] + err * 3.0 / 16.0
			end
			# directly below (next row, same column): 5/16
			if i < nr
				b = (i + 1) + (j - 1) * nr
				buf[b] = buf[b] + err * 5.0 / 16.0
			end
			# below-right (next row, next column): 1/16
			if i < nr && j < nc
				br = (i + 1) + j * nr
				buf[br] = buf[br] + err * 1.0 / 16.0
			end
		end
	end
	return out
end

# ╔═╡ ab69309f-6a08-4f9f-b503-7a9610b1994a
md"""
Use the **same** number of levels as Step 1 (the slider above) so you can compare
fairly. The dithered image only ever uses those few shades — yet it looks far
closer to the original. Zoom in to see the high-frequency pattern that fools your
eye.
"""

# ╔═╡ 0210462f-851b-4e2b-ba99-d7ade531fe11
let
	n = imgsize
	img = make_gradient(n, n)
	d = floyd_steinberg(img, n, n, levels)
	gray_figure(d, n, n)
end

# ╔═╡ 9e1f34a2-c092-4b58-acac-b354f47465e5
md"""
## How much error is left?

A simple way to measure quality is the **mean absolute error** between the
quantized result and the original continuous image — averaged over every pixel.
Lower is better.
"""

# ╔═╡ 354f38ba-a8cf-4405-a0ef-1ec243f18acf
"Mean absolute difference between two flat images of equal length."
function mean_abs_error(a::Vector{Float64}, b::Vector{Float64})
	s = 0.0
	for k in 1:length(a)
		d = a[k] - b[k]
		if d < 0.0
			d = -d
		end
		s = s + d
	end
	return s / length(a)
end

# ╔═╡ 7d1ced8c-8a33-4429-b8fb-f06eb4bc7b1b
err_quantize = let
	n = imgsize
	img = make_gradient(n, n)
	mean_abs_error(quantize(img, levels), img)
end

# ╔═╡ c4799684-46b7-4783-99de-c8946e7067de
err_dither = let
	n = imgsize
	img = make_gradient(n, n)
	mean_abs_error(floyd_steinberg(img, n, n, levels), img)
end

# ╔═╡ a52bdeb6-35c4-4a70-bfa4-469912b30b27
md"""**Mean abs. error — plain rounding:** $(err_quantize)"""

# ╔═╡ ce25faed-be1c-4b74-9c3c-968638eb7813
md"""**Mean abs. error — Floyd–Steinberg:** $(err_dither)

Per-pixel, dithering does *not* reduce the absolute error (it still snaps to the
same few levels). What it changes is *where* the error goes: it scatters it as
high-frequency noise that the eye averages out, instead of leaving big visible
bands. That's the whole trick. ✨
"""

# ╔═╡ 83252609-ff10-4395-82b5-06b592998647
md"""
# Appendix

The idea behind dithering goes back to an engraving technique from the 15th century
called [stippling](https://en.wikipedia.org/wiki/Stippling), and a related concept,
[halftoning](https://en.wikipedia.org/wiki/Halftone), is what lets newspapers print
shades of gray with only black ink. You may also recognise the look from retro video
games with limited palettes — it's what gives the
[Game Boy Camera](https://en.wikipedia.org/wiki/Game_Boy_Camera) its distinctive style!

For the real thing on actual images, take a look at
[DitherPunk.jl](https://github.com/JuliaImages/DitherPunk.jl).
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
# ╟─9258ccd2-c6ef-4fff-b7bf-13f09dfd5b42
# ╠═5627c4c8-5c3c-11ec-3a25-fdc505adbe69
# ╟─43744742-b8c7-4506-8ed6-1729fcd19321
# ╠═1e9359f2-59c1-4910-b00f-81dc74f889ae
# ╠═b72d08fd-58b2-4e75-a5a6-e5be5d4438dd
# ╟─a4a610a0-2034-4548-b9b1-283eaba05b59
# ╟─b509f437-be95-4272-a675-2d1e6af498ca
# ╠═09cbe381-c39e-4431-a9d3-624091ea42d0
# ╟─53d3af8c-88b5-4409-bf6a-9e1b22ac34a0
# ╠═0c6aff98-350e-4935-834c-6b9aa9fa3a38
# ╠═dc829cc3-213b-4f8f-b1e0-ad705be35edb
# ╟─3ed9b4fd-2da0-419e-986c-16faa80ad536
# ╠═8a718f57-740b-43a8-9f05-6c699f982220
# ╟─7de553b7-e19f-4482-9b5e-d4c8755a033a
# ╠═44d594ff-a25b-4455-be56-863345c67b68
# ╟─ab69309f-6a08-4f9f-b503-7a9610b1994a
# ╠═0210462f-851b-4e2b-ba99-d7ade531fe11
# ╟─9e1f34a2-c092-4b58-acac-b354f47465e5
# ╠═354f38ba-a8cf-4405-a0ef-1ec243f18acf
# ╠═7d1ced8c-8a33-4429-b8fb-f06eb4bc7b1b
# ╠═c4799684-46b7-4783-99de-c8946e7067de
# ╟─a52bdeb6-35c4-4a70-bfa4-469912b30b27
# ╟─ce25faed-be1c-4b74-9c3c-968638eb7813
# ╟─83252609-ff10-4395-82b5-06b592998647
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
