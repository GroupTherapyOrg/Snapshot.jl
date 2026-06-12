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

# ╔═╡ c5673bfa-d2b0-4893-ad88-42a5b81f27b4
begin
	using Collatz
	using Graphs
	using FixedPointNumbers 
	md"""
	!!! info "Numerical Packages"
		[Collatz](https://juliapackages.com/p/collatz): This package provide the methods to generate the hailstone sequence, the tree graph and stopping time for the collatz conjecture. 
	
		[Graphs](https://www.juliapackages.com/p/graphs): Used to deal with creating and modifying graphs. 
	
		[FixedPointNumbers](https://www.juliapackages.com/p/fixedpointnumbers): Package to deal with fixed point number, only used to handle colors.
	"""
end

# ╔═╡ e4a76493-9aea-4379-9a56-6a9b9e8d6b54
begin
	# Notebook related packages
	using PlutoUI
	import PlutoUI: combine
	using HypertextLiteral:@htl
	using Parameters
	md"""
	!!! info "Notebook Packages"
		[PlutoUI](https://www.juliapackages.com/p/PlutoUI): Extension for Pluto to handle interactivity, provides the Sliders, Checkboxes and Color Picker. 
	
		[HypertextLiteral](https://www.juliapackages.com/p/HypertextLiteral): Drawing library, specifically for graphs.
	
	"""
end

# ╔═╡ 13f52ec2-16b9-41a5-9560-177ca827a72e
begin
	using WasmMakie
	using Colors
	using Luxor
	using Karnak, NetworkLayout
	using ImageIO ,ImageShow
	md"""
	!!! info "Ploting Packages"
		[WasmMakie](https://github.com/GroupTherapyOrg/WasmMakie.jl): Plotting library for the several plots and trajectory visualizations in the notebook — Makie's API, rendered through HTML Canvas2D, WebAssembly-compilable.

		[Luxor](https://www.juliapackages.com/p/luxor): Drawing library used for the gallery visualizations.

		[Karnak](https://www.juliapackages.com/p/karnak): Drawing library, specifically for graphs.

		[NetworkLayout](https://www.juliapackages.com/p/networklayout): Used to compute the layout of the graphs.

		[ImageIO](https://www.juliapackages.com/p/ImageIO): Used to faciliate the handling of images.

		[ImageShow](https://www.juliapackages.com/p/ImageShow): Enhances the displaying of the images in the gallery.
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

# ╔═╡ 75b9294e-43a4-48c4-b493-5d40027f3cd6
md"## The Collatz Graph"

# ╔═╡ 12d218ee-9a43-4647-a96b-c9252c665fa0
md"""

We can visualize the path that each number takes with a graph. 


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



# ╔═╡ d0672735-8007-4a69-9fa5-0f40ac0685ea
md"# Interactive Visualization"

# ╔═╡ aef6cb43-61c7-4436-ad66-7e7f0459610d
@htl("""
<div class="slider_group_inner">
Filename: 
				$(@bind filename PlutoUI.TextField(default="MyCoolVisualization"))
				
			</div>
""")

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
@htl("""
<div style="padding: .5rem">
	<div>
	<h4>
	Want to generalize the parameters? $(@bind do_generalize_collatz PlutoUI.CheckBox())
	</h4>
	
	</div>
	<div>
	<b>Note</b>: This will update all the plots and visualizations in the notebook. 
</div>
</div>

""")

# ╔═╡ 1c3f1bea-f1ba-4d64-90ad-584391c01da5
begin
	generalize_checkbox = @bind generalize_collatz MultiCheckBox(["Hailstone Sequence", "Graph", "Stopping Time", "Interactive"], default=["Interactive"])
	if(do_generalize_collatz)
		generalize_checkbox
	end
end

# ╔═╡ 5f074850-b967-4de5-8ca3-b85a74052499
begin
	generalize_collatz
	stopping_times = Dict();
end;

# ╔═╡ af0c36ee-0534-4143-b59b-4ee041ef0f04
do_generalize_collatz ? md"""
!!! warning "Divergence"
	Some parameters will not behave as the traditional problem and will lead to some numbers diverging up to infinity. In that case, the calculations will stop at a stopping time of 1000. However, this still can still result in high latency so beware! .
""" : md""

# ╔═╡ 16d57341-6c55-4440-bdeb-492b4d0c4427
md"# Gallery"

# ╔═╡ 5655a706-2c53-4763-b8c5-e21aa3e72371
md"While playing around with the viusalization, I stumbled into some nice patterns that I wanted to share with you! I added the parameters in case you want to recreate them. Enjoy :)

*(Note that the parameters are highly dependent on the size of the canvas so it might not be trivial to reproduced)*"

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


# ╔═╡ 091d8f63-d02a-48fa-be0c-e9e027409279
md"## Custom Types"

# ╔═╡ 8c854d1c-2f89-43f0-a810-ce174cf94af8
"""
A struct to store parameters related to the visualization

```julia
num_traject::Int64 = 100.0
line_length::Float64 = 20.0
turn_scale::Float64  = 10.0
init_angle::Float64 = 90.0
x_start::Float64 = 250.0
y_start::Float64 = 500.0
window_width::Float64 = 500.0
window_height::Float64 = 500.0
stroke_width::Float64 = 2.0
stroke_color::Colors.RGBA = RGBA(1.0,1.0,1.0,1.0)
background_color::Colors.RGBA = RGBA(0.0,0.0,0.0,1.0)
vary_shade::Bool = false
random_shade::Bool = false
edmund_style::Bool = false
```
"""
@with_kw struct VisualizationParameters
	num_traject::Int64 = 100.0
	line_length::Float64 = 20.0
	turn_scale::Float64  = 10.0
	init_angle::Float64 = 90.0
	x_start::Float64 = 250.0
	y_start::Float64 = 500.0
	window_width::Float64 = 500.0
	window_height::Float64 = 500.0
	stroke_width::Float64 = 2.0
	stroke_color::Colors.RGBA = RGBA(0.0,0.0,0.0,1.0)
	background_color::Colors.RGBA = RGBA(1.0,1.0,1.0,1.0)
	vary_shade::Bool = false
	random_shade::Bool = false
	edmund_style::Bool = false
	chris_style::Bool = false
end

# ╔═╡ 9803f163-0027-4577-af8f-c66de195d182
md"## Functions"

# ╔═╡ 1e85c1af-3318-4f20-a358-25aa0999dc8a
"""
	hailstone_sequences(range::UnitRange{Int64}; P::Int=2, a::Int=3, b::Int=1 )

Extension for the `hailstone_sequence()` method from Collatz.jl to calculate list of hailstone sequence given a UnitRange. 

## Args

- `range::UnitRange{Int64}`: Unit Range in which to calculate the hailstone sequences.


## Kwargs

- `P::Integer = 2`: Modulus used to devide n, iff n is equivalent to (0 mod P).
- `a::Integer = 3`: Factor by which to multiply n.
- `b::Integer = 1`: Value to add to the scaled value of n.

## Examples
```jldoctest
julia> hailstone_sequences(2:5) 
[[2, 1], [3, 10, 5, 16, 8, 4, 2, 1], [4, 2, 1], [5, 16, 8, 4, 2, 1]]
```
```jldoctest
julia> hailstone_sequences(1:5; P=4, a=1, b=3)
[[1], [2, 5, 8, 2], [3, 6, 9, 12, 3], [4, 1], [5, 8, 2, 5]]
```

## See also
[`hailstone_sequence`](@ref), [`reverse_hailstone_sequences`](@ref)
"""
function hailstone_sequences(range::UnitRange{Int64}; P::Int=2, a::Int=3, b::Int=1 )
	return [ 
				hailstone_sequence(starting_number; P, a, b, verbose =false)  
			
			for starting_number in range
		]
