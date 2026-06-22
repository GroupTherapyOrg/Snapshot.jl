### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> license_url = "https://github.com/JuliaPluto/featured/blob/2a6a9664e5428b37abe4957c1dca0994f4a8b7fd/LICENSES/Unlicense"
#> image = "https://github.com/JuliaRegistries/General/assets/6933510/9a925232-6a75-47e7-9ab9-f384bc389602"
#> order = "5.1"
#> title = "Turtles – showcase"
#> date = "2024-08-10"
#> tags = ["turtle", "basic"]
#> description = "🐢 A couple of cool artworks made with simple Julia code"
#> license = "Unlicense"
#> 
#>     [[frontmatter.author]]
#>     name = "Pluto.jl"
#>     url = "https://github.com/JuliaPluto"

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

# ╔═╡ 1ff23021-4eb3-458d-a07e-0c5083eb4c4f
using WasmMakie, PlutoUI

# ╔═╡ 86e25a9c-b877-45cb-8a57-4643dd1fc266
md"""
# Turtle art!

This notebook recreates some famous works of art with simple turtle code — and every drawing is a [WasmMakie.jl](https://github.com/GroupTherapyOrg/WasmMakie.jl) figure, so the interactive ones recompute right in your browser via WebAssembly.
"""

# ╔═╡ aa000001-7474-4c1e-9000-000000000001
# A tiny turtle, drawn with WasmMakie — same API as PlutoTurtles.jl
# (forward!/backward!/right!/left!/penup!/pendown!/color!), but every
# drawing is a Figure whose strokes can recompute inside a wasm island.
begin
	mutable struct Turtle
		pos::NTuple{2,Float64}
		heading::Float64                 # degrees, 0 = north, clockwise
		pen::Bool
		color::NTuple{4,Float64}
		xs::Vector{Vector{Float64}}      # one polyline per pen stroke
		ys::Vector{Vector{Float64}}
		cols::Vector{NTuple{4,Float64}}
	end
	Turtle() = Turtle((0.0, 0.0), 0.0, true, (0.0, 0.0, 0.0, 1.0),
		Vector{Float64}[], Vector{Float64}[], NTuple{4,Float64}[])

	function forward!(t::Turtle, d)
		x2 = t.pos[1] + Float64(d) * sind(t.heading)
		y2 = t.pos[2] + Float64(d) * cosd(t.heading)
		if t.pen
			# extend the running stroke when contiguous + same color
			if !isempty(t.xs) && t.cols[end] == t.color &&
			   t.xs[end][end] == t.pos[1] && t.ys[end][end] == t.pos[2]
				push!(t.xs[end], x2)
				push!(t.ys[end], y2)
			else
				push!(t.xs, [t.pos[1], x2])
				push!(t.ys, [t.pos[2], y2])
				push!(t.cols, t.color)
			end
		end
		t.pos = (x2, y2)
		t
	end
	backward!(t::Turtle, d) = forward!(t, -d)
	right!(t::Turtle, a) = (t.heading += Float64(a); t)
	left!(t::Turtle, a) = (t.heading -= Float64(a); t)
	penup!(t::Turtle) = (t.pen = false; t)
	pendown!(t::Turtle) = (t.pen = true; t)

	function color!(t::Turtle, c::String)
		t.color =
			c == "black"  ? (0.0, 0.0, 0.0, 1.0) :
			c == "white"  ? (1.0, 1.0, 1.0, 1.0) :
			c == "red"    ? (1.0, 0.0, 0.0, 1.0) :
			c == "yellow" ? (1.0, 1.0, 0.0, 1.0) :
			c == "blue"   ? (0.0, 0.0, 1.0, 1.0) :
			(0.0, 0.0, 0.0, 1.0)
		t
	end

	# hsl color directly (avoids string parsing) — h in degrees, s/l in 0–1
	function color_hsl!(t::Turtle, h, s, l)
		hf = mod(Float64(h), 360.0) / 60.0
		c = (1.0 - abs(2.0 * l - 1.0)) * s
		x = c * (1.0 - abs(mod(hf, 2.0) - 1.0))
		m = l - c / 2.0
		r, g, b =
			hf < 1.0 ? (c, x, 0.0) :
			hf < 2.0 ? (x, c, 0.0) :
			hf < 3.0 ? (0.0, c, x) :
			hf < 4.0 ? (0.0, x, c) :
			hf < 5.0 ? (x, 0.0, c) : (c, 0.0, x)
		t.color = (r + m, g + m, b + m, 1.0)
		t
	end

	function turtle_drawing(f::Function; background::String = "white")
		t = Turtle()
		f(t)
		fig = Figure(size = (320, 320))
		ax = Axis(fig[1, 1])
		hidedecorations!(ax)
		hidespines!(ax)
		ax.xmin = -15.0; ax.xmax = 15.0
		ax.ymin = -15.0; ax.ymax = 15.0
		if background != "white"
			bg = background == "#000088" ? (0.0, 0.0, 8.0 / 15.0, 1.0) : (1.0, 1.0, 1.0, 1.0)
			hspan!(ax, [-15.0], [15.0]; color = bg)
		end
		for k in 1:length(t.xs)
			lines!(ax, t.xs[k], t.ys[k]; color = t.cols[k], linewidth = 1.5)
		end
		fig
	end
	turtle_drawing_fast(f::Function; background::String = "white") =
		turtle_drawing(f; background)
