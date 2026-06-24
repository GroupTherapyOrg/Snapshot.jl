### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> licence_url = "https://github.com/JuliaPluto/featured/blob/2a6a9664e5428b37abe4957c1dca0994f4a8b7fd/LICENSES/Unlicense"
#> image = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Collatz_Conjecture_Vizualization.png/500px-Collatz_Conjecture_Vizualization.png"
#> title = "Visualizing the Collatz Conjecture "
#> tags = ["math", "interactive visualization", "collatz conjecture", "edmond harris"]
#> date = "2023-12-14"
#> description = "Explore this cool math problem and create your own visualization!"
#> license = "Unlicense"
#> 
#>     [[frontmatter.author]]
#>     name = "Chris Damour"
#>     url = "https://github.com/damourChris"

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

# ╔═╡ e4a76493-9aea-4379-9a56-6a9b9e8d6b54
begin
	# Notebook related packages
	using PlutoUI
	using HypertextLiteral:@htl
	md"""
	!!! info "Notebook Packages"
		[PlutoUI](https://www.juliapackages.com/p/PlutoUI): Extension for Pluto to handle interactivity, provides the Sliders and Checkboxes.

		[HypertextLiteral](https://www.juliapackages.com/p/HypertextLiteral): Used to lay out the interactive control panels.

	"""
end

# ╔═╡ 13f52ec2-16b9-41a5-9560-177ca827a72e
begin
	using WasmMakie
	md"""
	!!! info "Plotting Package"
		[WasmMakie](https://github.com/GroupTherapyOrg/WasmMakie.jl): Plotting library for the several plots and trajectory visualizations in the notebook — Makie's API, rendered through HTML Canvas2D, WebAssembly-compilable.
	"""
end

# ╔═╡ e60fcc3e-312c-4546-9b04-e6b558ba752a
TableOfContents()

# ╔═╡ 5328c6f3-2ae7-4449-a2a2-b6803cec0dcc
md"""
$(Resource("https://static.wixstatic.com/media/a27d24_08a39705c99d40c6b764c9b8d699b71a~mv2.jpg/v1/fit/w_900%2Ch_1000%2Cal_c%2Cq_80/file.jpg", :height => 500))
Visualization of the Collatz Conjecture by [Edmund Harris](https://maxwelldemon.com/)
# The Collatz Conjecture
> "Mathematics may not be ready for such problems." - Paul Erdos
"""

# ╔═╡ 822a3646-be9d-4b1c-a189-550bd8b56ab7
md"# Introduction"

# ╔═╡ 0bc0ea95-585d-43be-b7ac-c33a2a7417b4
md"""

The [Collatz Conjecture](https://en.wikipedia.org/wiki/Collatz_conjecture), also known as the 3x+1 problem, is a fascinating mathematical puzzle that has been named after the German mathematician [Lothar Collatz](https://en.wikipedia.org/wiki/Lothar_Collatz). This conjecture arises from an iterative process where you start with any positive integer and alternate between two simple rules: 
- if the number is *even*, you divide it by 2,
- and if it's *odd*, you multiply it by 3 and add 1. 

For example, take the number 3. It's odd, so we multiply by 3 and add 1. We get 10. Now that's even, so we can divide it by 2, to get 5. Back to odd, so let's multiply that by 3 and add 1. We are now at 16, which is *very* even. So much so that we can keep on dividing by 2 until we reach 1. 

``3 \rightarrow 10 \rightarrow 5 \rightarrow 16 \rightarrow 8 \rightarrow 4 \rightarrow 2 \rightarrow 1``

What happens when we reach 1? Well, it's odd so we multiply by 3 and add 1. And we are back at 4, which leads back to one. We have reached a cycle. 

`` 4 \rightarrow 2 \rightarrow 1 \rightarrow  4 \rightarrow 2 \rightarrow 1  \ldots``


##### The question is, can you predict what the number will be after a certain number of iterations?
#####

The conjecture is that no matter what starting number you choose, **regardless** of its size, you will **always** reach the number 1. 

However, despite being relatively simple to understand and easy to test for small numbers, it has so far proven difficult to prove definitively for all cases. This conjecture is an unsolved problem in mathematics that continues to intrigue both mathematicians and enthusiasts alike.

"""