end

# ╔═╡ 40dd9659-abb9-4484-b5f1-f332e2abe90e
"""
	reverse_hailstone_sequences(range::UnitRange{Int64}; P::Int=2, a::Int=3, b::Int=1)
This function wraps the `hailstone_sequence()` method from Collatz.jl to calculate list of hailstone sequence given a UnitRange. 

It return the reversed sequence where the endpoint is the first element of the result.

## Args

- `range::UnitRange{Int64}`: Unit Range in which to calculate the hailstone sequences.


## Kwargs

- `P::Integer = 2`: Modulus used to devide n, iff n is equivalent to (0 mod P).
- `a::Integer = 3`: Factor by which to multiply n.
- `b::Integer = 1`: Value to add to the scaled value of n.

## Examples
```jldoctest
julia> hailstone_sequences(2:5) 
[[1, 2], [1, 2, 4, 8, 16, 5, 10, 3], [1, 2, 4], [1, 2, 4, 8, 16, 5]]
```
```jldoctest
julia> hailstone_sequences(1:5; P=4, a=1, b=3)
[[1], [2, 8, 5, 2], [3, 12, 9, 6, 3], [1, 4], [5, 2, 8, 5]]
```

## See also
[`hailstone_sequence`](@ref), [`hailstone_sequences`](@ref)
"""
function reverse_hailstone_sequences(range::UnitRange{Int64}; P::Int=2, a::Int=3, b::Int=1 )
	return [ 
				reverse(hailstone_sequence(starting_number; P, a, b, verbose =false))
			for starting_number in range
		]
end

# ╔═╡ f02affaa-534b-4c72-81ae-c42ca3b455fd
md"### Collatz"

# ╔═╡ 4c991173-d9ff-4ba9-b217-8f9aafbbd631
shortcut_collatz_cache = Dict{Int, Vector{Int}}()

# ╔═╡ 240b4cc1-1bae-429b-863b-792897cd555b
ultra_shortcut_collatz_cache = Dict{Int, Vector{Int}}()

# ╔═╡ 23be8efa-b907-453f-9245-8bc46a37ad26
"""
	shortcut_collatz(n::Int)

Calculate the collatz sequence of a number using the shortcut formulation:
g(n) = (3n + 1) / 2 if odd and g(n) = n / 2 if even

"""
function shortcut_collatz(n::Int)
   if n == 1
	   return [1]
   elseif haskey(shortcut_collatz_cache, n)
	   return shortcut_collatz_cache[n]
   elseif n % 2 == 0
	   sequence = [n, shortcut_collatz(n ÷ 2)...]
	   shortcut_collatz_cache[n] = sequence
	   return sequence
   else
	   sequence = [n, shortcut_collatz(Int((3n + 1)/2))...]
	   shortcut_collatz_cache[n] = sequence
	   return sequence
   end
end


# ╔═╡ a1a6130d-771a-43d7-ae94-049e3c9b81b3
"""
	ultra_shortcut_collatz(n::Int)

Calculate the collatz sequence of a number using the absolute shortcut formulation:
g(n) = (3n + 1) / 2^k  if odd where k is the highest power that divides 3n+1 and g(n) = n / 2 if even

"""
function ultra_shortcut_collatz(n::Int)
   if n == 1
	   return [1]
   elseif haskey(ultra_shortcut_collatz_cache, n)
	   return ultra_shortcut_collatz_cache[n]
   elseif n % 2 == 0
	   
	   while n % 2 == 0
		   n = n ÷ 2
	   end
	   
	   if n == 1 return [1] end
	   sequence = [n, ultra_shortcut_collatz(3n + 1)...]
	   ultra_shortcut_collatz_cache[n] = sequence
	   return sequence
   else
	   sequence = [n, ultra_shortcut_collatz(Int((3n + 1)/2))...]
	   ultra_shortcut_collatz_cache[n] = sequence
	   return sequence
   end
end


# ╔═╡ 3153ba89-f2d4-4e31-9e79-00ec5ecbb91c
"""
	descend_tree!(g::SimpleGraph{Int64}, record::Array{Tuple{Number,Number}},  tree::Dict, previous::Number=collect(keys(tree))[1], depth::Int=0)
	
This function is used to explore the tree return by `tree_graph` from Collatz.jl and modify the graph g given as input. 

## Args 
- `g::SimpleGraph`: The graph to modify 
- `record::Array{Tuple{Number,Number}}`: An array that keeps track of each of the encountered values. Each value is stored as (depth, value) in order to keep track of what depth the value was encountered
- `tree::Dict`: The tree graph returned by `tree_graph` 
- `previous::Number`: The number passed by the previous call to the function 
- `depth::Int`: The current depth of the search  
"""
function descend_tree!(g::SimpleGraph{Int64}, record::Array{Tuple{Number,Number}},  tree::Dict, previous::Number=collect(keys(tree))[1], depth::Int=0)
	
	# loop over each branch
	for key in  keys(tree)
		
		add_vertex!(g)
		
		# check if previous number exist in record
		previous_index = findfirst(x -> x == previous, map(x -> x[2], record))
		
		# if exist, create a edge in the graph 
		isnothing(previous_index) ? "" : add_edge!(g, previous_index, length(record)+1)

		# this check is there cos when reaching a cycle the tree has a non number key
		if(isa(key, Number))
			push!(record, (depth, key))
		end

		# call recursively to continue descending the tree 
		descend_tree!(g, record,tree[key], key, depth +1)
	end
	# end
end


# ╔═╡ b79405c3-42d1-4289-bbc3-67b6eae2b135
"""
	descend_tree!(g::SimpleGraph{Int64}, record::Array{Tuple{Number,Number}},  key::Int64, previous::Collatz._CC.CC, depth::Int=0)

To handle the case where the search hits a cycle and previous is of type Collatz._CC.CC

## Args 

- `g::SimpleGraph`: The graph to modify 
- `record::Array{Tuple{Number,Number}}`: An array that keeps track of each of the encountered values
- `tree::Dict`: The tree graph returned by `tree_graph` 
- `previous::Collatz._CC.CC`: The cycle value.
- `depth::Int`: The current depth of the search  

"""
function descend_tree!(g::SimpleGraph{Int64}, record::Array{Tuple{Number,Number}},  key::Int64, previous::Collatz._CC.CC, depth::Int=0)
	
	# check if previous number exist in record
	previous_index = findfirst(x -> x == previous, map(x -> x[2], record))

	# if exist, create a edge in the graph 
	isnothing(previous_index) ? "" : add_edge!(g, previous,  length(record)+1)

	# push key in record 
	push!(record, (depth, key))
	return
end

# ╔═╡ 319d784b-c62d-4f28-a5b3-ebf89c892afc
"""
	make_collatz_graph(initial_value::Int, max_orbit_distance::Int; P=2, a=3, b=1)

This function returns a graph that represent the different branches that each number takes.

## Args

- `initial_value::Integer`: The starting value of the directed tree graph.

- `max_orbit_distance::Integer`: Degree of seperation between the initial value and each value encountered. 

## Kwargs

- ```P::Integer=2```: Modulus used to devide n, iff n is equivalent to (0 mod P).

- ```a::Integer=3```: Factor by which to multiply n.

- ```b::Integer=1```: Value to add to the scaled value of n.


## See also
[`tree_graph`](@ref)
"""
function make_collatz_graph(initial_value::Int, max_orbit_distance::Int; P=2, a=3, b=1)
	g = SimpleGraph()
	record::Array{Tuple{Number,Number}} = []
	tree = tree_graph(initial_value,max_orbit_distance; P, a,b )
	descend_tree!(g, record, tree)
	return g, record
end