end

# ╔═╡ 0d7fb9e7-3437-4ff9-9de6-1f3f8a93dfff
md"""## "_The Starry Night_" 
Vincent van Gogh (1889)"""

# ╔═╡ abe23881-0354-4068-8115-451f7b3307c7
@bind GO_gogh CounterButton("Another one!")

# ╔═╡ 75b23160-aada-4e48-8b16-ddd2c6c8df1f
function draw_star(turtle, points, size)
	for i in 1:points
		right!(turtle, 360 / points)
		forward!(turtle, size)
		backward!(turtle, size)
	end
end

# ╔═╡ 426a1f52-32dd-4b63-a274-27e1cf139742
md"""## "_Tableau I_"
Piet Mondriaan (1913)"""

# ╔═╡ f30d72d7-7894-4229-8f25-509195563097
@bind GO_mondriaan CounterButton("Another one!")

# ╔═╡ ff2294a6-2bd0-461c-bc38-02f157d86660
md"""## "_Een Boom_"
Luka van der Plas (2020)"""

# ╔═╡ b6b1690b-6427-4ff3-9abf-b499f4661c39
@bind fractal_angle Slider(0:90; default=49)

# ╔═╡ 59963c46-ee42-4989-bff4-90f12606193e
@bind fractal_tilt Slider(0:90; default=36)

# ╔═╡ 5f6beed8-33ae-463c-9d28-09e3a4235936
@bind fractal_base Slider(0:0.01:2; default=1)

# ╔═╡ 18a97ce6-ae85-46a2-b294-830473fe80cd
function lindenmayer(turtle, depth, angle, tilt, base)
	if depth < 10
		old_pos = turtle.pos
		old_heading = turtle.heading

		size = base * .5 ^ (depth * 0.5)

		pendown!(turtle)
		color_hsl!(turtle, depth * 30, 0.8, 0.5)
		forward!(turtle, size * 8)
		right!(turtle, tilt / 2)
		lindenmayer(turtle, depth + 1, angle, tilt, base)
		left!(turtle, angle)
		lindenmayer(turtle, depth + 1, angle, tilt, base)


		turtle.pos = old_pos
		turtle.heading = old_heading
	end
end

# ╔═╡ 83cd894b-2be0-48c7-b5e7-8db7ed96c13f
fractal = turtle_drawing_fast() do t
	penup!(t)
	backward!(t, 15)
	pendown!(t)
	lindenmayer(t, 0, fractal_angle, fractal_tilt, fractal_base)
end

# ╔═╡ e51d4b19-fa30-4643-8d12-407941a4757d
md"""
## "_Een coole spiraal_" 
fonsi (2020)
"""

# ╔═╡ 6deab6a2-f298-42a8-9c86-db8a2a26ac17
@bind angle Slider(0:90; default=20)

# ╔═╡ c668c791-9c3b-4eed-babe-9a484a88b68e
turtle_drawing() do t

	let i = 0.0
		while i <= 10.0
			right!(t, angle)
			forward!(t, i)
			i += 0.1
		end
	end

end

# ╔═╡ 897cc639-5ab6-48fe-bdba-19aa4e8bad15
# A tiny deterministic PRNG (xorshift64*) — pure Julia, so the random art
# recomputes identically inside the wasm islands. Seeded by the buttons.
begin
	mutable struct ArtRNG
		state::UInt64
	end
	ArtRNG(seed::Integer) = ArtRNG(UInt64(seed + 1) * 0x9e3779b97f4a7c15 + 0x2545f4914f6cdd1d)

	function nextfloat!(r::ArtRNG)
		s = r.state
		s ⊻= s << 13
		s ⊻= s >> 7
		s ⊻= s << 17
		r.state = s
		Float64(s >> 11) / 9.007199254740992e15   # [0, 1)
	end
	rand_between!(r::ArtRNG, lo, hi) = Float64(lo) + nextfloat!(r) * (Float64(hi) - Float64(lo))
	rand_choice!(r::ArtRNG, xs) = xs[1 + Int(floor(nextfloat!(r) * length(xs)))]
end