# ╔═╡ bdd54208-1f66-45da-9e67-9479cc460863
md"---"

# ╔═╡ 81db5594-75c0-4bfb-8908-ef8084559123
md"## The Hailstone Sequence"

# ╔═╡ b3c9453e-3198-4697-966f-ade21f2255ce
md"""
The sequence of values that you go through when iterating a number is often called the hailstone sequence, as the numbers go up and down through the sequence. 
"""

# ╔═╡ e57da7e5-32bb-48a2-af27-5ac671cabdae
md"""
Starting value = $(@bind hailstone_start_value Slider(1:1:1000, default=15, show_value=true))
"""

# ╔═╡ 75b9294e-43a4-48c4-b493-5d40027f3cd6
md"## All Paths Lead to One"

# ╔═╡ 12d218ee-9a43-4647-a96b-c9252c665fa0
md"""

We can visualize the path that *every* number takes by overlaying many hailstone
sequences at once. Each line is one starting value; watch how, no matter where they
begin, they all tumble down into the same ``4 \rightarrow 2 \rightarrow 1`` cycle.

"""

# ╔═╡ 43c4fd8d-bb44-43cd-91dd-d221629d1fd9
md"""
Overlay paths for 1 … N = $(@bind graph_start_value Slider(1:1:60, default=12, show_value=true))
"""

# ╔═╡ 6f68b20d-67e5-4872-a23b-1840bbbb06ec
md"## The stopping time of a number"

# ╔═╡ 6a45247d-25db-445f-a687-191c0952c6c4
md"""At first it might seem that the fact that it *always* reaches 1 could appear strange, as some numbers get caught in a repeating pattern of multiplying by 3 and adding one, when dividing by 2, give a another odd number. Since:

``
\begin{aligned} x < \frac{3x + 1}{2} \end{aligned}
``

Thus, it's possible (and quite frequent) that we end going up in numbers, and looks like we are getting further away from the pit of doom that is the number 1. 

However, this is unfortunately not the case, but we quantify this by calculating how long it takes for a number to reach a another number that is lower than the starting point: the stopping time. 

Here is a plot to show the total stopping times of the numbers for up to 1000. 
"""



# ╔═╡ 0fd7242c-46a1-4929-9c53-3c45768893b4
md"""
Upper bound = $(@bind stopping_ub Slider(100:100:3000, default=1000, show_value=true))
"""

# ╔═╡ d0672735-8007-4a69-9fa5-0f40ac0685ea
md"# Interactive Visualization"

# ╔═╡ aef6cb43-61c7-4436-ad66-7e7f0459610d
@htl("""
<div class="slider_group_inner">
Filename: 
				$(@bind filename PlutoUI.TextField(default="MyCoolVisualization"))
				
			</div>
""")

# ╔═╡ 1b48b435-e959-477f-a8d2-3507da73fc28
md"""
The interactive visualization above runs live in your browser as a WebAssembly
island — drag the sliders to explore. (Exporting the rendered image to a
standalone HTML file is only available when running this notebook in a full
Pluto session.)
"""

# ╔═╡ 0865f8a3-a959-481b-a9ae-adbca78a2749
window_size_sliders = @htl("""
<div class="slider_group_inner">
	<div><p>Window Size:</p></div>
	<div>Height: $(@bind window_height NumberField(100:10000, default=700))</div>
	<div>Width: $(@bind window_width NumberField(100:10000, default=500))</div>
</div>
""");

# ╔═╡ 8a64e9e3-477e-4a7e-97f7-61cf5e428731
md"The window size controls feed the interactive visualization below."

# ╔═╡ 01cc5e4f-d94b-4211-b268-9ce0640cd23f
colors_sliders = @htl("""
<div class="slider_group_inner">
	<div><p>Color Options:</p></div>
	<div>Stroke (R): $(@bind stroke_r Slider(0:255, default=230, show_value=true))</div>
	<div>Stroke (G): $(@bind stroke_g Slider(0:255, default=130, show_value=true))</div>
	<div>Stroke (B): $(@bind stroke_b Slider(0:255, default=130, show_value=true))</div>
</div>
""");

