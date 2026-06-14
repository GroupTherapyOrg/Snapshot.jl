### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> license_url = "https://github.com/JuliaPluto/featured/blob/2a6a9664e5428b37abe4957c1dca0994f4a8b7fd/LICENSES/Unlicense"
#> image = "https://github.com/JuliaPluto/featured/assets/6933510/65dadde7-6381-4cda-ad71-7bbba4b1db97"
#> title = "Convolutions"
#> tags = ["convolution", "filter", "signal-processing", "math", "signal processing"]
#> date = "2023-09-20"
#> description = "Learn about the cool concept of convolution on continuous functions!"
#> license = "Unlicense"
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

# ╔═╡ 3fd4b34c-18ed-4b07-b594-01afb377ead7
begin
	# plotting:
	using WasmMakie, ColorSchemes, Colors

	# widgets and layout:
	using PlutoUI
	using PlutoUI.ExperimentalLayout: grid, vbox, hbox, Div
	using HypertextLiteral
end

# ╔═╡ 00358bc2-1e49-45a9-9b78-293aadd40976
md"""## Convolutions *Explained*

#### Introduction
Hello there! If you ever came across convolutions in some certain science context, you know they can be VERY confusing. This notebook will help you get a better intuition for convolutions. Let's go!"""

# ╔═╡ f265f5b9-d5d0-45ce-a850-f4237218cf99
md"""
#### A new disease appears - oh no
"""

# ╔═╡ dbdbcbbe-57fd-497f-b5ba-83b61e87de0b
md"""Let's start with this great example from the [**better explained blog** ](https://betterexplained.com/articles/intuitive-convolution/) : Suppose there is a **pandemic** going on and more people are getting sick every day. So, you are a doctor and you have the following **new** patients coming in each day (yes, sadly even elves and fairies can get this disease): 
"""

# ╔═╡ f97f9f46-b5c7-4cee-a69f-1eb53b560952
md"""The number of patients increases as the disease spreads."""

# ╔═╡ 796aad78-36d4-42fd-a467-707692b094a2


# ╔═╡ adfc8467-93bf-472e-a9fc-bd502caa5daa
md"""
#### But we have a treatment, puh!
"""

# ╔═╡ f9df01a1-8fb7-4337-9415-9ab56d9c696a
md"""The patients all have the same disease that requires the following treatment: 
- On the 1st day, the patient receives 1 pill 
- On the 2nd day, the patient receives 2 pills
- On the nth day, the patient receives n pills

So something that looks like this: """

# ╔═╡ bb869b27-0bce-4314-b28f-684ccc14f7ea
md"""> **Try it:** Choose your own treatment plan (you can also chose 0 pills for a certain day):"""

# ╔═╡ faf156f0-fa3f-46f6-98d3-3bbf0690a0a4
begin
	a1 = @bind a1_s PlutoUI.Scrubbable(0:1:6, default=1)
	a2 = @bind a2_s PlutoUI.Scrubbable(0:1:6, default=2)
	a3 = @bind a3_s PlutoUI.Scrubbable(0:1:6, default=3)
	a4 = @bind a4_s PlutoUI.Scrubbable(0:1:6, default=4)
	a5 = @bind a5_s PlutoUI.Scrubbable(0:1:6, default=0)
	a6 = @bind a6_s PlutoUI.Scrubbable(0:1:6, default=0)
	a7 = @bind a7_s PlutoUI.Scrubbable(0:1:6, default=0)
	a8 = @bind a8_s PlutoUI.Scrubbable(0:1:6, default=0)
	
end;

# ╔═╡ 88e4551f-9ae1-4a5f-819b-01c43a319981
begin
	#treatment_array = @bind treatment_in PlutoUI.Scrubbable(treatment_array)
	md""" $(a1) $(a2) $(a3) $(a4) $(a5) $(a6) $(a7) $(a8)"""
end

