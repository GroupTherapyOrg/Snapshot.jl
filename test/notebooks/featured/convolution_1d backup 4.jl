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
	# packages for convolution:
	using DSP, SignalAnalysis, Random

	# plotting:
	using CairoMakie, ColorSchemes, Colors, ColorTypes
	using MakieThemes
	set_theme!(ggthemr(:flat))

	# widgets and layout:
	using PlutoUI
	using PlutoUI.ExperimentalLayout: grid, vbox, hbox, Div
	using HypertextLiteral
end

# ╔═╡ ca75244c-69ac-45c8-aa33-59c05dc4091b
begin
	import CairoMakie:Polygon
	using GeometryBasics
	function plot_pill(emoji_pill_pic::Matrix)
		positions = Colors.alpha.(emoji_pill_pic).<0.5

		curr_fig = Figure()
		curr_ax = Axis(curr_fig[1, 1])
		contour_plot = contour!(curr_ax, positions, levels=1, labels = false)
		pill_points = contour_plot.plots[2].converted[1][]./10
		pill_points = [Point2f.(0.5 .+6 .- p.data[1] .-3.5,p.data[2] .- 3.5) for p in pill_points]

		pill_shape = Polygon(pill_points[1:end-1])
		return pill_shape
	end
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
begin
	# Makie can't display emojis directly, so we have to grab them from github - sorry
	import PNGFiles
	emoji_pill_pic = PNGFiles.load(download("https://cdn.jsdelivr.net/gh/pranabdas/github-emojis@c0632da/assets/png/pill.png")) .|> RGBA{Float64};
end;

# ╔═╡ 9fab3bbb-5c7f-4464-97c9-847f52754845
treatment_in = [a1_s a2_s a3_s a4_s a5_s a6_s a7_s a8_s];

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

# ╔═╡ d7ce43e5-7af7-4182-9992-1501e6d2e532
function plot_grey_pill(emoji_pill_pic::Matrix{RGBA{Float64}})
	emoji_pill_org = deepcopy(emoji_pill_pic)
	grey_pill = GrayA.(emoji_pill_org)
	for k = 1:length(grey_pill)
		grey_pill[k] = GrayA(grey_pill[k].val,grey_pill[k].alpha* 0.2)
	end
	return grey_pill
end

# ╔═╡ 0dd8235c-c09b-49ae-b02a-4bbb285970a6
happyX = findlast(treatment_in[1,:] .> 0)

# ╔═╡ 8680db2e-3dda-4aff-a00e-130ac1f4486c
function draw_point(x, y1, ax::Axis, marker, size_marker, color::ColorTypes.RGB{Float64}, offset::Int, masked=false)
		stroke = masked ? :black : :grey 
		z = 0
	size_marker = 0.8*size_marker
		for y = 1:y1[1]
			#@show stroke,color,masked
			#@show marker
			if marker == '😷'
		
				obj = scatter!(ax,[x.+0.1],[y.+offset], markersize=40,strokewidth=0.0,marker='⚫', strokecolor=stroke, color=RGB{Float64}(1,1,1), overdraw=masked)
				#translate!(obj[1], 0, 0, z)
				#z += 0.1
				obj = scatter!(ax,[x.+0.1],[y.+offset], markersize=size_marker,strokewidth=0.0,marker= x > happyX ? '😄' : marker, strokecolor=stroke, color=color, overdraw=masked)
				#translate!(obj[1], 0, 0, z)
				#z -= 0.3
	
			else
			
				scatter!(ax,[x.-0.2],[y.+offset], markersize=size_marker,strokewidth=0.0,marker=marker, strokecolor=stroke, color=color, overdraw=masked)
			end
		end
end

# ╔═╡ c2455fae-f733-4e59-b2d0-a76913810f15
function draw_grey_points(x, y, ax, len, marker, size_marker, colors, masked=false)
	
	for j in 1:len
			color = colors[j % length(colors) + 1]
			draw_point(x[j], y[j], ax, marker, size_marker, color, 0, masked)
		
	end
end

# ╔═╡ df178bb8-3b81-4c4b-ba94-3ad945e63007
begin
	color_grey = RGB{Float64}(0.5, 0.5, 0.5)
	colors = [ColorSchemes.viridis[i] for i in 1:40:256]
	col_length = length(colors)
	color_blue = ColorSchemes.viridis[116]
end;