# ╔═╡ 5ba5f885-1de1-4058-91bf-35e1b05d1941
viz_sliders = @htl("""
<div class="slider_group_inner">
	<div><p>Visualization Options:</p></div>
	<div>Numbers of trajectories: $(@bind num_traject Slider(10:10:300, default=80, show_value=true))</div>
	<div>Step: $(@bind line_length Slider(1:1:150, default=20, show_value=true))</div>
	<div>Rotation Angle (in degrees): $(@bind turn_scale Slider(0:180, default=10, show_value=true))</div>
</div>
""");

# ╔═╡ 7dbfb4dc-c9d0-464d-83b2-18db90d76878
viz_specs_sliders = @htl("""
<div class="slider_group_inner">
	<div><p>Image Options:</p></div>
	<div>Image Rotation (in degrees): $(@bind init_angle Slider(0:360, default=20, show_value=true))</div>
	<div>Starting point (X): $(@bind x_start Slider(0:1000, default=250, show_value=true))</div>
	<div>Starting point (Y): $(@bind y_start Slider(0:1000, default=700, show_value=true))</div>
	<div>Stroke Width: $(@bind stroke_width Slider(1:50, default=5, show_value=true))</div>
</div>
""");

# ╔═╡ f680e7ea-8e3a-41ac-ab92-a27c05103864
viz_extra_sliders = @htl("""
<div class="slider_group_inner">
	<div><p>Extra Options:</p></div>
	<div>Random Color: $(@bind random_shade CheckBox(default=false))</div>
	<div>Vary Shade: $(@bind vary_shade CheckBox(default=false))</div>
	<div>In Edmund Harris's style: $(@bind edmund_style CheckBox(default=false))</div>
	<div>In Chris's style: $(@bind chris_style CheckBox(default=false))</div>
</div>
""");

# ╔═╡ 50a423ad-ca90-4015-9ef6-577f60e4efe7
begin
	@htl("""
	<div class="slider_group sidebar-left">
		<div class="on_big_show">
			<div class="slider_group_inner">
				$viz_sliders
			</div>

		</div>	
	</div>
	
	<div class="slider_group sidebar-right">
		<div class="on_small_show">
			<div class="slider_group_inner ">
				$viz_sliders
			</div>
		</div>
	
		<div class="slider_group_inner">
			$viz_specs_sliders
		</div>
	
		<div class="slider_group_inner">
			$colors_sliders
		</div>
	
		<div class="slider_group_inner">
			$viz_extra_sliders
		</div>
	</div>
	<div class="sidebar-bottom">
		<div class="on_tiny_show">
			<div class="slider_group">
				<div class="slider_group_inner">
					$viz_sliders
				</div>
			
				<div class="slider_group_inner ">
					$viz_sliders
				</div>
			</div>
		
			<div class="slider_group">
				<div class="slider_group_inner">
					$viz_specs_sliders
				</div>
			
				<div class="slider_group_inner">
					$colors_sliders
				</div>
				<div class="slider_group_inner">
					$viz_extra_sliders
				</div>
			</div>
		</div>
		<div>
				
		</div>
	</div>
	""")
end

# ╔═╡ b56a1328-194c-4e1c-a033-9ca6e0ab3eeb
md"---"

# ╔═╡ 6e359db6-581f-4a5a-a0a7-6924faf19653
md"> Of course, we are not limited to the 3x + 1 problem, what happens if we change up those values?"

# ╔═╡ dc1dba7c-8c0d-4609-882a-e5703c467fef
md"# Generalizing the Collatz function"

# ╔═╡ b9277abb-7a14-4479-8bcb-6a50df27182b
md"""
A generalization of the collatz function is the following:

``
	g(n) = n/P \ \ \ \ \ \ \ \text{when}\ \ \ n \ \text{mod}\ P = 0
``

``
	g(n) = an+b \ \ \ \text{otherwise}
``

This formulation makes sure that we always deal with integers.

"""

# ╔═╡ 0e85d872-ef01-463e-b395-b0797c96317e
md"""
The sliders below let you change the three numbers ``P``, ``a`` and ``b`` directly.
Every plot above — the hailstone sequence, the convergence view and the stopping-time
plot — reacts live to these values, so you can explore the generalized family without
leaving the page.
"""