# ╔═╡ cf545d05-7846-4881-a532-33cb2c1972a4
md"### Drawing"

# ╔═╡ 5683080b-7d4b-4e34-aa75-b3c68dc60314
"""
	draw_hailstone_sequence(hailstone_seq::Vector{Int64}; params::VisualizationParameters)

This function is used to draw the trajectory of the hailstone sequence of a number. Using a Turtle, the function loops over each number in the sequence. For the sequence, a curve is drawn where for each step in the sequence, it will curves one way if the number is odd, and the other way if the number is even. 

## See also
[`VisualizationParameters`](@ref)

"""
function draw_hailstone_sequence(hailstone_seq::Vector{Int64}; params::VisualizationParameters=VisualizationParameters())

	@unpack line_length, turn_scale, 
	stroke_width, stroke_color, random_shade, vary_shade, edmund_style, chris_style = params
	# Initiliaze turle
	🐢 = Turtle()
	
	# set stroke width
	Penwidth(🐢, stroke_width)

	# Handle Color
	if(random_shade)
		Pencolor(🐢,RGB(rand(), rand(), rand()))
		
	elseif vary_shade
		
		color_offset = randn()/2
		Pencolor(🐢,RGB(stroke_color.r + color_offset, stroke_color.g + color_offset, stroke_color.b + color_offset))
	else
		Pencolor(🐢,stroke_color)
	end

	# Move the turtle 
	 for (index,number) in enumerate(hailstone_seq)

		# decrease opacity as the sequence gets longer
		setopacity(rescale(index, 1, length(hailstone_seq)*8
			, 0.1,1))

		if(chris_style)
			if number % 3 == 1
				Turn(🐢, turn_scale)
			else
				Turn(🐢, -turn_scale)	
			end
			Forward(🐢, line_length)
			continue
		end
			
		 
		if number % 2 == 0
			Turn(🐢, turn_scale)
		else
			if(edmund_style) 
				Turn(🐢, -1/2*turn_scale)
			else
				Turn(🐢, -turn_scale)
			end
			
		end
			
		
		# if number < 0
		# 	Turn(🐢, -90)
		# end
		 
		Forward(🐢, line_length)
	end
	
end


# ╔═╡ 278572e6-5a74-4dad-b39b-68cc85e4339c
"""
	draw_hailstone_sequences(hailstone_seqs::Vector{Vector{Int64}}; params::VisualizationParameters)

This function is used to draw each trajectory given an array of hailstone sequences.

## See also

[`VisualizationParameters`](@ref)

"""
function draw_hailstone_sequences(hailstone_seqs::Vector{Vector{Int64}}; params::VisualizationParameters)
	
	@unpack init_angle, x_start, y_start, window_width, window_height = params
	
	for hailstone_seq in hailstone_seqs
		# reset to origin and setup windows accord to user parameter
		origin()
		Luxor.translate(
			x_start - window_width  /2,
			y_start - window_height /2
		)
		Luxor.rotate(deg2rad(init_angle)+π)

		# draw sequence
		draw_hailstone_sequence(hailstone_seq; params)
	end
end

# ╔═╡ d6cc6642-018d-4a7f-b82a-dd50bff8e2fc
"""
A struct to bundle the parameters and the generated image together. 

`viz_parameters::VisualizationParameters`
`collatz_parameters::NamedTuple{(:P, :a, :b)}` = (P = 2, a = 3, b = 1)
`imgdata::Matrix{RGBA{N0f8}}` = []
`shortcut::Bool` = false
`notes::String` = ""



"""
@with_kw struct CollatzVisualization
	viz_parameters::VisualizationParameters
	collatz_parameters::NamedTuple{(:P, :a, :b)} = (P=2,a=3,b=1)
	imgdata::Matrix{RGBA{N0f8}} = []
	shortcut::Bool = false
	ultra_shortcut::Bool = false
	notes::String = ""
	
	function CollatzVisualization(viz_parameters, collatz_parameters,imgdata, shortcut,ultra_shortcut, notes)
		if((shortcut || ultra_shortcut)  &&  (collatz_parameters.P != 2 || collatz_parameters.a != 3 || collatz_parameters.b == 1)) 
			@info "Custom style is applied, running with default collatz parameters.." 
			collatz_parameters = (P = 2, a=3, b=1)
		end
		# convert to struct not supplied 
		if(!isa(viz_parameters, VisualizationParameters))
			viz_parameters = VisualizationParameters(edmund_style=shortcut,chris_style=ultra_shortcut;viz_parameters...)
		end

		
	
		# Caluclate reversed hailstone_sequences
		if(ultra_shortcut)
			hailstone_sequences = [ 
				reverse(ultra_shortcut_collatz(starting_number))
				for starting_number in 1:viz_parameters.num_traject
			]
		elseif(shortcut)
			hailstone_sequences = [ 
				reverse(shortcut_collatz(starting_number))
				for starting_number in 1:viz_parameters.num_traject
			]
		else
			hailstone_sequences = reverse_hailstone_sequences(1:viz_parameters.num_traject;
						collatz_parameters...)
		end
		# Draw the sequence and store in an image matrix
		imgdata = @imagematrix begin
			background(viz_parameters.background_color)
			draw_hailstone_sequences(
				hailstone_sequences; params = viz_parameters
			)
		end viz_parameters.window_width viz_parameters.window_height

		# Convert matrix to img 
		imgdata = convert.(Colors.RGBA, imgdata)
	
		return new(viz_parameters, collatz_parameters ,imgdata, shortcut,ultra_shortcut, notes)
	end
end

# ╔═╡ b7161895-ba79-4b99-b2f1-eda7484708da
begin

	viz_thumbnail = CollatzVisualization(
		viz_parameters = (
				num_traject = 10000,
				line_length = 15,
				turn_scale = 9.3,
				window_width = 500.0,
				window_height = 500.0, 
				x_start = 100.0, 
				y_start = 0.0,
				init_angle = 270, 
				stroke_width = 2.0, 
				stroke_color = RGB(38/255,148/255,30/255), 
				background_color = RGB(188/255, 251/255, 199/255), 
				vary_shade=true,
				random_shade=false
			),
		ultra_shortcut = true,
		
	)

	viz_5_5_5 = CollatzVisualization(
		viz_parameters = (
				num_traject = 1000,
				line_length = 15,
				turn_scale = 21.3,
				window_width = 500.0,
				window_height = 500.0, 
				x_start = 500.0, 
				y_start = 250.0,
				init_angle = 30.5, 
				stroke_width = 2.0, 
				stroke_color = RGB(0,102/255,0), 
				background_color = RGB(128/255, 234/255, 193/255), 
				vary_shade=true,
				random_shade=false
			),
		collatz_parameters = (
			P = 5,
			a = 5,
			b = 5
		)
	)

	viz_3_7_2 = CollatzVisualization(
		viz_parameters = (
				num_traject = 1000,
				line_length = 24, 
				turn_scale = 10.3,
				window_width = 500.0,
				window_height = 500.0, 
				x_start = 500.0, 
				y_start = 250.0,
				init_angle = 306.0, 
				stroke_width = 2.0, 
				stroke_color = RGB(67/255,65/255,210/255), 
				background_color = RGB(0/255,4/255,36/255), 
				vary_shade=true,
				random_shade=false
		),
		collatz_parameters = (
			P = 2,
			a = 3,
			b = 7
		)
	)
	
	viz_1_1_3 = CollatzVisualization(
		viz_parameters = (
			num_traject = 1000,
			line_length = 25, 
			turn_scale = 15.0,
			window_width = 500.0,
			window_height = 500.0, 
			x_start = 500.0, 
			y_start = 250.0,
			init_angle = 24.0, 
			stroke_width = 2.0, 
			stroke_color = RGB(191/255,237/255,253/255), 
			background_color = RGB(1/255,152/255,150/255), 
			vary_shade=true,
			random_shade=false
		),
		collatz_parameters = (
			P = 3,
			a = 1,
			b = 1
		)
	)
	viz_3_1_7 = CollatzVisualization(
		collatz_parameters = (
			P = 7,
			a = 1,
			b = 3
		),
		viz_parameters = (
			num_traject = 1000,
			line_length = 22, 
			turn_scale = 11.0,
			window_width = 500.0,
			window_height = 500.0, 
			x_start = 500.0, 
			y_start = 250.0,
			init_angle = 5.0, 
			stroke_width = 2.0, 
			stroke_color = RGB(236/255,196/255,50/255), 
			background_color = RGB(255/255,243/255,163/255), 
			vary_shade=true,
			random_shade=false
		)
	)

	hex_grid = CollatzVisualization(
		viz_parameters = (
				num_traject = 1000,
				line_length = 12,
				turn_scale = 60.0,
				window_width = 500.0,
				window_height = 500.0, 
				x_start = 300.0, 
				y_start = 350.7,
				init_angle = 112.8, 
				stroke_width = 3.0, 
				stroke_color = RGB(196/255,132/255,231/255), 
				background_color = RGB(28/255,0,87/255), 
				vary_shade=true,
				random_shade=false
			),
		collatz_parameters = (
			P = 2,
			a = 3,
			b = 1
		)
	)

	
	lil_guy = CollatzVisualization(
		viz_parameters = (
				num_traject = 600,
				line_length = 42,
				turn_scale = 29.4,
				window_width = 500.0,
				window_height = 500.0, 
				x_start = 300.0, 
				y_start = 150.0,
				init_angle = 74.3, 
				stroke_width = 3.0, 
				stroke_color = RGB(230/255,130/255,130/255), 
				background_color = RGB(0/255,0,0/255), 
				vary_shade=true,
				random_shade=false
			),
		collatz_parameters = (
			P = 3,
			a = 8,
			b = 1
		)
	)
	
	gallery_vizs = [viz_thumbnail, viz_5_5_5, viz_3_1_7,viz_1_1_3,viz_3_7_2, hex_grid, lil_guy,]
	