# ╔═╡ 70402e12-22c2-47fd-99be-aa6cd15ce2c3
starry_night = turtle_drawing_fast(background = "#000088") do t
	rng = ArtRNG(GO_gogh + 7)
	
	star_count = 100
	
	color!(t, "yellow")
	
	for i in 1:star_count
		#move
		penup!(t)
		random_angle = nextfloat!(rng) * 360
		right!(t, random_angle)
		random_distance = rand_between!(rng, 1.0, 8.0)
		forward!(t, random_distance)
		
		#draw star
		pendown!(t)
		
		draw_star(t, 5, 1)
	end
end

# ╔═╡ ab4d46eb-d441-47c3-b061-2611b2e44009
function draw_mondriaan(rng::ArtRNG, turtle::Turtle, width::Float64, height::Float64)
	#propbability that we make a mondriaan split
	p = if width * height < 8.0
		0.0
	else
		((width * height) / 900.0) ^ 0.5
	end

	if nextfloat!(rng) < p
		#split into halves

		split = rand_between!(rng, width * 0.1, width * 0.9)

		#draw split
		forward!(turtle, split)
		right!(turtle, 90)
		color!(turtle, "black")
		pendown!(turtle)
		forward!(turtle, height)
		penup!(turtle)

		#fill in left of split
		right!(turtle, 90)
		forward!(turtle, split)
		right!(turtle, 90)
		draw_mondriaan(rng, turtle, height, split)
		
		#fill in right of split
		forward!(turtle, height)
		right!(turtle, 90)
		forward!(turtle, width)
		right!(turtle, 90)
		draw_mondriaan(rng, turtle, height, width - split)
		
		#walk back
		right!(turtle, 90)
		forward!(turtle, width)
		right!(turtle, 180)
		
	else
		#draw a colored square
		square_color = rand_choice!(rng, ("white", "white", "white", "red", "yellow", "blue"))
		color!(turtle, square_color)
		stripe_xs = Float64[]
		let sx = 0.4
			while sx <= width - 0.4
				push!(stripe_xs, sx)
				sx += 0.4
			end
		end
		(isempty(stripe_xs) || stripe_xs[end] != width - 0.4) && push!(stripe_xs, width - 0.4)
		for x in stripe_xs
			forward!(turtle, x)
			right!(turtle, 90)
			forward!(turtle, .2)
			pendown!(turtle)
			forward!(turtle, height - .4)
			penup!(turtle)
			right!(turtle, 180)
			forward!(turtle, height - .2)
			right!(turtle, 90)
			backward!(turtle, x)
		end
	end
end

# ╔═╡ d400d8d6-de2c-4886-86b9-ffd9e5f4e073
# turtle_drawing_fast() is the same as turtle_drawing(), but it does not show a little turtle taking the individual steps

mondriaan = turtle_drawing_fast() do t
	rng = ArtRNG(GO_mondriaan + 7)
	size = 30.0

	#go to top left corner
	penup!(t)
	forward!(t, size / 2)
	left!(t, 90)
	forward!(t, size / 2)
	right!(t, 180)

	#draw painting
	draw_mondriaan(rng, t, size, size)
	
	#white border around painting
	color!(t, "white")
	pendown!(t)
	for i in 1:4
		forward!(t, size)
		right!(t, 90)
	end
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
# ╟─86e25a9c-b877-45cb-8a57-4643dd1fc266
# ╠═1ff23021-4eb3-458d-a07e-0c5083eb4c4f
# ╟─aa000001-7474-4c1e-9000-000000000001
# ╟─0d7fb9e7-3437-4ff9-9de6-1f3f8a93dfff
# ╟─abe23881-0354-4068-8115-451f7b3307c7
# ╟─70402e12-22c2-47fd-99be-aa6cd15ce2c3
# ╠═75b23160-aada-4e48-8b16-ddd2c6c8df1f
# ╟─426a1f52-32dd-4b63-a274-27e1cf139742
# ╟─f30d72d7-7894-4229-8f25-509195563097
# ╟─d400d8d6-de2c-4886-86b9-ffd9e5f4e073
# ╟─ab4d46eb-d441-47c3-b061-2611b2e44009
# ╟─ff2294a6-2bd0-461c-bc38-02f157d86660
# ╟─b6b1690b-6427-4ff3-9abf-b499f4661c39
# ╟─59963c46-ee42-4989-bff4-90f12606193e
# ╟─5f6beed8-33ae-463c-9d28-09e3a4235936
# ╠═83cd894b-2be0-48c7-b5e7-8db7ed96c13f
# ╟─18a97ce6-ae85-46a2-b294-830473fe80cd
# ╟─e51d4b19-fa30-4643-8d12-407941a4757d
# ╠═6deab6a2-f298-42a8-9c86-db8a2a26ac17
# ╠═c668c791-9c3b-4eed-babe-9a484a88b68e
# ╠═897cc639-5ab6-48fe-bdba-19aa4e8bad15
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