# ╔═╡ 27bd1602-3ca0-4daf-a9ff-c76ea818ead4
md"""
### But, how many pills do we need to stockpile?
"""

# ╔═╡ 572bd8d5-65b0-462e-a143-811f4bfa875e
md"""---
Now to make things more visual, move the slider around to see how many pills you need each day!"""

# ╔═╡ 1fd4973b-8a25-4ddb-ac6d-3fb444a5ed2c
md"""**Hint:** In order to administer the treatment in the right order, we need to **flip** patients lists, so they get admitted to the hospital in the right order! So now it looks like this: 
"""

# ╔═╡ 0ccf60db-75b2-466d-935e-f39855bc36f7
md"""## Generating Code """

# ╔═╡ e4a17824-0e9f-442e-82bc-62b8d46e88e5
md"""The following code sets up our initial figure. If you're interested in drawing graphs in computer science, you can take a look but you don't need to understand every line."""

# ╔═╡ 032130c4-686b-4db9-9753-9b0fe764f94e
begin
	# Number of time steps
	nb = 8 

	# Slider for how long the pandemic should go 
	len_slider = @bind len PlutoUI.Slider(3:1:nb-1, show_value=true, default=5)

	# Checkboxes for more options
	show_stairs = @bind stairs CheckBox(default=true)
	make_exponential = @bind exponential CheckBox()
		
end;

# ╔═╡ 380ba7f0-76e6-47ec-98e2-e6c6a3b7f2d5
patients = exponential ? collect(["👵","🧑👴", "🧑🧔🏼🧝🧚", "👧👴👴👩🧝🧚👩🧓", "👵🧝🧑👴🧑🧝🧝🧚🧓🧚🧓🧚🧑🧝🧝🧝", "👵🧝🧑👴🧑👵🧝🧑👴🧑🧓🧚👩🧝🧚👩👩🧝🧚👩👴👴👩🧝🧚🧓🧚🧓👴👵🧑🧑", "🧚🧚🧚🧚🧚🧚🧚🧚🧚🧓🧚🧓🧚🧑🧝🧝👧👴👴👩🧝🧚👩🧓👧👴👴👩🧝🧚👩🧓👵🧝🧑👴🧑👵🧝🧑👴🧑🧓🧚👩🧝🧚👩👩🧝🧚👩👴👴👩🧝🧚🧓🧚🧓👴👵🧑🧑🧑", ""])[1:len] :  collect(["👵","👴🧑", "👩🧔🏼🧝🧚", "👧👴👴👩🧝🧚👩🧓", "👵🧝🧑👴", "🧓🧚", "🧚", ""])[1:len] 

# ╔═╡ a60029d5-ae8d-4704-bef1-076949712c37
patients_flipped = append!(["" for i in 1:8-length(patients)], reverse(patients))

# ╔═╡ 9243a029-8f8d-4a28-b098-d2a2810a8786
md"""**Try it:** How many days should the disease go on:  $(len_slider) day(s)"""

# ╔═╡ bccfdd98-b425-4f8d-a58d-489134851ebd
begin
	# Set slider for the day (index)
	k_slider = @bind k_conv PlutoUI.Slider(1:2*nb+1, show_value=true, default=1)
	md"""**Try it:**: calculate up to day: $(k_slider)
	> **Test your understanding**: On what day do you require most pills?"""
end

# ╔═╡ e63c92a5-659e-41f7-85a4-c2f3baffcef6
md"""## Appendix"""

# ╔═╡ 05df72e9-f45b-49c3-8015-9212f439cf72
# (the emoji-pill PNG download is gone — WasmMakie markers are plain shapes,
# so the visualization is fully self-contained and wasm-compilable)

# ╔═╡ 9fab3bbb-5c7f-4464-97c9-847f52754845
treatment_in = [a1_s, a2_s, a3_s, a4_s, a5_s, a6_s, a7_s, a8_s];