# ╔═╡ da0a4117-629e-42b5-95ae-d49f10769830
function draw_all(l, k, k_conv, x, x_conv, y1, y2, y2_draw, y12, y3, ax1, ax2, ax3, emoji_pill_grey, emoji_pill, grey_marker, color_marker, masked=false)
	offset = 0
	for index in k:k+nb
		scatter!(ax3, (x_conv[k_conv], y3[k_conv]), color = colors[1])
		
		if index < 1 || index > l
			continue
		end

		color = colors[index % col_length + 1]

		
		draw_point(x[index], y12[index], ax2, emoji_pill, color_marker, color, 0)
		draw_point(x_conv[k_conv], y12[index], ax3, emoji_pill, color_marker, color, offset)
		
		draw_point(x[index], y12[index], ax2, emoji_pill_grey, grey_marker, color, 0)

		if y1[index] != 0 && y2_draw[index] != 0
			draw_point(x[index], y2_draw[index], ax1,'😷' , grey_marker, color, 0, masked)
		end
		
		offset += y12[index]
	end
end

# ╔═╡ ceb05a23-93b8-4423-a5f9-f6e3d961d0c6
begin
	# Set up Figure elements
	f = Figure(;resolution= (650,700))
	
	ax1 = Axis(f[1, 1];
			xticklabelsize = 32,
			yticklabelsize = 12,
			ylabel="New patients")
	
	ax2 = Axis(f[2, 1];
			xticklabelsize = 32,
			yticklabelsize = 12,
			ylabel = "New pills required")
	
	ax3 = Axis(f[3, 1];
			xticklabelsize = 12,
			yticklabelsize = 12,
			ylabel = "Stockpile required",
			xlabel = "Day")

	# Set up range and constants
	x = range(-nb, 2*nb, step=1)
	x_conv = range(-nb, 5*nb, step = 1) .- nb*1.5 .+4
	l = length(x)
	k = k_conv - nb +1

	# This is to add the shape of the pill on top of the color
	emoji_pill_grey = plot_grey_pill(emoji_pill_pic)

	# Set up the emojis and their sizes
	emoji_pill = plot_pill(emoji_pill_pic) 
	grey_marker = 25
	color_marker = 4

	# Set up the functions
	y1 = y1_pills
	y2 = y2_patients
	y2_draw = y2_patients_draw
	
	# Intermediate step for convolution
	y12_draw = y1 .* y2_draw 
	y12 = y1 .* y2

	# Set up the final convoluted result 
	y3 = DSP.conv(y1,reverse(y2))

	# Draw vertical lines
	vlines!.([ax1,ax2],Ref([k_conv-1]), color = color_blue)
	vlines!.([ax3],Ref([k-2+nb/2].+4), color = color_blue)

	# Get the top value of each plot and add day line
	max_ax1 = maximum([maximum(y1) maximum(y2)]) + 2
	max_ax2 = maximum(y1) * maximum(y2) + 2
	text!(ax1,k_conv-1, max_ax1-2, text=" Current day", color = color_blue)
	
	# Draw the function lines
	if stairs
		stairs!(ax1, x, y1, color = colors[6], step=:center)
		stairs!(ax1, x, y2_draw, color = colors[4], step=:center)
		stairs!(ax2, x, y12_draw, color = colors[7], step=:center)
		stairs!(ax3, x_conv, y3, color=colors[1], step=:center)
	end
	
	# Draw the points on the graph for the current day
	draw_grey_points(x, y2_draw, ax1, l, '😷', [grey_marker], [color_grey], true)
	draw_grey_points(x, y1, ax1, l, emoji_pill, color_marker, colors)
	
	draw_all(l, k+nb, k_conv+2*nb, x, x_conv, y1, y2, y2_draw, y12_draw, y3, ax1, ax2, ax3, emoji_pill_grey, emoji_pill, grey_marker, color_marker, true)
	
	draw_grey_points(x, y1, ax1, l, emoji_pill_grey, grey_marker, [color_grey])
	draw_grey_points(x_conv, y3, ax3, 4*nb -1, emoji_pill_grey, grey_marker, [color_grey])
	
	
	# Set the axes limits
	xlims!.([ax1,ax2,ax3],Ref((-4,12)))
	ylims!(ax1, (-1, max_ax1))
	ylims!(ax2, (-0.2*max_ax2, max_ax2))
	ylims!(ax3, (-1, maximum(y3) + 7))

	# Draw * as labels
	ax1.xticks = (-len+1:0).+k_conv.-1
	showPlus = sum(y12_draw.>0) > 0
	ax1.xtickformat = "*\n↓"

	# Draw + as labels
	midpoint = [(2*k_conv - len - 1)/2]
	ax2.xticks = midpoint
	ax2.xtickformat = "+\n↓"
	bracket!(ax2,midpoint.-len/2,[-0.5],midpoint.+len/2,[-0.5];orientation=:down)
	ax3.xticks = (-nb:5*nb, string.(0 .+ (-nb+4:5*nb+4)))
	
	# a bit hacky, Makie doesnt allow specifying lineheight of ticks directly
	ax1.xaxis.elements[:ticklabels].lineheight = 0.5
	ax2.xaxis.elements[:ticklabels].lineheight = 0.5

	
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