end;

# ╔═╡ f718bbfd-2e86-45c5-96b3-ef3d810966a9
"""
	buffer_img_data(vis::CollatzVisualization)

Helper function to transform the RGBA img of CollatzVisualization into a UInt8 buffer for loading onto a html canvas.
"""
function buffer_img_data(vis::CollatzVisualization)
	buffer::Vector{UInt8} = [] 
		
	for pix in vis.imgdata
		push!(buffer, reinterpret.(UInt8, [pix.r, pix.g, pix.b, pix.alpha])...)
	end
	return buffer
end

# ╔═╡ 7335059c-d9b8-40a5-b2c0-6bcca4bdfe28
function Base.getproperty(obj::CollatzVisualization, sym::Symbol) 
	if(sym == :P) return obj.collatz_parameters.P end
	if(sym == :a) return obj.collatz_parameters.a end
	if(sym == :b) return obj.collatz_parameters.b end
	return getfield(obj, sym)
end

# ╔═╡ b4a31304-34a3-4ecc-8c6e-e67714bc5d52
function Base.show(io::IO, m::MIME"image/png",obj::CollatzVisualization)
	show(io, m, obj.imgdata)
end

# ╔═╡ ae8c02c0-2944-42dc-8a19-a45fbdc16134
md"### HTML Functions"

# ╔═╡ f47eb656-67ec-4760-8906-713fa480cb47
md"### Interactivity extensions"

# ╔═╡ 43479204-cd12-40b4-a65f-16bf54aaddfe
@with_kw struct SliderParameter{T} 
	lb::T = 0.0
	ub::T = 100.0
	step::T = 1.0
	default::T = lb
	label::String 
	alias::Symbol = Symbol(label)
	function SliderParameter{T}(lb::T,ub::T,step::T,default::T, label::String, alias::Symbol) where T
		 if ub < lb error("Invalid Bounds") end 
		 return new{typeof(default)}(lb,ub,step,default,label,alias)
	end
end

# ╔═╡ 31a7994d-13e0-440a-8279-5f19d7d0933f
@with_kw struct NumberFieldParameter{T}
	lb::T = 0
	ub::T = 100
	step::T = 1
	default::T = lb
	label::String
	alias::Symbol = Symbol(label)
	function NumberFieldParameter(lb,ub,step,default, label, alias) 
		 if ub < lb error("Invalid Bounds") end 
		 return new{typeof(default)}(lb,ub,step,default,label,alias)
	end
end

# ╔═╡ 25d2291f-f422-41e4-aa61-9000e13d34ad
@with_kw struct CheckBoxParameter
	label::String 
	default::Bool = false
	alias::Symbol = Symbol(label)
end

# ╔═╡ 1255f4cc-7448-40f6-83ba-0cca1637d1cf
@with_kw struct ColorParameter
	label::String 
	default::RGB = RGB(0,0,0)
	alias::Symbol = Symbol(label)
end

# ╔═╡ 7dac4da8-0877-4d07-b4d2-2164faeccfde
function format_sliderParameter( params::Vector{SliderParameter{T}};title::String,) where T
	
	return combine() do Child
		
		mds = [
			@htl("""
			<div>
			<p>$(param.label)
			</div>
			<div>
				$(Child(param.alias, PlutoUI.Slider(param.lb:param.step:param.ub, default = param.default, show_value = true))) 
			</div>
			
			""")
			
			for param in params
		]
		md"""
		#### $title
		$(mds)
		"""
	end
end

# ╔═╡ 4dd44fbd-f26a-4b72-a580-842209b44f27
function format_sliderParameter( params::Vector{SliderParameter};title::String,)
	
	return combine() do Child
		
		mds = [
			@htl("""
			<div>
			<p>$(param.label)
			</div>
			<div>
				$(Child(param.alias, PlutoUI.Slider(param.lb:param.step:param.ub, default = param.default, show_value = true))) 
			</div>
			
			""")
			for param in params
		]
		md"""
		#### $title
		$(mds)
		"""
	end
end

# ╔═╡ e57da7e5-32bb-48a2-af27-5ac671cabdae
@bind hailstone_params format_sliderParameter(title="Hailstone Sequence Parameters:",[
	SliderParameter(lb=1,ub=1000,default=15,step=1,alias=:start_value,label="Starting Value")]
	)

# ╔═╡ 43c4fd8d-bb44-43cd-91dd-d221629d1fd9
begin
graph_sliders = @bind graph_parameters format_sliderParameter(title="Collatz Graph Parameters:",[
	SliderParameter(lb=1,ub=1000,default=1,step=1,alias=:start_value,label="Starting Value"),
	SliderParameter(lb=1,ub=25,default=9,step=1,alias=:orbit,label="Maximum Orbit")
	
])
	

	@htl("""
	<div class="slider_group">
	<div>
		$graph_sliders
	</div>
	
	</div>
	""")
end

# ╔═╡ 0fd7242c-46a1-4929-9c53-3c45768893b4
@bind stopping_parameters format_sliderParameter(title="Stopping Time Plot Parameters",
	[SliderParameter(lb=100, ub=30000, step=100, default=1000,alias=:ub, label="Upper Bound")]

)

# ╔═╡ 5ba5f885-1de1-4058-91bf-35e1b05d1941
viz_sliders = @bind viz_parameters format_sliderParameter(
			title = "Visualization Options:", 
			[
				SliderParameter(
					lb = 100.0,
					ub = 10000.0, 
					default = 1000.0, 
			 		step = 100.0, 
					alias = :num_traject, 
					label = "Numbers of trajectories"
				),
				SliderParameter(
					lb = 1,
					ub = 150, 
					default = 20,
					step = 1,
					alias=:line_length, 
					label="Step"),
				SliderParameter(
					lb = 0.0,
					ub = 180.0, 
					default = 10.0,
					step = 0.1, 
					alias = :turn_scale, 
					label = "Rotation Angle (in degrees)"
				),
			]
		);