# ╔═╡ 9274ed36-a28e-42f3-879f-167d5afa6fc7
treatment = vec([repeat('💊', i) for i in treatment_in])

# ╔═╡ f0d08486-0086-48da-baeb-169f3812d0ea
let
	t = treatment
	p = patients
md"""Now as a doctor, you want to be ready for this scenario, at each day you want to know, how many pills you will need for your patients:

- On day 1: you would give $((t[1]))  to $((p[1])) 
- On day 2: you would give $((t[2]))  to $((p[1]))  , and $((t[1]))  to $((p[2]))  each
- On day 3: you would give  $((t[3]))  to $(length(p[1])) , and $((t[2])) pills to $((p[2])) , and $((t[1]))  to $((p[3]))  each ... etc 

Notice how we are multiplying and adding each day? We are close to performing a convolution already!
"""
end

# ╔═╡ 472b52d8-e787-4a93-83d8-c53e977a143c
begin
	# Set the number of patients array (First function)
	numbers_patients = [length(s) for s in patients_flipped]
	y2_patients = append!([0 for i in 1:9], numbers_patients, [0 for i in 1:16-length(patients_flipped)])

	# Set the number of pills array (Second function)
	numbers_pills = [length(s) for s in treatment]
	y1_pills = append!([0 for i in 1:9], numbers_pills, [0 for i in 1:16-length(numbers_pills)])

	# Set the function to draw the patients moving
	if k_conv < 9 idx = 9 - k_conv else idx = 34 - k_conv end
	y2_patients_draw = y2_patients[[idx+1:end; 1:idx]]

end;

# ╔═╡ 8680db2e-3dda-4aff-a00e-130ac1f4486c
# Stack `count` markers above x — style :patient (big ringed circle),
# :pill (small filled circle) or :pillghost (translucent grey circle).
function draw_point(x, count, ax::Axis, style::Symbol, size_marker, color::NTuple{4,Float64}, offset::Int, masked=false)
	for y = 1:count[1]
		if style == :patient
			scatter!(ax, [Float64(x) + 0.1], [Float64(y + offset)];
				markersize = Float64(size_marker), marker = :circle,
				color = (1.0, 1.0, 1.0, 1.0))
			scatter!(ax, [Float64(x) + 0.1], [Float64(y + offset)];
				markersize = 0.62 * Float64(size_marker), marker = :circle, color = color)
		elseif style == :pillghost
			scatter!(ax, [Float64(x) - 0.2], [Float64(y + offset)];
				markersize = Float64(size_marker), marker = :circle,
				color = (0.5, 0.5, 0.5, 0.2))
		else
			scatter!(ax, [Float64(x) - 0.2], [Float64(y + offset)];
				markersize = Float64(size_marker), marker = :circle, color = color)
		end
	end
end

# ╔═╡ c2455fae-f733-4e59-b2d0-a76913810f15
function draw_grey_points(x, y, ax, len, style, size_marker, colors, masked=false)

	for j in 1:len
			color = colors[mod(j, length(colors)) + 1]
			draw_point(x[j], y[j], ax, style, size_marker, color, 0, masked)

	end
end

# ╔═╡ ca75244c-69ac-45c8-aa33-59c05dc4091b
# The convolution itself, written out explicitly — this is the whole point of
# the notebook, and the same loop runs inside the WebAssembly island.
function simple_conv(a, b)
	n = length(a)
	m = length(b)
	out = fill(0.0, n + m - 1)
	for i in 1:n
		for j in 1:m
			out[i + j - 1] += Float64(a[i]) * Float64(b[j])
		end
	end
	out
end

# ╔═╡ d7ce43e5-7af7-4182-9992-1501e6d2e532
# (grey-pill ghost markers are now translucent grey circles — see draw_point)

# ╔═╡ 0dd8235c-c09b-49ae-b02a-4bbb285970a6
happyX = findlast(treatment_in .> 0)