# ╔═╡ 1c3f1bea-f1ba-4d64-90ad-584391c01da5
md"""
!!! info "Try it"
	The classic Collatz problem is ``P = 2``, ``a = 3``, ``b = 1``. Move the sliders to
	pick a different ``(P, a, b)`` and watch how the trajectories change.
"""

# ╔═╡ f21f1e3e-a3ab-458e-a101-ce824731f0b6
md"""
Collatz Parameters (P, a, b):

P = $(@bind collatz_P Slider(2:1:10, default=2, show_value=true))

a = $(@bind collatz_a Slider(1:1:10, default=3, show_value=true))

b = $(@bind collatz_b Slider(1:1:10, default=1, show_value=true))
"""

# ╔═╡ af0c36ee-0534-4143-b59b-4ee041ef0f04
md"""
!!! warning "Divergence"
	Some parameter choices do not behave like the traditional problem and can send the
	numbers climbing without ever reaching 1. To keep everything fast and finite, the
	computations stop after at most 1000 steps.
"""

# ╔═╡ 16d57341-6c55-4440-bdeb-492b4d0c4427
md"# Gallery"

# ╔═╡ 5655a706-2c53-4763-b8c5-e21aa3e72371
md"""While playing around with the **interactive visualization** above, you can
stumble into some lovely patterns. Try a few `(P, a, b)` combinations together with
different rotation angles, step lengths and starting points — for example
`P = 5, a = 5, b = 5` or `P = 2, a = 3, b = 7` — and watch the trajectories bloom into
flowers, hexagonal grids and little creatures. Enjoy :)

*(Note that the patterns are highly dependent on the canvas size, so the exact look will
shift as you resize the window.)*"""

# ╔═╡ b7b80bd8-7a16-4483-9b8f-b6a8da531b0a


# ╔═╡ 3e9a6e74-a0ab-4c47-b493-4670fa828c45
md"---"

# ╔═╡ 546a2cf6-f54a-4482-9da5-af9d966b22eb
md"---"

# ╔═╡ cdfb638b-a04c-482c-9206-47f7dfd63766
md"# Appendix"

# ╔═╡ 3e6323cb-4b09-4fe9-a223-8c66cb0d3efc
md"""
Here a list of extra ressources in case you want to learn more. They inspired me a lot through this notebook so hope you find them usefull!


- [Wikipedia page](https://en.wikipedia.org/wiki/Collatz_conjecture)
- [The Numberphile video](https://www.youtube.com/watch?v=5mFpVDpKX70) ( [and the extras](https://www.youtube.com/watch?v=O2_h3z1YgEU) )
- [The Coding Train](https://www.youtube.com/watch?v=EYLWxwo1Ed8)
- [This amazing post from Luc Blassel] (https://lucblassel.com/posts/visualizing-the-collatz-conjecture/)
- [Edmund Harris's website](https://maxwelldemon.com/) 
"""

# ╔═╡ 0fdafbdc-a6aa-42a6-a899-41b351b5e7e8
md"## Packages"


# ╔═╡ c5673bfa-d2b0-4893-ad88-42a5b81f27b4
md"""
!!! info "Numerical kernels"
	The Collatz / hailstone / stopping-time computations in this notebook are written
	as plain integer loops (`collatz_hailstone`, `collatz_stopping_time`) so the
	interactive plots compile to WebAssembly — no external numerical packages needed.
"""

# ╔═╡ 091d8f63-d02a-48fa-be0c-e9e027409279
md"## Custom Types"

# ╔═╡ 9803f163-0027-4577-af8f-c66de195d182
md"## Functions"

# ╔═╡ f02affaa-534b-4c72-81ae-c42ca3b455fd
md"### Collatz"

# ╔═╡ a3b1c2d4-0001-4001-8001-000000000001
"""
	collatz_hailstone(n0, P, a, b, maxlen)

The generalized hailstone sequence as a flat `Vector{Int64}`, computed with a plain
integer loop so it compiles to WebAssembly. `g(n) = n ÷ P` when `n % P == 0`, otherwise
`g(n) = a*n + b`. Iteration stops at 1 or after `maxlen` steps.
"""
function collatz_hailstone(n0::Int64, P::Int64, a::Int64, b::Int64, maxlen::Int64)
	out = Int64[]
	n = n0 < 1 ? Int64(1) : n0
	pp = P < 2 ? Int64(2) : P
	push!(out, n)
	steps = 0
	while n != 1 && steps < maxlen
		n = (n % pp == 0) ? (n ÷ pp) : (a * n + b)
		push!(out, n)
		steps += 1
		if n < 1
			break
		end
	end
	return out