# ╔═╡ f21f1e3e-a3ab-458e-a101-ce824731f0b6
begin
collatz_sliders = @bind collatz_parameters format_sliderParameter(title="Collatz Parameters:",[
	SliderParameter(lb=1,ub=10,step=1,default=2,label="P"),
	SliderParameter(lb=1,ub=10,step=1,default=3,label="a"),
	SliderParameter(lb=1,ub=10,step=1,label="b"),
])
	if(do_generalize_collatz)
		collatz_sliders
	else
	end
end

# ╔═╡ 66fe673a-7679-4c55-bf59-146a8dd1241c
begin
	hailstone_seq = "Hailstone Sequence" ∈ generalize_collatz ? hailstone_sequence(hailstone_params.start_value; collatz_parameters... ,verbose=false) : hailstone_sequence(hailstone_params.start_value; verbose=false)

	fig_hail = Figure(size = (640, 420))
	ax_hail = Axis(fig_hail[1, 1];
		title = "Hailstone sequence of: " * string(hailstone_params.start_value),
		xlabel = "Iterations",
		ylabel = "Value")

	hail_x = Float64[]
	hail_y = Float64[]
	for (i, v) in enumerate(hailstone_seq)
		push!(hail_x, Float64(i))
		push!(hail_y, Float64(v))
	end
	lines!(ax_hail, hail_x, hail_y; color = (0.678, 0.847, 0.902, 1.0))
	scatter!(ax_hail, hail_x, hail_y; markersize = 12.0, color = (0.678, 0.847, 0.902, 1.0))

	fig_hail
end

# ╔═╡ 6693800b-e2bc-46e4-b5f8-004184ef472b
begin
	g, record = "Graph" ∈ generalize_collatz ?  make_collatz_graph(
		graph_parameters.start_value,
		graph_parameters.orbit;
		collatz_parameters...
	) :  make_collatz_graph(
		graph_parameters.start_value,
		graph_parameters.orbit;
	)
	
	graph_colors = [RGB(rescale(record[i][1],1,graph_parameters.orbit, 1,0.3),.1,.3) 
		               for i in 1:nv(g)]
end;

# ╔═╡ 3550fe19-261e-4069-9bf6-6417dcaac102
begin
	collatz_graph = @drawsvg begin
	    background("white")
	    sethue("grey40")
	    fontsize(25)
	    drawgraph(g, 
			layout=Stress(initialpos=[(0.0,0.0)]),
			margin = 60,                         
	        vertexlabels = map(x -> x[2], record),
			vertexshapesizes = 40,
	        vertexfillcolors = graph_colors
	    )	
	end 1600 1200
			
	collatz_graph
end

# ╔═╡ 45ca6e2a-6a58-475e-9c02-4925e71625bd
begin
	# find values that that have not been previously been calculated
	newValues = filter(x -> !(x ∈ keys(stopping_times)),collect(range(1,stopping_parameters.ub,step=1)) )
	
	# calculate the values and add them to the dictionary 
	for newValue in newValues
		push!(stopping_times, 
			( newValue => "Stopping Time" ∈ generalize_collatz ? stopping_time(newValue, ;collatz_parameters..., total_stopping_time=true) : stopping_time(newValue, total_stopping_time=true))
		)
	end

	st_vals = collect(values(sort(
			filter(
				key -> (key[1] ∈ range(1,stopping_parameters.ub,step=1))
				, stopping_times)
		)
	))
	st_x = Float64[]
	st_y = Float64[]
	for (i, v) in enumerate(st_vals)
		push!(st_x, Float64(i))
		push!(st_y, Float64(v))
	end

	fig_st = Figure(size = (640, 420))
	ax_st = Axis(fig_st[1, 1];
		title = "Total stopping time of numbers up to " * string(stopping_parameters.ub),
		xlabel = "Starting point",
		ylabel = "Stopping time")
	scatter!(ax_st, st_x, st_y; markersize = 4.0)
	fig_st
end

# ╔═╡ 5977a13d-93b8-4e51-8484-5b1882100c49
function format_numberFieldParameter( params::Vector{NumberFieldParameter{T}};title::String,) where T
	
	return combine() do Child
		
		mds = [
			@htl("""
			<div>
			<p>$(param.label)
			</div>
			<div>
				$(Child(param.alias, PlutoUI.NumberField(param.lb:param.step:param.ub, default = param.default)) ) 
			</div>
			
			""")
			for param in params
		]
		md"""
		#### $title
		$(mds)
		"""
	end
end

# ╔═╡ 0865f8a3-a959-481b-a9ae-adbca78a2749
begin
	window_size_sliders = @bind window_size_parameters format_numberFieldParameter(
		title="Window Size",
	[
		NumberFieldParameter(
			lb=100.0,
			ub=10000.0,
			default=700.0,
			alias = :window_height, 
			label = "Height", 
		),
		NumberFieldParameter(
			lb=100.0,
			ub=10000.0,
			default=500.0,
			alias=:window_width, 
			label="Width")
	]
	)
end


# ╔═╡ 8a64e9e3-477e-4a7e-97f7-61cf5e428731
@unpack window_height,window_width = window_size_parameters;

# ╔═╡ 7dbfb4dc-c9d0-464d-83b2-18db90d76878
viz_specs_sliders = @bind viz_specs_parameters format_sliderParameter(
			title = "Image Options:", 
			[
				SliderParameter(
					lb = 0.0,
					ub = 360.0,
					default = 20.0,
					step = 0.1,
					alias = :init_angle, 
					label = "Image Rotation (in degrees)"
				),
				SliderParameter(
					lb = 0.0,
					ub = window_width, 
					default = window_width/2, 
					step = 0.1, 
					alias = :x_start, 
					label = "Starting point (X)"
				),
				SliderParameter(
					lb = 0.0, 
					ub = window_height,
					default = window_height, 
					step = 0.1, 
					alias = :y_start, 
					label = "Starting point (Y)"
				),
				SliderParameter(
					lb = 1.0, 
					ub = 50.0,
					default = 5.0, 
					step = 0.1, 
					alias = :stroke_width, 
					label = "Stroke Width"
				),
			]
		);

# ╔═╡ a7885279-3f73-4c5d-aeef-061dea1ce930
function format_checkBoxParameter( params::Vector{CheckBoxParameter};title::String)
	
	return combine() do Child
		
		mds = [
			@htl("""
			<div>
			<p>$(param.label)
			</div>
			<div>
				$(Child(param.alias, PlutoUI.CheckBox(default=param.default)) ) 
			</div>
			
			""")
			
			for param in params
		]
		
		md"""
		#### $title
		$(mds)
		"""
	end
end

# ╔═╡ f680e7ea-8e3a-41ac-ab92-a27c05103864
viz_extra_sliders = @bind viz_extra_options format_checkBoxParameter(
			title="Extra Options",
			[
				CheckBoxParameter(
					alias=:random_shade, 
					label="Random Color"
				),
				CheckBoxParameter(
					alias=:vary_shade, 
					label="Vary Shade"
				),
				CheckBoxParameter(
					alias=:edmund_style, 
					label="In Edmund Harris's style"
				),
				CheckBoxParameter(
					alias=:chris_style, 
					label="In Chris's style"
				),
			], 
		);