# ╔═╡ df178bb8-3b81-4c4b-ba94-3ad945e63007
begin
	_rgba(c) = (Float64(red(c)), Float64(green(c)), Float64(blue(c)), 1.0)
	color_grey = (0.5, 0.5, 0.5, 1.0)
	colors = [_rgba(ColorSchemes.viridis[i]) for i in 1:40:256]
	col_length = length(colors)
	color_blue = _rgba(ColorSchemes.viridis[116])
end;

# ╔═╡ da0a4117-629e-42b5-95ae-d49f10769830
function draw_all(l, k, k_conv, x, x_conv, y1, y2, y2_draw, y12, y3, ax1, ax2, ax3, grey_marker, color_marker, masked=false)
	offset = 0
	for index in k:k+nb
		scatter!(ax3, [Float64(x_conv[k_conv])], [Float64(y3[k_conv])]; color = colors[1])

		if index < 1 || index > l
			continue
		end

		color = colors[mod(index, col_length) + 1]


		draw_point(x[index], y12[index], ax2, :pill, color_marker, color, 0)
		draw_point(x_conv[k_conv], y12[index], ax3, :pill, color_marker, color, offset)

		draw_point(x[index], y12[index], ax2, :pillghost, grey_marker, color, 0)

		if y1[index] != 0 && y2_draw[index] != 0
			draw_point(x[index], y2_draw[index], ax1, :patient, grey_marker, color, 0, masked)
		end

		offset += y12[index]
	end
end

# ╔═╡ ceb05a23-93b8-4423-a5f9-f6e3d961d0c6
begin
	# Set up Figure elements
	f = Figure(size = (650, 700))

	ax1 = Axis(f[1, 1]; ylabel = "New patients")

	ax2 = Axis(f[2, 1]; ylabel = "New pills required")

	ax3 = Axis(f[3, 1];
			ylabel = "Stockpile required",
			xlabel = "Day")

	# Set up range and constants
	# plain Float64 vectors — range iteration/broadcast is not
	# wasm-compilable yet (WASM_FINDINGS #7)
	x = Float64[]
	for k in -nb:2*nb
		push!(x, Float64(k))
	end
	x_conv = Float64[]
	for k in -nb:5*nb
		push!(x_conv, Float64(k) - nb*1.5 + 4)
	end
	l = length(x)
	k = k_conv - nb +1

	# Marker sizes (plain circles — pills are small dots, patients big rings)
	grey_marker = 16.0
	color_marker = 7.0

	# Set up the functions
	y1 = y1_pills
	y2 = y2_patients
	y2_draw = y2_patients_draw

	# Intermediate step for convolution
	y12_draw = y1 .* y2_draw
	y12 = y1 .* y2

	# Set up the final convoluted result
	y3 = simple_conv(y1, reverse(y2))

	# Draw vertical "current day" lines
	vlines!(ax1, [Float64(k_conv - 1)]; color = color_blue)
	vlines!(ax2, [Float64(k_conv - 1)]; color = color_blue)
	vlines!(ax3, [Float64(k - 2 + nb/2 + 4)]; color = color_blue)

	# Get the top value of each plot
	max_ax1 = maximum([maximum(y1), maximum(y2)]) + 2
	max_ax2 = maximum(y1) * maximum(y2) + 2

	# Draw the function lines
	if stairs
		stairs!(ax1, x, y1; color = colors[6], step=:center)
		stairs!(ax1, x, y2_draw; color = colors[4], step=:center)
		stairs!(ax2, x, y12_draw; color = colors[7], step=:center)
		stairs!(ax3, x_conv, y3; color=colors[1], step=:center)
	end

	# Draw the points on the graph for the current day
	draw_grey_points(x, y2_draw, ax1, l, :patient, grey_marker, [color_grey], true)
	draw_grey_points(x, y1, ax1, l, :pill, color_marker, colors)

	draw_all(l, k+nb, k_conv+2*nb, x, x_conv, y1, y2, y2_draw, y12_draw, y3, ax1, ax2, ax3, grey_marker, color_marker, true)

	draw_grey_points(x, y1, ax1, l, :pillghost, grey_marker, [color_grey])
	draw_grey_points(x_conv, y3, ax3, 4*nb -1, :pillghost, grey_marker, [color_grey])


	# Set the axes limits
	ax1.xmin = -4.0; ax1.xmax = 12.0
	ax2.xmin = -4.0; ax2.xmax = 12.0
	ax3.xmin = -4.0; ax3.xmax = 12.0
	ax1.ymin = -1.0; ax1.ymax = Float64(max_ax1)
	ax2.ymin = -0.2 * Float64(max_ax2); ax2.ymax = Float64(max_ax2)
	ax3.ymin = -1.0; ax3.ymax = Float64(maximum(y3) + 7)