end

# ╔═╡ 66fe673a-7679-4c55-bf59-146a8dd1241c
begin
	hail_x = Float64[]
	hail_y = Float64[]
	let
		seq = collatz_hailstone(
			Int64(hailstone_start_value),
			Int64(collatz_P),
			Int64(collatz_a),
			Int64(collatz_b),
			Int64(1000))
		i = 1
		for v in seq
			push!(hail_x, Float64(i))
			push!(hail_y, Float64(v))
			i += 1
		end
	end

	fig_hail = Figure(size = (640, 420))
	ax_hail = Axis(fig_hail[1, 1])
	lines!(ax_hail, hail_x, hail_y; color = (0.678, 0.847, 0.902, 1.0))

	fig_hail
end

# ╔═╡ 3550fe19-261e-4069-9bf6-6417dcaac102
begin
	# Every starting number from 1 up to `graph_start_value` traces its own hailstone
	# path. Overlaying them shows the central pedagogy of the Collatz graph: no
	# matter where you begin, every path funnels down into the 4 → 2 → 1 cycle.
	# Each trajectory is computed with the pure-integer kernel and drawn with
	# WasmMakie `lines!`, so the whole figure ships as a live wasm island.
	fig_conv = Figure(size = (700, 460))
	ax_conv = Axis(fig_conv[1, 1])

	top = Int64(graph_start_value)
	n0 = Int64(1)
	while n0 <= top
		seq = collatz_hailstone(
			n0,
			Int64(collatz_P),
			Int64(collatz_a),
			Int64(collatz_b),
			Int64(1000))
		cx = Float64[]
		cy = Float64[]
		i = 1
		for v in seq
			push!(cx, Float64(i))
			push!(cy, Float64(v))
			i += 1
		end
		shade = Float64(n0 % 7) / 7.0
		lines!(ax_conv, cx, cy;
			color = (0.25 + 0.5 * shade, 0.45, 0.85 - 0.4 * shade, 0.55),
			linewidth = 1.5)
		n0 += 1
	end
	fig_conv
end

# ╔═╡ 6d225dce-3362-4f5d-bba9-0b5312f6be5a
begin
	# num_traject, turn_scale, line_length, init_angle, x_start, y_start,
	# stroke_width, stroke_r/stroke_g/stroke_b, random_shade, vary_shade,
	# edmund_style and chris_style all come directly from the plain PlutoUI
	# bonds above — no combine-NamedTuple unpacking needed.

	# Trajectories from the pure-integer kernel (reversed so they grow outward
	# from 1), one per starting number — fully wasm-compilable.
	viz_trajectories = Vector{Vector{Int64}}()
	let
		Pv = Int64(collatz_P)
		av = Int64(collatz_a)
		bv = Int64(collatz_b)
		n0 = Int64(1)
		ntop = Int64(num_traject)
		while n0 <= ntop
			push!(viz_trajectories, reverse(collatz_hailstone(n0, Pv, av, bv, Int64(1000))))
			n0 += 1
		end
	end

	# Turtle-walk each sequence in pure Julia (WasmMakie draws the paths):
	# start at (x_start, y_start) heading init_angle+180°, turn by parity,
	# step line_length — the same rules draw_hailstone_sequence used.
	interactive_viz = let
		fig = Figure(size = (Float64(window_width), Float64(window_height)))
		ax = Axis(fig[1, 1])
		hidedecorations!(ax)
		hidespines!(ax)

		base_r = Float64(stroke_r) / 255.0
		base_g = Float64(stroke_g) / 255.0
		base_b = Float64(stroke_b) / 255.0
		turn = Float64(turn_scale)
		step = Float64(line_length)

		for (t_i, seq) in enumerate(viz_trajectories)
			xs = Float64[]
			ys = Float64[]
			x = Float64(x_start)
			y = Float64(y_start)
			θ = Float64(init_angle) + 180.0
			push!(xs, x)
			push!(ys, y)
			for v in seq
				if chris_style
					θ += (mod(v, 3) == 1 ? turn : -turn)
				elseif mod(v, 2) == 0
					θ += turn
				else
					θ -= edmund_style ? turn / 2 : turn
				end
				x += step * cosd(θ)
				y += step * sind(θ)
				push!(xs, x)
				push!(ys, y)
			end

			# deterministic stand-ins for rand()/randn() shades — identical
			# in the native run and the wasm island
			col = if random_shade
				(Float64(mod(t_i * 37, 97)) / 97.0,
				 Float64(mod(t_i * 53, 89)) / 89.0,
				 Float64(mod(t_i * 71, 83)) / 83.0, 0.6)
			elseif vary_shade
				shade = (Float64(mod(t_i, 7)) - 3.0) * 0.08
				(clamp(base_r + shade, 0.0, 1.0),
				 clamp(base_g + shade, 0.0, 1.0),
				 clamp(base_b + shade, 0.0, 1.0), 0.6)
			else
				(base_r, base_g, base_b, 0.6)
			end
			lines!(ax, xs, ys; color = col, linewidth = Float64(stroke_width))
		end
		fig
	end