# ╔═╡ 2d98aed3-9a51-4225-b914-a20b19f43908
function format_colorPicker( params::Vector{ColorParameter};title::String)
	
	return combine() do Child
		
		mds = [
			@htl("""
			<div>
			<p>$(param.label)
			</div>
			<div>
				$(Child(param.alias, PlutoUI.ColorPicker(default=param.default))) 
			</div>
			
			""")
			
			for param in params
		]
		
		md"""
		#### $title
		$(mds)
		"""
	end
end

# ╔═╡ 01cc5e4f-d94b-4211-b268-9ce0640cd23f
colors_sliders = @bind viz_colors_options format_colorPicker(
		title="Color Options",
	[
		ColorParameter(
		alias = :stroke_color, 
		label = "Stroke Color", 
		default = RGB{N0f8}(
			reinterpret(N0f8, UInt8(230)),
			reinterpret(N0f8, UInt8(130)),
			reinterpret(N0f8, UInt8(130)))
		),
		ColorParameter(
			alias=:background_color, 
			label="Background")
	]
	
);

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

# ╔═╡ 6d225dce-3362-4f5d-bba9-0b5312f6be5a
begin
	@unpack ( num_traject, turn_scale, line_length ) = viz_parameters
	@unpack ( init_angle, x_start, y_start, stroke_width) = viz_specs_parameters
	@unpack ( stroke_color, background_color ) = viz_colors_options
	@unpack ( random_shade, vary_shade, edmund_style, chris_style ) = viz_extra_options

	# Trajectories exactly as CollatzVisualization computes them
	viz_trajectories = if chris_style
		[reverse(ultra_shortcut_collatz(n)) for n in 1:num_traject]
	elseif edmund_style
		[reverse(shortcut_collatz(n)) for n in 1:num_traject]
	else
		reverse_hailstone_sequences(1:num_traject;
			P = collatz_parameters.P, a = collatz_parameters.a, b = collatz_parameters.b)
	end

	# Turtle-walk each sequence in pure Julia (WasmMakie draws the paths):
	# start at (x_start, y_start) heading init_angle+180°, turn by parity,
	# step line_length — the same rules draw_hailstone_sequence used.
	interactive_viz = let
		fig = Figure(size = (Float64(window_width), Float64(window_height)))
		ax = Axis(fig[1, 1])
		hidedecorations!(ax)
		hidespines!(ax)

		base_r = Float64(red(stroke_color))
		base_g = Float64(green(stroke_color))
		base_b = Float64(blue(stroke_color))

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
					θ += (mod(v, 3) == 1 ? turn_scale : -turn_scale)
				elseif mod(v, 2) == 0
					θ += turn_scale
				else
					θ -= edmund_style ? turn_scale / 2 : turn_scale
				end
				x += line_length * cosd(θ)
				y += line_length * sind(θ)
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

# ╔═╡ 1b48b435-e959-477f-a8d2-3507da73fc28
@htl("""
$(PlutoUI.DownloadButton("<!doctype html><html><body>" * html_snippet(interactive_viz) * "</body></html>", (filename == "" ? "MyCoolVisualization" : filename) * ".html"))
"""
)

# ╔═╡ d9aaaadc-7d94-4e85-a1cb-c137e869ad2f
md"### Extras"

# ╔═╡ fb2dd0e1-5198-4c0a-b62b-50649ac21f32
begin
	# getters
	get_num_trajects(viz::CollatzVisualization) = viz.viz_parameters.num_traject
	get_line_length(viz::CollatzVisualization) = viz.viz_parameters.line_length
	get_turn_scale(viz::CollatzVisualization) = viz.viz_parameters.turn_scale
	get_window_width(viz::CollatzVisualization) = viz.viz_parameters.window_width
	get_window_height(viz::CollatzVisualization) = viz.viz_parameters.window_height
	get_x_start(viz::CollatzVisualization) = viz.viz_parameters.x_start
	get_y_start(viz::CollatzVisualization) = viz.viz_parameters.y_start
	get_init_angle(viz::CollatzVisualization) = viz.viz_parameters.init_angle
	get_stroke_width(viz::CollatzVisualization) = viz.viz_parameters.stroke_width
	get_stroke_color(viz::CollatzVisualization, as_hex=true) = as_hex ? hex(RGB(viz.viz_parameters.stroke_color)) : viz.viz_parameters.stroke_color
	get_background_color(viz::CollatzVisualization, as_hex=true) = as_hex ? hex(RGB(viz.viz_parameters.background_color)) : viz.viz_parameters.background_color
	get_vary_shade(viz::CollatzVisualization) = viz.viz_parameters.vary_shade 
	get_random_shade(viz::CollatzVisualization) = viz.viz_parameters.random_shade
	get_notes(viz::CollatzVisualization) = viz.notes
end

# ╔═╡ 03eb05fa-57bc-45d0-9943-79034ed10211
"""
	makeCollatzGallery(visualizations::Vector{CollatzVisualization}; width::Int=500, height::Int=500)

Helper function to format an array of visualizations into a scrollable gallery, with an panel below the image showing the parameters used to generate the visualization.

## Kwargs
-`width::Int`=500: Width of each image in pixels

-`height::Int`=500: Height of each image in pixels

"""
function makeCollatzGallery(visualizations::Vector{CollatzVisualization}; width::Int=500, height::Int=500)
	res = []
	for (i,viz) in enumerate(visualizations)
		push!(res, @htl("""
		<div>
			<div class="canvas-container">
				<canvas id="canvas$(i-1)" width="$width" height="$height">
				</canvas>
			</div>
			<div class="notes-container ">
				<div class="notes-container-inner">
					Parameters:
					<br>
					P: $(viz.P)
					<br>
					a: $(viz.a)
					<br>
					b: $(viz.b)
					<br>
				</div>
				<div class="notes-container-inner">
					Number of trajectories: $(get_num_trajects(viz))
					<br>
					Step length: $(get_line_length(viz))
					<br>
					Rotation Angle: $(get_turn_scale(viz))
				</div>
				<div class="notes-container-inner">
					Window Width: $(get_window_width(viz))
					<br>		
					Window Height: $(get_window_height(viz))
					<br>
					Starting point (X): $(get_x_start(viz))
					<br>
					Starting point (Y): $(get_y_start(viz))
					<br>
					Rotation Angle: $(get_init_angle(viz))
				</div>
				<div class="notes-container-inner">
					Stroke Width: $(get_stroke_width(viz))
					<br>
					Stroke Color: #$(get_stroke_color(viz))
					<br>
					Background Color: #$(get_background_color(viz))
				</div>
				<div class="notes-container-inner">
					Shade Variation: $(get_vary_shade(viz))
					<br>
					Random Shade: $(get_random_shade(viz))
				</div>

				$(get_notes(viz))
				
			</div> 
		</div>"""))
	end
	return res
end

# ╔═╡ 53520512-fc88-4dd2-ae6d-a8ed0d599e42
begin
	@htl("""
	<script>
	
	
	const buffers = $([buffer_img_data(viz) for viz in gallery_vizs])
	buffers.forEach((buffer, index) => {
		
		const canvas = document.getElementById("canvas"+index);
		const ctx = canvas.getContext("2d");
		const arr = new Uint8ClampedArray(buffer);
		let imageData = new ImageData(arr, 500, 500);
		ctx.putImageData(imageData, 0, 0);
		
		
	})
	</script>
	<div class="gallery">
		$(makeCollatzGallery(gallery_vizs))
	</div>
	""")
end

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
Collatz = "93a6299e-2ed6-4a7f-9f14-000d52f8d402"
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
FixedPointNumbers = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
ImageIO = "82e4d734-157c-48bb-816b-45c225c6df19"
ImageShow = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
Karnak = "cd156443-31ad-4f6f-850f-a93ee5f75905"
Luxor = "ae8d54c2-7ccd-5906-9d76-62fc9837b5bc"
NetworkLayout = "46757867-2c16-5918-afeb-47bfcb05e46a"
Parameters = "d96e819e-fc66-5662-9728-84c9c7592b0a"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