end;

# ╔═╡ 6b243243-8f26-4f2d-8727-564f0701b302
f

# ╔═╡ c4f25a29-009e-47e4-adc0-18c94e247df4
sidebar = Div([
	@htl("""
	<header>
	<span class="sidebar-toggle open-sidebar">🕹</span>
	<span class="sidebar-toggle closed-sidebar">🕹</span>
	Interactive Sliders
	</header>
	"""),
	md"""
	Here are all interactive bits of the notebook at one place. Feel free to change them!
	"""
], class="plutoui-sidebar aside")

# ╔═╡ 110068f5-0433-40bc-ab9e-cafe8fa3cc68
sidebar2 = Div([
	md""" **Choose a day:**""",
	k_slider,
	md"""**Choose how long the pandemic is:**""",
	len_slider, 
	md"""**Change the treatment:**""",
	md""" $(a1) $(a2) $(a3) $(a4) $(a5) $(a6) $(a7) $(a8)""",
	md"""**Make the pandemic exponential:** $(make_exponential)""",
	md"""**Show the stairs** $(show_stairs)"""
], class="plutoui-sidebar aside third")

# ╔═╡ 9ad51efd-a487-4153-ac3a-077ae99905bc
html"""
<style>
	div.plutoui-sidebar.aside {
		position: fixed;
		right: 1rem;
		top: 10rem;
		width: min(80vw, 300px);
		padding: 10px;
		border: 3px solid rgba(0, 0, 0, 0.15);
		border-radius: 10px;
		box-shadow: 0 0 11px 0px #00000010;
		max-height: calc(100vh - 5rem - 56px);
		overflow: auto;
		z-index: 40;
		background: white;
		transition: transform 300ms cubic-bezier(0.18, 0.89, 0.45, 1.12);
		color: var(--pluto-output-color);
		background-color: var(--main-bg-color);
	}

	.second {
		top: 17.5rem !important;
	}

	.third {
		top: 17.5rem !important;
	}
	
	div.plutoui-sidebar.aside.hide {
		transform: translateX(calc(100% - 28px));
	}
	
	.plutoui-sidebar header {
		display: block;
		font-size: 1.5em;
		margin-top: -0.1em;
		margin-bottom: 0.4em;
		padding-bottom: 0.4em;
		margin-left: 0;
		margin-right: 0;
		font-weight: bold;
		border-bottom: 2px solid rgba(0, 0, 0, 0.15);
	}
	
	.plutoui-sidebar.aside.hide .open-sidebar, .plutoui-sidebar.aside:not(.hide) .closed-sidebar, .plutoui-sidebar:not(.aside) .closed-sidebar {
		display: none;
	}

	.sidebar-toggle {
		cursor: pointer;
	}
	
</style>
<script>
	let listener = event => {
		if (event.target.classList.contains("sidebar-toggle")) {
			document.querySelectorAll('.plutoui-sidebar').forEach(function(el) {
				el.classList.toggle("hide");
			});
		}
	}
	document.addEventListener('click', listener);
	invalidation.then(() => {
		document.removeEventListener('click', listener);
	})
</script>
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
ColorSchemes = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

[sources]
WasmMakie = {url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"}

[compat]
ColorSchemes = "~3.31.0"
Colors = "~0.13.1"
HypertextLiteral = "~1.0.0"
PlutoUI = "~0.7.83"
WasmMakie = "~0.1.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "80147987562c62e8ec99a0218f738ac72a73c5da"

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

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "8b3b6f87ce8f65a2b4f857528fd8d70086cd72b1"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.0"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

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

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "edbeefc7a4889f528644251bdb5fc9ab5348bc2c"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "8b770b60760d4451834fe79dd483e318eee709c4"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.2"

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

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

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

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

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
# ╟─00358bc2-1e49-45a9-9b78-293aadd40976
# ╟─f265f5b9-d5d0-45ce-a850-f4237218cf99
# ╟─dbdbcbbe-57fd-497f-b5ba-83b61e87de0b
# ╟─380ba7f0-76e6-47ec-98e2-e6c6a3b7f2d5
# ╟─f97f9f46-b5c7-4cee-a69f-1eb53b560952
# ╟─9243a029-8f8d-4a28-b098-d2a2810a8786
# ╟─796aad78-36d4-42fd-a467-707692b094a2
# ╟─adfc8467-93bf-472e-a9fc-bd502caa5daa
# ╟─f9df01a1-8fb7-4337-9415-9ab56d9c696a
# ╟─9274ed36-a28e-42f3-879f-167d5afa6fc7
# ╟─bb869b27-0bce-4314-b28f-684ccc14f7ea
# ╟─88e4551f-9ae1-4a5f-819b-01c43a319981
# ╟─faf156f0-fa3f-46f6-98d3-3bbf0690a0a4
# ╟─27bd1602-3ca0-4daf-a9ff-c76ea818ead4
# ╟─f0d08486-0086-48da-baeb-169f3812d0ea
# ╟─572bd8d5-65b0-462e-a143-811f4bfa875e
# ╟─1fd4973b-8a25-4ddb-ac6d-3fb444a5ed2c
# ╟─a60029d5-ae8d-4704-bef1-076949712c37
# ╟─bccfdd98-b425-4f8d-a58d-489134851ebd
# ╠═6b243243-8f26-4f2d-8727-564f0701b302
# ╟─0ccf60db-75b2-466d-935e-f39855bc36f7
# ╟─e4a17824-0e9f-442e-82bc-62b8d46e88e5
# ╠═032130c4-686b-4db9-9753-9b0fe764f94e
# ╠═472b52d8-e787-4a93-83d8-c53e977a143c
# ╠═ceb05a23-93b8-4423-a5f9-f6e3d961d0c6
# ╟─e63c92a5-659e-41f7-85a4-c2f3baffcef6
# ╠═3fd4b34c-18ed-4b07-b594-01afb377ead7
# ╠═05df72e9-f45b-49c3-8015-9212f439cf72
# ╠═9fab3bbb-5c7f-4464-97c9-847f52754845
# ╟─da0a4117-629e-42b5-95ae-d49f10769830
# ╟─8680db2e-3dda-4aff-a00e-130ac1f4486c
# ╟─c2455fae-f733-4e59-b2d0-a76913810f15
# ╟─ca75244c-69ac-45c8-aa33-59c05dc4091b
# ╟─d7ce43e5-7af7-4182-9992-1501e6d2e532
# ╟─0dd8235c-c09b-49ae-b02a-4bbb285970a6
# ╠═df178bb8-3b81-4c4b-ba94-3ad945e63007
# ╠═c4f25a29-009e-47e4-adc0-18c94e247df4
# ╠═110068f5-0433-40bc-ab9e-cafe8fa3cc68
# ╠═9ad51efd-a487-4153-ac3a-077ae99905bc
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