end

# ╔═╡ a3b1c2d4-0002-4001-8001-000000000002
"""
	collatz_stopping_time(n0, P, a, b, maxlen)

Number of steps the generalized Collatz map takes to first reach 1 (the *total stopping
time*), as a plain `Int64`. Capped at `maxlen` steps so divergent parameters stay finite.
"""
function collatz_stopping_time(n0::Int64, P::Int64, a::Int64, b::Int64, maxlen::Int64)
	n = n0 < 1 ? Int64(1) : n0
	pp = P < 2 ? Int64(2) : P
	steps = 0
	while n != 1 && steps < maxlen
		n = (n % pp == 0) ? (n ÷ pp) : (a * n + b)
		steps += 1
		if n < 1
			break
		end
	end
	return steps
end

# ╔═╡ 45ca6e2a-6a58-475e-9c02-4925e71625bd
begin
	# Total stopping time for every starting point from 1 to the chosen upper
	# bound, computed with the pure-integer kernel and collected into flat
	# Float64 vectors — no Dict, no caching, fully wasm-compilable.
	st_x = Float64[]
	st_y = Float64[]
	let
		ub = Int64(stopping_ub)
		Pv = Int64(collatz_P)
		av = Int64(collatz_a)
		bv = Int64(collatz_b)
		n0 = Int64(1)
		while n0 <= ub
			push!(st_x, Float64(n0))
			push!(st_y, Float64(collatz_stopping_time(n0, Pv, av, bv, Int64(1000))))
			n0 += 1
		end
	end

	fig_st = Figure(size = (640, 420))
	ax_st = Axis(fig_st[1, 1])
	scatter!(ax_st, st_x, st_y; markersize = 4.0)
	fig_st
end

# ╔═╡ cf545d05-7846-4881-a532-33cb2c1972a4
md"### Drawing"

# ╔═╡ ae8c02c0-2944-42dc-8a19-a45fbdc16134
md"### HTML Functions"

# ╔═╡ f47eb656-67ec-4760-8906-713fa480cb47
md"### Interactivity extensions"

# ╔═╡ 43479204-cd12-40b4-a65f-16bf54aaddfe
md"All interactive controls now use plain PlutoUI bonds (`@bind x Slider(...)`), which serialize correctly as WebAssembly island bonds."

# ╔═╡ 31a7994d-13e0-440a-8279-5f19d7d0933f
md"_(NumberField controls use plain `@bind x NumberField(...)` bonds.)_"

# ╔═╡ 25d2291f-f422-41e4-aa61-9000e13d34ad
md"_(CheckBox controls use plain `@bind x CheckBox(...)` bonds.)_"

# ╔═╡ 1255f4cc-7448-40f6-83ba-0cca1637d1cf
md"_(Stroke colour now uses three integer `@bind x Slider(0:255, ...)` channel bonds.)_"