[sources]
WasmMakie = {url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"}

[compat]
Collatz = "~1.0.0"
Colors = "~0.13.1"
FixedPointNumbers = "~0.8.6"
Graphs = "~1.14.0"
HypertextLiteral = "~1.0.0"
ImageIO = "~0.6.9"
ImageShow = "~0.3.8"
Karnak = "~1.2.0"
Luxor = "~4.5.0"
NetworkLayout = "~0.4.10"
Parameters = "~0.12.3"
PlutoUI = "~0.7.83"
WasmMakie = "~0.1.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "85ed1d9b55b38650116ce71b4d87af5603df174b"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "4126b08903b777c88edf1754288144a0492c05ad"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.8"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "71aa551c5c33f1a4415867fe06b7844faadb0ae9"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.1.1"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "1fa950ebc3e37eccd51c6a8fe1f92f7d86263522"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.7+0"

[[deps.CodecZstd]]
deps = ["TranscodingStreams", "Zstd_jll"]
git-tree-sha1 = "da54a6cd93c54950c15adf1d336cfd7d71f51a56"
uuid = "6b39b394-51ab-5f42-8807-6242bab2b4c2"
version = "0.8.7"

[[deps.Collatz]]
git-tree-sha1 = "f2ebb33a345e086823cc57ed206e956eb8f1d4d8"
uuid = "93a6299e-2ed6-4a7f-9f14-000d52f8d402"
version = "1.0.0"

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

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "6fb53a69613a0b2b68a0d12671717d307ab8b24e"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.5"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c307cd83373868391f3ac30b41530bc5d5d05d08"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.8.1+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "95ecf07c2eea562b5adbd0696af6db62c0f52560"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.5"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libva_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "cac41ca6b2d399adfc95e51240566f8a60a80806"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "8.1.0+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "8e9c059d6857607253e837730dbf780b6b151acd"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.19.0"

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

    [deps.FileIO.weakdeps]
    HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "f85dac9a96a01087df6e3a749840015a0ca3817d"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.17.1+0"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "70329abc09b886fd2c5d94ad2d9527639c421e3e"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.14.3+1"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7a214fdac5ed5f59a22c2d9a885a16da1c74bbc7"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.17+0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "LinearAlgebra", "PrecompileTools", "Random", "StaticArrays"]
git-tree-sha1 = "364685f5ffde25deb1bbcfd5bb278a5c6b7a9b37"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.5.11"

    [deps.GeometryBasics.extensions]
    ExtentsExt = "Extents"
    GeometryBasicsGeoInterfaceExt = "GeoInterface"
    IntervalSetsExt = "IntervalSets"

    [deps.GeometryBasics.weakdeps]
    Extents = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
    GeoInterface = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"

[[deps.GettextRuntime_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll"]
git-tree-sha1 = "45288942190db7c5f760f59c04495064eedf9340"
uuid = "b0724c58-0f36-5564-988d-3bb0596ebc4a"
version = "0.22.4+0"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "24f6def62397474a297bfcec22384101609142ed"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.86.3+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "a641238db938fff9b2f60d08ed9030387daf428c"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.3"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a6dbda1fd736d60cc477d99f2e7a042acfa46e8"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.15+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "DataStructures", "Inflate", "LinearAlgebra", "Random", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "7eb45fe833a5b7c51cf6d89c5a841d5967e44be3"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.14.0"

    [deps.Graphs.extensions]
    GraphsSharedArraysExt = "SharedArrays"

    [deps.Graphs.weakdeps]
    Distributed = "8ba89e20-285c-5b6f-9357-94700520ee1b"
    SharedArrays = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "f923f9a774fcf3f5cb761bfa43aeadd689714813"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.5.1+0"

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

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "e12629406c6c4442539436581041d372d69c55ba"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.12"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "8c193230235bbcee22c8066b0374f63b5683c2d3"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.5"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs", "WebP"]
git-tree-sha1 = "696144904b76e1ca433b886b4e7edd067d76cbf7"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.9"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "2a81c3897be6fbcde0802a0ebe6796d0562f63ec"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.10"

[[deps.ImageShow]]
deps = ["Base64", "ColorSchemes", "FileIO", "ImageBase", "ImageCore", "OffsetArrays", "StackViews"]
git-tree-sha1 = "3b5344bcdbdc11ad58f3b1956709b5b9345355de"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.8"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dcc8d0cd653e55213df9b75ebc6fe4a8d3254c65"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.2.2+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.IntervalSets]]
git-tree-sha1 = "79d6bd28c8d9bccc2229784f1bd637689b256377"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.14"

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

    [deps.IntervalSets.weakdeps]
    Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "9496de8fb52c224a2e3f9ff403947674517317d9"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.6"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c0c9b76f3520863909825cbecdef58cd63de705a"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.5+0"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.Karnak]]
deps = ["Colors", "Graphs", "InteractiveUtils", "Luxor", "NetworkLayout", "Reexport", "SimpleWeightedGraphs"]
git-tree-sha1 = "14b4c3f33e75719d697c7e4845f13fb5b3772104"
uuid = "cd156443-31ad-4f6f-850f-a93ee5f75905"
version = "1.2.0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "17b94ecafcfa45e8360a4fc9ca6b583b049e4e37"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.1.0+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eb62a3deb62fc6d8822c0c4bef73e4412419c5d8"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.8+0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.15.0+0"

[[deps.LibGit2]]
deps = ["LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.9.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c8da7e6a91781c41a863611c7e966098d783c57a"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.4.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "cc3ad4faf30015a3e8094c9b5b7f19e85bdf2386"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.42.0+0"

[[deps.Librsvg_jll]]
deps = ["Artifacts", "Cairo_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "Libdl", "Pango_jll", "XML2_jll", "gdk_pixbuf_jll"]
git-tree-sha1 = "e6ab5dda9916d7041356371c53cdc00b39841c31"
uuid = "925c91fb-5dd6-59dd-8e8c-345e74382d89"
version = "2.54.7+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "f04133fe05eff1667d2054c53d59f9122383fe05"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.2+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d620582b1f0cbe2c72dd1d5bd195a9ce73370ab1"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.42.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.Luxor]]
deps = ["Base64", "Cairo", "Colors", "DataStructures", "Dates", "FFMPEG", "FileIO", "PolygonAlgorithms", "PrecompileTools", "Random", "Rsvg"]
git-tree-sha1 = "fe8060b3d693f682e14f1019b058c64effb62b43"
uuid = "ae8d54c2-7ccd-5906-9d76-62fc9837b5bc"
version = "4.5.0"

    [deps.Luxor.extensions]
    LuxorExtLatex = ["LaTeXStrings", "MathTeXEngine"]
    LuxorExtTypstry = ["Typstry"]

    [deps.Luxor.weakdeps]
    LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
    MathTeXEngine = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
    Typstry = "f0ed7684-a786-439e-b1e3-3b82803b501e"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.MappedArrays]]
git-tree-sha1 = "0ee4497a4e80dbd29c058fcee6493f5219556f40"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.3"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "dbd2e8cd2c1c27f0b584f6661b4309609c5a685e"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.4"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkLayout]]
deps = ["GeometryBasics", "LinearAlgebra", "Random", "Requires", "StaticArrays"]
git-tree-sha1 = "f7466c23a7c5029dc99e8358e7ce5d81a117c364"
uuid = "46757867-2c16-5918-afeb-47bfcb05e46a"
version = "0.4.10"
weakdeps = ["Graphs"]

    [deps.NetworkLayout.extensions]
    NetworkLayoutGraphsExt = "Graphs"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OffsetArrays]]
git-tree-sha1 = "117432e406b5c023f665fa73dc26e79ec3630151"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.17.0"

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

    [deps.OffsetArrays.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6aa4566bb7ae78498a5e68943863fa8b5231b59"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.6+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "4a33fd64a77949468187339d8b10c44a422082f1"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.4.12+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.7+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e2bb57a313a74b8104064b7efd01406c0a50d2ff"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.6.1+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "94ba93778373a53bfd5a0caaf7d809c445292ff4"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.2"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.44.0+1"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "32b657a0d57c310a1a172bfc8c8cf68c5e674323"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.5"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "58e5ed5e386e156bd93e86b305ebd21ac63d2d04"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.57.1+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "e4a6721aa89e62e5d4217c0b21bd714263779dda"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.46.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.12.1"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.PolygonAlgorithms]]
git-tree-sha1 = "c1092ada65e6d59d6361d5086ddb0a5ea63ae204"
uuid = "32a0d02f-32d9-4438-b5ed-3a2932b48f96"
version = "0.4.0"

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

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "fbb92c6c56b34e1a2c4c36058f68f332bec840e7"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.11.0"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "472daaa816895cb7aee81658d4e7aec901fa1106"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.Rsvg]]
deps = ["Cairo", "Glib_jll", "Librsvg_jll"]
git-tree-sha1 = "e53dad0507631c0b8d5d946d93458cbabd0f05d7"
uuid = "c4c386cf-5103-5370-be45-f3a111cca3b8"
version = "1.1.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "e24dc23107d426a096d3eae6c165b921e74c18e4"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.2"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "7ddb0b49c109481b046972c0e4ab02b2127d6a75"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.6"

[[deps.SimpleWeightedGraphs]]
deps = ["Graphs", "LinearAlgebra", "Markdown", "SparseArrays"]
git-tree-sha1 = "749a2b719ec7f34f280c0d97ac3dab5c89818631"
uuid = "47aef6b3-ad0c-573a-a1e2-d07658019622"
version = "1.5.1"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "0494aed9501e7fb65daba895fb7fd57cc38bc743"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.5"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.12.0"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "246a8bb2e6667f832eea063c3a56aef96429a3db"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.18"

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

    [deps.StaticArrays.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6ab403037779dae8c514bad259f32a447262455a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.8.3+2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TiffImages]]
deps = ["CodecZstd", "ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "9ca5f1f2d42f80df4b8c9f6ab5a64f438bbd9976"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.9"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

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

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.WasmMakie]]
deps = ["Base64"]
git-tree-sha1 = "de6c9a45585e892ac96fa7ad9fd3b1d3d61277ec"
repo-rev = "main"
repo-url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"
uuid = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"
version = "0.1.0"

[[deps.WebP]]
deps = ["CEnum", "ColorTypes", "FileIO", "FixedPointNumbers", "ImageCore", "libwebp_jll"]
git-tree-sha1 = "aa1ca3c47f119fbdae8770c29820e5e6119b83f2"
uuid = "e3aaa7dc-3e4b-44e0-be63-ffb868ccd7c1"
version = "0.1.3"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "80d3930c6347cfce7ccf96bd3bafdf079d9c0390"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.9+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b29c22e245d092b8b4e8d3c09ad7baa586d9f573"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.3+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "808090ede1d41644447dd5cbafced4731c56bd2f"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.13+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "1a4a26870bf1e5d26cd585e38038d399d7e65706"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.8+0"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "75e00946e43621e09d431d9b95818ee751e6b2ef"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "6.0.2+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "7ed9347888fac59a618302ee38216dd0379c480d"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.12+0"

[[deps.Xorg_libpciaccess_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "58972370b81423fc546c56a60ed1a009450177c3"
uuid = "a65dc6b1-eb27-53a1-bb3e-dea574b5389e"
version = "0.19.0+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.gdk_pixbuf_jll]]
deps = ["Artifacts", "Glib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Xorg_libX11_jll", "libpng_jll"]
git-tree-sha1 = "895f21b699121d1a57ecac57e65a852caf569254"
uuid = "da03df04-f53b-5353-a52f-6a8b0620ced0"
version = "2.42.13+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "850b06095ee71f0135d644ffd8a52850699581ed"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.13.3+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "125eedcb0a4a0bba65b657251ce1d27c8714e9d6"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.4+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.libdrm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "63aac0bcb0b582e11bad965cef4a689905456c03"
uuid = "8e53e030-5e6c-5a89-a30b-be5b7263a166"
version = "2.4.125+1"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e51150d5ab85cee6fc36726850f0e627ad2e4aba"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.58+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libva_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll", "Xorg_libXfixes_jll", "libdrm_jll"]
git-tree-sha1 = "7dbf96baae3310fe2fa0df0ccbb3c6288d5816c9"
uuid = "9a156e7d-b971-5f62-b2c9-67348b8fb97c"
version = "2.23.0+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "4e4282c4d846e11dce56d74fa8040130b7a95cb3"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.6.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.7.0+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14cc7083fc6dff3cc44f2bc435ee96d06ed79aa7"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.1+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e7b67590c14d487e734dcb925924c5dc43ec85f3"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "4.1.0+0"
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
# ╟─6693800b-e2bc-46e4-b5f8-004184ef472b
# ╟─6f68b20d-67e5-4872-a23b-1840bbbb06ec
# ╟─6a45247d-25db-445f-a687-191c0952c6c4
# ╟─0fd7242c-46a1-4929-9c53-3c45768893b4
# ╟─45ca6e2a-6a58-475e-9c02-4925e71625bd
# ╟─5f074850-b967-4de5-8ca3-b85a74052499
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
# ╟─53520512-fc88-4dd2-ae6d-a8ed0d599e42
# ╟─b7161895-ba79-4b99-b2f1-eda7484708da
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
# ╟─d6cc6642-018d-4a7f-b82a-dd50bff8e2fc
# ╟─8c854d1c-2f89-43f0-a810-ce174cf94af8
# ╟─9803f163-0027-4577-af8f-c66de195d182
# ╟─1e85c1af-3318-4f20-a358-25aa0999dc8a
# ╟─40dd9659-abb9-4484-b5f1-f332e2abe90e
# ╟─f718bbfd-2e86-45c5-96b3-ef3d810966a9
# ╟─7335059c-d9b8-40a5-b2c0-6bcca4bdfe28
# ╟─b4a31304-34a3-4ecc-8c6e-e67714bc5d52
# ╟─f02affaa-534b-4c72-81ae-c42ca3b455fd
# ╟─4c991173-d9ff-4ba9-b217-8f9aafbbd631
# ╟─240b4cc1-1bae-429b-863b-792897cd555b
# ╟─23be8efa-b907-453f-9245-8bc46a37ad26
# ╟─a1a6130d-771a-43d7-ae94-049e3c9b81b3
# ╟─319d784b-c62d-4f28-a5b3-ebf89c892afc
# ╟─3153ba89-f2d4-4e31-9e79-00ec5ecbb91c
# ╟─b79405c3-42d1-4289-bbc3-67b6eae2b135
# ╟─cf545d05-7846-4881-a532-33cb2c1972a4
# ╟─278572e6-5a74-4dad-b39b-68cc85e4339c
# ╟─5683080b-7d4b-4e34-aa75-b3c68dc60314
# ╟─ae8c02c0-2944-42dc-8a19-a45fbdc16134
# ╟─03eb05fa-57bc-45d0-9943-79034ed10211
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
# ╟─fb2dd0e1-5198-4c0a-b62b-50649ac21f32
# ╟─90dc6dd4-c4f3-4e4d-8e91-0fecafd258e1
# ╟─7baab6e9-31bb-4da5-8ab9-938546cc863e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