# ╔═╡ 7dac4da8-0877-4d07-b4d2-2164faeccfde
md"_(slider layout is built inline in each control cell.)_"

# ╔═╡ 4dd44fbd-f26a-4b72-a580-842209b44f27
md"_(slider layout is built inline in each control cell.)_"

# ╔═╡ 5977a13d-93b8-4e51-8484-5b1882100c49
md"_(NumberField layout is built inline in each control cell.)_"

# ╔═╡ a7885279-3f73-4c5d-aeef-061dea1ce930
md"_(CheckBox layout is built inline in each control cell.)_"

# ╔═╡ 2d98aed3-9a51-4225-b914-a20b19f43908
md"_(Stroke colour slider layout is built inline in the control cell.)_"

# ╔═╡ d9aaaadc-7d94-4e85-a1cb-c137e869ad2f
md"### Extras"

# ╔═╡ 90dc6dd4-c4f3-4e4d-8e91-0fecafd258e1
md"## CSS Styles"

# ╔═╡ 7baab6e9-31bb-4da5-8ab9-938546cc863e
@htl("""

<style>

input[type="button" i] {
	padding: 0.5rem;
}

@media screen and (min-width: 1000px) {
	
	.on_tiny_show {
		display: flex;
	}
	.on_small_show {
		display: none;
	}
	.on_big_show {
		display: none;
	}
}
@media screen and (min-width: 1000px) {
	.on_tiny_show {
		display: none;
	}
	.on_small_show {
		display: flex;
	}
	.on_big_show {
		display: none;
	}
}
@media screen and (min-width: 1500px) {
	.on_tiny_show {
		display: none;
	}
	.on_small_show {
		display: none;
	}
	.on_big_show {
		display: flex;
	}
}

.sidebar-left {
	position: absolute;
    top: 100%;
	right: 110%;
	width: 17rem;
	z-index: 99;
}
.sidebar-right {
    top: 100%;
	position: absolute;
	left: 100%;
	width: 17rem;
}
.sidebar-bottom {
    display: flex;
}

.slider_group{
	display:flex; 
	flex-direction: column;
	padding: .5rem; 
	gap: 2rem
}
.slider_group_inner{
	display:flex; 
	align-items:center; 
	padding: .5rem; 
	gap: 2rem
}

.gallery{
	display: flex;
	width: fit-content;
	background-color: white
}

.canvas-container{
	display: flex;
	margin: .75rem;
	box-shadow: 6px 5px 11px 0px gray;
	border: solid black 1px;
}
.notes-container{
	display: flex;
	flex-wrap: wrap;
	margin: .75rem;
	box-shadow: 6px 5px 11px 0px gray;
	padding: .5rem;
	border: solid black 1px;
	color: black
}
.notes-container-inner{
	margin-right: 4px
}

</style>

""")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

[sources]
WasmMakie = {url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"}

[compat]
HypertextLiteral = "~1.0.0"
PlutoUI = "~0.7.83"
WasmMakie = "~0.1.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "04597b52408c65bfff4f65370a7824e4faad07fa"

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
# ╟─e60fcc3e-312c-4546-9b04-e6b558ba752a
# ╟─5328c6f3-2ae7-4449-a2a2-b6803cec0dcc
# ╟─822a3646-be9d-4b1c-a189-550bd8b56ab7
# ╟─0bc0ea95-585d-43be-b7ac-c33a2a7417b4
# ╟─bdd54208-1f66-45da-9e67-9479cc460863
# ╟─81db5594-75c0-4bfb-8908-ef8084559123
# ╟─b3c9453e-3198-4697-966f-ade21f2255ce
# ╟─e57da7e5-32bb-48a2-af27-5ac671cabdae
# ╟─66fe673a-7679-4c55-bf59-146a8dd1241c
# ╟─75b9294e-43a4-48c4-b493-5d40027f3cd6
# ╟─12d218ee-9a43-4647-a96b-c9252c665fa0
# ╟─3550fe19-261e-4069-9bf6-6417dcaac102
# ╟─43c4fd8d-bb44-43cd-91dd-d221629d1fd9
# ╟─6f68b20d-67e5-4872-a23b-1840bbbb06ec
# ╟─6a45247d-25db-445f-a687-191c0952c6c4
# ╟─0fd7242c-46a1-4929-9c53-3c45768893b4
# ╟─45ca6e2a-6a58-475e-9c02-4925e71625bd
# ╟─d0672735-8007-4a69-9fa5-0f40ac0685ea
# ╟─50a423ad-ca90-4015-9ef6-577f60e4efe7
# ╟─6d225dce-3362-4f5d-bba9-0b5312f6be5a
# ╟─aef6cb43-61c7-4436-ad66-7e7f0459610d
# ╟─1b48b435-e959-477f-a8d2-3507da73fc28
# ╟─0865f8a3-a959-481b-a9ae-adbca78a2749
# ╟─8a64e9e3-477e-4a7e-97f7-61cf5e428731
# ╟─01cc5e4f-d94b-4211-b268-9ce0640cd23f
# ╟─5ba5f885-1de1-4058-91bf-35e1b05d1941
# ╟─7dbfb4dc-c9d0-464d-83b2-18db90d76878
# ╟─f680e7ea-8e3a-41ac-ab92-a27c05103864
# ╟─b56a1328-194c-4e1c-a033-9ca6e0ab3eeb
# ╟─6e359db6-581f-4a5a-a0a7-6924faf19653
# ╟─dc1dba7c-8c0d-4609-882a-e5703c467fef
# ╟─b9277abb-7a14-4479-8bcb-6a50df27182b
# ╟─0e85d872-ef01-463e-b395-b0797c96317e
# ╟─1c3f1bea-f1ba-4d64-90ad-584391c01da5
# ╟─f21f1e3e-a3ab-458e-a101-ce824731f0b6
# ╟─af0c36ee-0534-4143-b59b-4ee041ef0f04
# ╟─16d57341-6c55-4440-bdeb-492b4d0c4427
# ╟─5655a706-2c53-4763-b8c5-e21aa3e72371
# ╟─b7b80bd8-7a16-4483-9b8f-b6a8da531b0a
# ╟─3e9a6e74-a0ab-4c47-b493-4670fa828c45
# ╟─546a2cf6-f54a-4482-9da5-af9d966b22eb
# ╟─cdfb638b-a04c-482c-9206-47f7dfd63766
# ╟─3e6323cb-4b09-4fe9-a223-8c66cb0d3efc
# ╟─0fdafbdc-a6aa-42a6-a899-41b351b5e7e8
# ╟─c5673bfa-d2b0-4893-ad88-42a5b81f27b4
# ╟─e4a76493-9aea-4379-9a56-6a9b9e8d6b54
# ╠═13f52ec2-16b9-41a5-9560-177ca827a72e
# ╟─091d8f63-d02a-48fa-be0c-e9e027409279
# ╟─9803f163-0027-4577-af8f-c66de195d182
# ╟─f02affaa-534b-4c72-81ae-c42ca3b455fd
# ╟─a3b1c2d4-0001-4001-8001-000000000001
# ╟─a3b1c2d4-0002-4001-8001-000000000002
# ╟─cf545d05-7846-4881-a532-33cb2c1972a4
# ╟─ae8c02c0-2944-42dc-8a19-a45fbdc16134
# ╟─f47eb656-67ec-4760-8906-713fa480cb47
# ╟─43479204-cd12-40b4-a65f-16bf54aaddfe
# ╟─31a7994d-13e0-440a-8279-5f19d7d0933f
# ╟─25d2291f-f422-41e4-aa61-9000e13d34ad
# ╟─1255f4cc-7448-40f6-83ba-0cca1637d1cf
# ╟─7dac4da8-0877-4d07-b4d2-2164faeccfde
# ╟─4dd44fbd-f26a-4b72-a580-842209b44f27
# ╟─5977a13d-93b8-4e51-8484-5b1882100c49
# ╟─a7885279-3f73-4c5d-aeef-061dea1ce930
# ╟─2d98aed3-9a51-4225-b914-a20b19f43908
# ╟─d9aaaadc-7d94-4e85-a1cb-c137e869ad2f
# ╟─90dc6dd4-c4f3-4e4d-8e91-0fecafd258e1
# ╟─7baab6e9-31bb-4da5-8ab9-938546cc863e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
