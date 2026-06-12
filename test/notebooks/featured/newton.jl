### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> chapter = "1"
#> license_url = "https://github.com/mitmath/computational-thinking/blob/Fall23/LICENSE.md"
#> youtube_id = "Wjcx9sNSLP8"
#> video = "https://www.youtube.com/watch?v=Wjcx9sNSLP8"
#> layout = "layout.jlhtml"
#> description = "This lecture explains a method for finding the root of a function, but using code an illustrations instead of a chalkboard! We will illustrate the Newton method using the ForwardDiff.jl package to carry out automatic differentiation, but we will also try to understand what's going on \"under the hood\"."
#> text_license = "CC-BY-SA-4.0"
#> image = "https://user-images.githubusercontent.com/6933510/136196605-b6119b9d-223c-44bc-97d5-ef7cfce66483.gif"
#> code_license = "MIT"
#> section = "6"
#> title = "The Newton Method"
#> tags = ["lecture", "module1", "track_math", "continuous", "differentiation", "automatic differentiation", "ForwardDiff", "interactive", "Symbolics", "transformation"]
#> 
#>     [[frontmatter.author]]
#>     name = "MIT mathematics"
#>     url = "https://github.com/mitmath"

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

# ╔═╡ f4fda666-7b9c-11eb-0304-716c5e710462
begin
    using Symbolics, ForwardDiff, WasmMakie, PlutoUI, LaTeXStrings
	using ForwardDiff: jacobian
	import Latexify
end

# ╔═╡ dd6b0ae2-cc87-4d19-ac78-f3a990aa692e
html"""
<script src="https://cdn.jsdelivr.net/npm/lite-youtube-embed@0.3.0/src/lite-yt-embed.js" integrity="sha256-sDRYYtDc+jNi2rrJPUS5kGxXXMlmnOSCq5ek5tYAk/M=" crossorigin="anonymous" defer></script>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/lite-youtube-embed@0.3.0/src/lite-yt-embed.css" integrity="sha256-lv6SEl7Dhri7d86yiHCTuSWFb9CYROQFewxZ7Je0n5k=" crossorigin="anonymous">

<style>
.lecture-header {
    background: #282936;
    color: white;
    padding: 1rem;
    /* min-height: 500px; */
    /* width: 100%; */
    display: block;
    border-radius: 1rem;
    margin: 1rem;
}

.lecture-header * {
    color: white;
	text-decoration-color: white;
}

.lecture-header h1 {
    font-family: Vollkorn, serif;
    font-weight: 700;
    font-feature-settings: "lnum", "pnum";
}

.lecture-header .number {
    font-style: italic;
    font-size: 1.5rem;
    opacity: 0.8;
}

.lecture-header h1 {
    text-align: center;
    font-size: 2rem;
}
.lecture-header .video > div {
    display: flex;
    justify-content: center;
    overflow: hidden;
    max-width: 400px;
    margin: 0 auto;
}
.lecture-header .video iframe,
.lecture-header .video lite-youtube {
    /* max-width: 400px; */
    aspect-ratio: 16/9;
    flex: 1 1 auto;
}

</style>

<div class="lecture-header">
<!--
<h6 class="number">Section</h6>
<h1>Loading...</h1>
-->
<p>This lecture is part of <strong>Computational Thinking</strong>, a live online Julia/Pluto textbook. Go to <a href="https://computationalthinking.mit.edu/">computationalthinking.mit.edu</a> to read all 50 lectures for free.</p>
<!--
<div class="video">

	<h4>Lecture Video</h4>
	<div>
		
	</div>
</div>
-->


<script>
const div = currentScript.parentElement
const fm = getNotebookMetadataExperimental("frontmatter")
console.log(fm)

div.querySelector("h1").innerText = fm.title
div.querySelector(".number").innerText = `Section ${fm.chapter}.${fm.section}`


const yt = document.createElement("lite-youtube")
yt.setAttribute("videoid", fm.youtube_id)
div.querySelector(".video > div").append(yt)

</script>
</div>
"""

# ╔═╡ d82f1eae-7b9c-11eb-24d8-e1dcb2eef71a
md"""
## Solving equations and finding inverse transformations using the Newton method
"""

# ╔═╡ e410c1d0-7ba1-11eb-394f-71dac89756b7
md"""
In science and engineering we often need to *solve systems of equations*. 

If the equations are *linear* then linear algebra tells us a general method to solve them; these are now routinely applied to solve systems of millions of linear equations.

If the equations are *non*linear then things are less obvious. The main solution methods we know work by... reducing the nonlinear equations to a sequence of linear equations! They do this by *approximating* the function by a linear function and solving that to get a better solution, then repeating this operation as many times as necessary to get a *sequence* of increasingly better solutions. This is an example of an **iterative algorithm**.

A well-known and elegant method, which can be used in many different contexts, is the **Newton method**. It does, however, have the disadvantage that it requires derivatives of the function. This can be overcome using **automatic differentiation** techniques.

We will illustrate the Newton method using the `ForwardDiff.jl` package to carry out automatic differentiation, but we will also try to understand what's going on "under the hood".
"""

# ╔═╡ 5ea7344c-7ba2-11eb-2cc5-0bbdca218c82
md"""
## The Newton method in 1D

We would like to solve equations like $f(x) = g(x)$. 
We rewrite that by moving all the terms to one side of the equation so that we can write $h(x) = 0$, with $h(x) := f(x) - g(x)$.

A point $x^*$ such that $h(x^*) = 0$ is called a **root** or **zero** of $h$.

The Newton method finds zeros, and hence solves the original equation.
"""

# ╔═╡ 8c0c412e-7c2f-11eb-1880-4f6c45d77597
md"""


The idea of the Newton method is to *follow the direction in which the function is pointing*! We do this by building a **tangent line** at the current position and following that instead, until it hits the $x$-axis.

Let's look at that visually first:

"""

# ╔═╡ ce44554e-847f-4129-8841-1a729dfa7a2e
md"""
n = $(@bind n2 Slider(0:10, show_value=true, default=1))
"""

# ╔═╡ 77ef0cfb-60db-4599-bec2-b65e99e5b246
md"""
x₀ = $(@bind x02 Slider(-10:10, show_value=true, default=6))
"""

# ╔═╡ 2445da24-7b9d-11eb-02bd-eb99a3d95a2e
md"""
n = $(@bind n Slider(0:10, show_value=true, default=1))
"""

# ╔═╡ 9addbcbe-7b9e-11eb-3e8c-fbab3be40e05
md"""
x₀ = $(@bind x0 Slider(-10:10, show_value=true, default=6))
"""

# ╔═╡ c0b4defe-7c2f-11eb-1913-bdb01d28a4a8
md"""
## Using symbolic calculations to understand derivatives and nonlinear maps
"""

# ╔═╡ 615aff3c-7c30-11eb-2ca8-9d2fdf299017
md"""
We can use Julia's new symbolic capabilities to understand what's going on with a nonlinear (polynomial) function.

Let's see what happens if we perturb a function $f$ around a point $z$ by a small amount $\eta$.
"""

# ╔═╡ 71efd6b0-7c30-11eb-0da7-0d4a5ab8f8ff
@variables z, η

# ╔═╡ a869e6c6-7c31-11eb-13c8-155d08be02eb
md"""
m = $(@bind m Slider(1:6, show_value=true))
"""

# ╔═╡ 6dc89964-7c30-11eb-0a41-8d97b210ed34
f(x) = x^m - 2;

# ╔═╡ d35e0cc8-7c30-11eb-28d3-17c9e221ea62
f′(x) = ForwardDiff.derivative(f, x);

# ╔═╡ 63dbf052-7c32-11eb-1062-5b3581d38f70
f(z)

# ╔═╡ 9371f930-7c30-11eb-1f77-c7f31b97ea26
f(z + η)

# ╔═╡ 9d778e36-7c30-11eb-1f4b-894af86a8f5d
md"""
When $\eta$	is small, $\eta^2$ is *very* small, so we can ignore it. We are left with terms that either don't contain $\eta$ (constants), or multiply $\eta$ (linear). The part that multiplies $\eta$ is the derivative:
"""

# ╔═╡ db26375a-7c30-11eb-066e-ab9e8ded3356
f′(z)

# ╔═╡ ea741018-7c30-11eb-3912-a50475e6ec49
f(z) + η*f′(z)

# ╔═╡ 389e990e-7c40-11eb-37c4-5ba0f59173b3
md"""
The derivative gives the "*linear* part" of the function. `ForwardDiff.jl`, and forward-mode automatic differentiation in general, effectively uses this (although not symbolically in this sense) to just propagate the linear part of each function through a calculation.
"""

# ╔═╡ 5123c038-7ba2-11eb-1be2-19f789b02c1f
md"""
## Mathematics of the Newton method
"""

# ╔═╡ 9bfafcc0-7ba2-11eb-1b67-e3a3803ead08
md"""
We can convert the idea of "following the tangent line" into equations as follows.
(You can also do so by just looking at the geometry in 1D, but that does not help in 2D.)
"""

# ╔═╡ f153b4b8-7ba0-11eb-37ec-4f1a3dbe20e8
md"""
Suppose we have a guess $x_0$ for the root and we want to find a (hopefully) better guess $x_1$.

Let's set $x_1 = x_0 + \delta$, where $x_1$ and $\delta$ are still unknown.

We want $x_1$ to be a root, so
"""

# ╔═╡ 9cfa9062-7ba0-11eb-3a93-197ac0287ab4
md"""
$$f(x_1) = f(x_0 + \delta) \simeq 0$$
"""

# ╔═╡ 1ba1ae44-7ba1-11eb-21ff-558c95446435
md"""
If we are already "quite close" to the root then $\delta$ should be small, so we can approximate $f$ using the tangent line:

$$f(x_0) + \delta \, f'(x_0) \simeq 0$$

and hence

$$\delta \simeq \frac{-f(x_0)}{f'(x_0)}$$

so that

$$x_1 = x_0 - \frac{f(x_0)}{f'(x_0)}$$

Now we can repeat so that 

$$x_2 = x_1 - \frac{f(x_1)}{f'(x_1)}$$

and in general

$$x_{n+1} = x_n - \frac{f(x_n)}{f'(x_n)}.$$


This is the Newton method in 1D.
"""

# ╔═╡ ba570c4c-7ba2-11eb-2125-9f23e415a1dc
md"""
## Implementation in 1D
"""

# ╔═╡ d690f83a-7c2e-11eb-14d7-79a250deb473
function newton1D(f, x0)
	
	f′(x) = ForwardDiff.derivative(f, x)   # \prime<TAB>
	
	x0 = 37.0  # starting point
	sequence = [x0]
	
	x = x0
	
	for i in 1:10
		x -= f(x) / f′(x)
	end
	
	return x
	
end

# ╔═╡ 2fb40dc6-7c2f-11eb-2469-8deb4db59b5c
newton1D(x -> x^2 - 2, 37.0)

# ╔═╡ 35791bca-7c2f-11eb-1cfb-8d5ebd0208cb
sqrt(2)

# ╔═╡ 1d7dd328-7c2d-11eb-2b35-bdbf5df686f0
md"""
## Symbolic derivative in 2D

"""

# ╔═╡ d44c73b4-7c3e-11eb-1302-8ba9039ae789
md"""
Let's see what happens when we perturb by small amounts $\delta$ in the $x$ direction and $\epsilon$ in the $y$ direction around the point $(a, b)$:
"""

# ╔═╡ fe742fec-7c3e-11eb-1f54-55cdf02a1574
md"""
p = $(@bind p Slider(0:0.01:1, show_value=true))
"""

# ╔═╡ 23536420-7c2d-11eb-20b0-9523f7a5f9d7
@variables a, b, δ, ϵ

# ╔═╡ 4dd2322c-7ba0-11eb-2b3b-af7c6c1d60a0
md"""
## Newton for transformations in 2 dimensions

$$T: \mathbb{R}^2 \to \mathbb{R}^2$$

"""

# ╔═╡ 5c9edb2c-7ba0-11eb-14f6-3d5e52123bc7
md"""
We want to find the inverse $T^{-1}(y)$, i.e. to solve the equation $T(x) = y$ for $x$.

We use the same idea as in 1D, but now in 2D:
"""

# ╔═╡ 80917990-7ba0-11eb-029a-dba981c52b58
md"""
$$T(x_0 + \delta) \simeq 0$$

$$T(x_0) + J \cdot \delta \simeq 0,$$

where $J := DT_{x_0}$ is the Jacobian matrix of $T$ at $x_0$, i.e. the best linear approximation of $T$ near to $x_0$.
"""

# ╔═╡ af887dea-7ba1-11eb-3b0d-6925756382a7
md"""
Hence $\delta$ is the solution of the system of linear equations
"""

# ╔═╡ b7dc4666-7ba1-11eb-32eb-fd3d720c2960
md"""
$$J \cdot \delta = -T(x_0)$$

Then we again construct the new approximation $x_1$ as $x_1 := x_0 + \delta$.
"""

# ╔═╡ c519704c-7ba1-11eb-12da-8b9b176daa0d
md"""
In 2D we have an explicit formula for the inverse of the matrix.
"""

# ╔═╡ e1afc6ca-7ba1-11eb-3fb9-ef3a7f82d750
md"""
## Implementation in 2D
"""

# ╔═╡ 1db66b0e-7ba4-11eb-2157-d5a399a73b1f
function newton2D_step(T, x)
	
	J = ForwardDiff.jacobian(T, x)   # should use StaticVectors
	
	δ = J \ T(x)   # J^(-1) * T(x)
	
	return x - δ
end

# ╔═╡ 923bde64-7ba4-11eb-21e9-a11993aaab2e
"Find ``x`` such that ``T(x) = 0``"
function newton2D(T, x0, n=10)
	
	x = x0

	for i in 1:n
		x = newton2D_step(T, x)
	end
	
	return x
end

# ╔═╡ 61905ae0-7ba6-11eb-0773-17e9aa4e9991
md"""
Remember that Newton is designed to look for *roots*, i.e. places where $T(x) = 0$.
We want $T(x) = y$, so we need another layer:
"""

# ╔═╡ ff8b6aec-7ba5-11eb-0d83-19803b1bdda7
"Looks for ``x`` such that ``f(x) = y``, i.e. ``f(x) - y = 0``"
function inverse(f, y, x0=[0, 0])
	return newton2D(x -> f(x) - y, x0)
end

# ╔═╡ 2e2e5f0e-7c31-11eb-0da7-770b07ee6202
inverse(f) = y -> inverse(f, y)

# ╔═╡ 1b77fada-7b9d-11eb-3266-ebb3895cb76a
straight(x0, y0, x, m) = y0 + m * (x - x0)

# ╔═╡ f25af026-7b9c-11eb-1f11-77a8b06b2d71
function standard_Newton(f, n, x_range, x0, ymin=-10.0, ymax=10.0)

	x0 = Float64(x0)   # keep the iterate type-stable (the slider gives an Int)

	f′ = x -> ForwardDiff.derivative(f, x)

	xs = Float64[]
	ys = Float64[]
	# while-loop instead of `for x in x_range`: StepRangeLen iteration is not
	# wasm-compilable yet (WASM_FINDINGS #7)
	let t = Float64(first(x_range)), hi = Float64(last(x_range)),
		dt = Float64(step(x_range))
		while t <= hi + dt / 2
			push!(xs, t)
			push!(ys, Float64(f(t)))
			t += dt
		end
	end

	fig = Figure(size = (400, 300))
	ax = Axis(fig[1, 1])
	ax.ymin = Float64(ymin)
	ax.ymax = Float64(ymax)

	lines!(ax, xs, ys; linewidth = 3)
	hlines!(ax, [0.0]; color = :magenta, linewidth = 3, linestyle = :dash)
	scatter!(ax, [Float64(x0)], [0.0]; color = :green)

	for i in 1:n

		lines!(ax, [Float64(x0), Float64(x0)], [0.0, Float64(f(x0))];
		       color = (0.5, 0.5, 0.5, 0.5))
		scatter!(ax, [Float64(x0)], [Float64(f(x0))]; color = :red)
		m = f′(x0)

		ts = Float64[]
		for x in xs
			push!(ts, Float64(straight(x0, f(x0), x, m)))
		end
		lines!(ax, xs, ts;
		       color = (0.0, 0.0, 1.0, 0.5), linestyle = :dash, linewidth = 2)

		x1 = x0 - f(x0) / m

		scatter!(ax, [Float64(x1)], [0.0]; color = :green)

		x0 = x1

	end

	fig

end

# ╔═╡ ecb40aea-7b9c-11eb-1476-e54faf32d91c
let
	f(x) = x^2 - 2

	standard_Newton(f, n2, -1:0.01:10, x02, -10, 70)
end

# ╔═╡ ec6c6328-7b9c-11eb-1c69-dba12ae522ad
let
	f(x) = 0.2x^3 - 4x + 1
	
	standard_Newton(f, n, -10:0.01:10, x0, -10, 70)
end

# ╔═╡ 515c23b6-7c2d-11eb-28c9-1b1d92eb4ba0
T(α) = ((x, y),) -> [x + α*y^2, y + α*x^2]

# ╔═╡ 09b97be8-7c2e-11eb-05fd-65bbd097afb8
jacobian(T(p), [a, b]) .|> Text

# ╔═╡ 18ce2fac-7c2e-11eb-03d2-b3a674621662
jacobian(T(p), [a, b]) * [δ, ϵ]

# ╔═╡ 395fd8e2-7c31-11eb-1933-dd719fa0cd22
md"""
α = $(@bind α Slider(0.0:0.01:1.0, show_value=true))
"""

# ╔═╡ 02b1b470-7c31-11eb-28f4-411956f73f12
T(α)( [0.3, 0.4] )

# ╔═╡ 07a754da-7c31-11eb-0394-4bef4d79fc30
inverse(T(α))( [0.3, 0.4] )

# ╔═╡ 5faa2784-7c31-11eb-34f1-3f8224dbdbde
( T(α) ∘ inverse(T(α)) )( [0.3, 0.4] )

# ╔═╡ ee91563e-7c3e-11eb-3f65-1f336073869a
md"""
## Appendix
"""

# ╔═╡ 786f8e78-7c2d-11eb-1bb8-c5cb2e349f45
expand(ex) = simplify(ex, polynorm=true)

# ╔═╡ 98158a38-7c30-11eb-0796-2335e97ec6d0
expand( f(z + η) )

# ╔═╡ e18f2470-7c31-11eb-2b74-d59d00d20ba4
expand( f(z + η) ) - ( f(z) + η*f′(z) )

# ╔═╡ 3828b94c-7c2d-11eb-2e01-79038b0f5226
image = expand.(T(p)( [ (a + δ), (b + ϵ) ] ))

# ╔═╡ ed605b90-7c3e-11eb-34e9-776a05a177dd
image - T(p)([a, b])

# ╔═╡ 35b5c5c6-7c3f-11eb-2723-4b406a809114
simplify.(expand.(image - T(p)([a, b]) - jacobian(T(p), [a, b]) * [δ, ϵ]))

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Symbolics = "0c5d862f-8b57-4792-8d23-62f2024744c7"
WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

[sources]
WasmMakie = {url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"}

[compat]
ForwardDiff = "~1.4.1"
LaTeXStrings = "~1.4.0"
Latexify = "~0.16.10"
PlutoUI = "~0.7.83"
Symbolics = "~7.26.0"
WasmMakie = "~0.1.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "dd30c23d1d739443c0f466cd05833cccc099eb18"

[[deps.ADTypes]]
git-tree-sha1 = "bbc22a9a08a0ef6460041086d8a7b27940ed4ffd"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "1.22.0"

    [deps.ADTypes.extensions]
    ADTypesChainRulesCoreExt = "ChainRulesCore"
    ADTypesConstructionBaseExt = "ConstructionBase"
    ADTypesEnzymeCoreExt = "EnzymeCore"

    [deps.ADTypes.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "2eeb2c9bef11013efc6f8f97f32ee59b146b09fb"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.44"

    [deps.Accessors.extensions]
    AxisKeysExt = "AxisKeys"
    IntervalSetsExt = "IntervalSets"
    LinearAlgebraExt = "LinearAlgebra"
    StaticArraysExt = "StaticArrays"
    StructArraysExt = "StructArrays"
    TestExt = "Test"
    UnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "7715e5b2b186c4d9b664d299d2c9e48b9a778c88"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.6.1"
weakdeps = ["SparseArrays", "StaticArrays"]

    [deps.Adapt.extensions]
    AdaptSparseArraysExt = "SparseArrays"
    AdaptStaticArraysExt = "StaticArrays"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "3d0cabd25fab32390e3bcb82cd67e700aebd9816"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.25.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceAMDGPUExt = "AMDGPU"
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = ["CUDSS", "CUDA"]
    ArrayInterfaceChainRulesCoreExt = "ChainRulesCore"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceMetalExt = "Metal"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.Bijections]]
git-tree-sha1 = "a2d308fcd4c2fb90e943cf9cd2fbfa9c32b69733"
uuid = "e2ed5e7c-b2de-5872-ae92-c73ca462fb04"
version = "0.2.2"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.CommonWorldInvalidations]]
git-tree-sha1 = "ae52d1c52048455e85a387fbee9be553ec2b68d0"
uuid = "f70d9fcc-98c5-4d4a-abd7-e4cdeebd8ca8"
version = "1.0.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.CompositeTypes]]
git-tree-sha1 = "bce26c3dab336582805503bed209faab1c279768"
uuid = "b152e2b5-7a66-4b01-a709-34e65c35f657"
version = "0.1.4"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ConstructionBase]]
git-tree-sha1 = "b4b092499347b18a015186eae3042f72267106cb"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.6.0"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "6fb53a69613a0b2b68a0d12671717d307ab8b24e"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.5"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "79a2aca180a85c690c58a020d47b426954b590f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.16.0"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.DomainSets]]
deps = ["CompositeTypes", "FunctionMaps", "IntervalSets", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "1af39efbaf76fb648432b5efaac0d73af6760407"
uuid = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
version = "0.8.0"

    [deps.DomainSets.extensions]
    DomainSetsMakieExt = "Makie"
    DomainSetsRandomExt = "Random"

    [deps.DomainSets.weakdeps]
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.DynamicPolynomials]]
deps = ["LinearAlgebra", "MultivariatePolynomials", "MutableArithmetics", "Reexport", "StarAlgebras", "Test"]
git-tree-sha1 = "5bfabc3827dfdd164359bad6800c115a81280c00"
uuid = "7c1d4256-1411-5781-91ec-d7bc3513ac07"
version = "0.6.6"

[[deps.EnumX]]
git-tree-sha1 = "c49898e8438c828577f04b92fc9368c388ac783c"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.7"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.ExproniconLite]]
git-tree-sha1 = "c13f0b150373771b0fdc1713c97860f8df12e6c2"
uuid = "55351af7-c7e9-48d6-89ff-24e801d99491"
version = "0.10.14"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "2c5d0b0e12088cde2cf84afb2784415b1ea3dfee"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "1.4.1"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FunctionMaps]]
deps = ["CompositeTypes", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "31bd99a57edf98990d1c21486032963955450e8d"
uuid = "a85aefff-f8ca-4649-a888-c8e5398bc76c"
version = "0.1.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

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

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.IntegerMathUtils]]
git-tree-sha1 = "4c1acff2dc6b6967e7e750633c50bc3b8d83e617"
uuid = "18e54dd8-cb9d-406c-a71d-865a43cbb235"
version = "0.1.3"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.IntervalSets]]
git-tree-sha1 = "79d6bd28c8d9bccc2229784f1bd637689b256377"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.14"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.IrrationalConstants]]
git-tree-sha1 = "b2d91fe939cae05960e760110b328288867b5758"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.6"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.Jieko]]
deps = ["ExproniconLite"]
git-tree-sha1 = "2f05ed29618da60c06a87e9c033982d4f71d0b6c"
uuid = "ae98c720-c025-4a4a-838c-29b094483192"
version = "0.2.1"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c0c9b76f3520863909825cbecdef58cd63de705a"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.5+0"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.Latexify]]
deps = ["Format", "Ghostscript_jll", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "44f93c47f9cd6c7e431f2f2091fcba8f01cd7e8f"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.10"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"
    TectonicExt = "tectonic_jll"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"
    tectonic_jll = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"

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

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "bba2d9aa057d8f126415de240573e86a8f39d2a1"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "1.0.1"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.Moshi]]
deps = ["ExproniconLite", "Jieko"]
git-tree-sha1 = "999dfa2b4f8334c1c23bd307c2b0cb6f97c54591"
uuid = "2e0e35c7-a2e4-4343-998d-7ef72827ed2d"
version = "0.3.8"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.MultivariatePolynomials]]
deps = ["DataStructures", "LinearAlgebra", "MutableArithmetics", "StarAlgebras"]
git-tree-sha1 = "4838893d9b035c2f6967c0d533350e1755b58a70"
uuid = "102ac46a-7ee4-5c85-9060-abc95bfdeaa3"
version = "0.5.19"

    [deps.MultivariatePolynomials.extensions]
    MultivariatePolynomialsChainRulesCoreExt = "ChainRulesCore"

    [deps.MultivariatePolynomials.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "dc5b2c4c111c46bc79ac4405eeb563523b39c004"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.8.0"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "dbd2e8cd2c1c27f0b584f6661b4309609c5a685e"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.4"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.7+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "94ba93778373a53bfd5a0caaf7d809c445292ff4"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.2"

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

[[deps.Primes]]
deps = ["IntegerMathUtils"]
git-tree-sha1 = "25cdd1d20cd005b52fc12cb6be3f75faaf59bb9b"
uuid = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
version = "0.5.7"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.ReadOnlyArrays]]
git-tree-sha1 = "e6f7ddf48cf141cb312b078ca21cb2d29d0dc11d"
uuid = "988b38a3-91fc-5605-94a2-ee2116b3bd83"
version = "0.2.0"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "28154d426e557495aa75097861b18c11f2541ded"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.19"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SciMLPublic]]
git-tree-sha1 = "0ba076dbdce87ba230fff48ca9bca62e1f345c9b"
uuid = "431bcebd-1456-4ced-9d72-93c2757fff0b"
version = "1.0.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "c5391c6ace3bc430ca630251d02ea9687169ca68"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.2"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "7ddb0b49c109481b046972c0e4ab02b2127d6a75"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.6"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.12.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "6547cbdd8ce32efba0d21c5a40fa96d1a3548f9f"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.8.0"

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

    [deps.SpecialFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.StarAlgebras]]
deps = ["LinearAlgebra", "MutableArithmetics", "SparseArrays"]
git-tree-sha1 = "235b1f9d287bbf34083b3d0829343a7942c0ad1c"
uuid = "0c0c59c1-dc5f-42e9-9a8b-b5dc384a6cd1"
version = "0.3.0"

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

[[deps.SymbolicIndexingInterface]]
deps = ["Accessors", "ArrayInterface", "RuntimeGeneratedFunctions", "StaticArraysCore"]
git-tree-sha1 = "64b15330b9e3c91a86bcac92f369c58e382981c6"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.3.48"

    [deps.SymbolicIndexingInterface.extensions]
    SymbolicIndexingInterfacePrettyTablesExt = "PrettyTables"

    [deps.SymbolicIndexingInterface.weakdeps]
    PrettyTables = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"

[[deps.SymbolicLimits]]
deps = ["SymbolicUtils", "TermInterface"]
git-tree-sha1 = "5085671d2cba1eb02136a3d6661c583e801984c1"
uuid = "19f23fe9-fdab-4a78-91af-e7b7767979c3"
version = "1.1.0"

[[deps.SymbolicUtils]]
deps = ["AbstractTrees", "ArrayInterface", "Combinatorics", "ConstructionBase", "DataStructures", "DocStringExtensions", "DynamicPolynomials", "EnumX", "ExproniconLite", "Graphs", "LinearAlgebra", "MacroTools", "Moshi", "MultivariatePolynomials", "MutableArithmetics", "NaNMath", "PrecompileTools", "ReadOnlyArrays", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArraysCore", "SymbolicIndexingInterface", "TaskLocalValues", "TermInterface", "WeakCacheSets"]
git-tree-sha1 = "db2dd7feba95f6d94d52e7a63185449d57f808c5"
uuid = "d1185830-fcd6-423d-90d6-eec64667417b"
version = "4.35.0"

    [deps.SymbolicUtils.extensions]
    SymbolicUtilsChainRulesCoreExt = "ChainRulesCore"
    SymbolicUtilsDistributionsExt = "Distributions"
    SymbolicUtilsLabelledArraysExt = "LabelledArrays"
    SymbolicUtilsReverseDiffExt = "ReverseDiff"

    [deps.SymbolicUtils.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    LabelledArrays = "2ee39098-c373-598a-b85f-a56591580800"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"

[[deps.Symbolics]]
deps = ["ADTypes", "AbstractPlutoDingetjes", "ArrayInterface", "Bijections", "CommonWorldInvalidations", "ConstructionBase", "DataStructures", "DiffRules", "DocStringExtensions", "DomainSets", "DynamicPolynomials", "Libdl", "LinearAlgebra", "LogExpFunctions", "MacroTools", "Markdown", "Moshi", "MultivariatePolynomials", "MutableArithmetics", "NaNMath", "PrecompileTools", "Preferences", "Primes", "RecipesBase", "Reexport", "RuntimeGeneratedFunctions", "SciMLPublic", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArraysCore", "SymbolicIndexingInterface", "SymbolicLimits", "SymbolicUtils", "TermInterface"]
git-tree-sha1 = "a73710e38577a31b32e4d204d362f768bc5badff"
uuid = "0c5d862f-8b57-4792-8d23-62f2024744c7"
version = "7.26.0"

    [deps.Symbolics.extensions]
    SymbolicsD3TreesExt = "D3Trees"
    SymbolicsDistributionsExt = "Distributions"
    SymbolicsForwardDiffExt = "ForwardDiff"
    SymbolicsGroebnerExt = "Groebner"
    SymbolicsHypergeometricFunctionsExt = "HypergeometricFunctions"
    SymbolicsLatexifyExt = ["Latexify", "LaTeXStrings"]
    SymbolicsNemoExt = "Nemo"
    SymbolicsPreallocationToolsExt = ["PreallocationTools", "ForwardDiff"]
    SymbolicsSymPyExt = "SymPy"
    SymbolicsSymPyPythonCallExt = "SymPyPythonCall"

    [deps.Symbolics.weakdeps]
    D3Trees = "e3df1716-f71e-5df9-9e2d-98e193103c45"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Groebner = "0b43b601-686d-58a3-8a1c-6623616c7cd4"
    HypergeometricFunctions = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
    LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
    Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
    Nemo = "2edaba10-b0f1-5616-af89-8c11ac63239a"
    PreallocationTools = "d236fae5-4411-538c-8e31-a6e3d9e00b46"
    SymPy = "24249f21-da20-56a4-8eb1-6a02cf4ae2e6"
    SymPyPythonCall = "bc8888f7-b21e-4b7c-a06a-5d9c9496438c"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TaskLocalValues]]
git-tree-sha1 = "67e469338d9ce74fc578f7db1736a74d93a49eb8"
uuid = "ed4db957-447d-4319-bfb6-7fa9ae7ecf34"
version = "0.1.3"

[[deps.TermInterface]]
git-tree-sha1 = "d673e0aca9e46a2f63720201f55cc7b3e7169b16"
uuid = "8ea1fca8-c5ef-4a55-8b96-4e9afe9c9a3c"
version = "2.0.0"

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
repo-rev = "main"
repo-url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"
uuid = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"
version = "0.1.0"

[[deps.WeakCacheSets]]
git-tree-sha1 = "386050ae4353310d8ff9c228f83b1affca2f7f38"
uuid = "d30d5f5c-d141-4870-aa07-aabb0f5fe7d5"
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
# ╟─dd6b0ae2-cc87-4d19-ac78-f3a990aa692e
# ╠═f4fda666-7b9c-11eb-0304-716c5e710462
# ╟─d82f1eae-7b9c-11eb-24d8-e1dcb2eef71a
# ╟─e410c1d0-7ba1-11eb-394f-71dac89756b7
# ╟─5ea7344c-7ba2-11eb-2cc5-0bbdca218c82
# ╟─8c0c412e-7c2f-11eb-1880-4f6c45d77597
# ╟─ce44554e-847f-4129-8841-1a729dfa7a2e
# ╟─77ef0cfb-60db-4599-bec2-b65e99e5b246
# ╠═ecb40aea-7b9c-11eb-1476-e54faf32d91c
# ╟─2445da24-7b9d-11eb-02bd-eb99a3d95a2e
# ╟─9addbcbe-7b9e-11eb-3e8c-fbab3be40e05
# ╠═ec6c6328-7b9c-11eb-1c69-dba12ae522ad
# ╟─c0b4defe-7c2f-11eb-1913-bdb01d28a4a8
# ╟─615aff3c-7c30-11eb-2ca8-9d2fdf299017
# ╠═71efd6b0-7c30-11eb-0da7-0d4a5ab8f8ff
# ╠═6dc89964-7c30-11eb-0a41-8d97b210ed34
# ╠═d35e0cc8-7c30-11eb-28d3-17c9e221ea62
# ╟─a869e6c6-7c31-11eb-13c8-155d08be02eb
# ╠═63dbf052-7c32-11eb-1062-5b3581d38f70
# ╠═9371f930-7c30-11eb-1f77-c7f31b97ea26
# ╠═98158a38-7c30-11eb-0796-2335e97ec6d0
# ╟─9d778e36-7c30-11eb-1f4b-894af86a8f5d
# ╠═db26375a-7c30-11eb-066e-ab9e8ded3356
# ╠═ea741018-7c30-11eb-3912-a50475e6ec49
# ╠═e18f2470-7c31-11eb-2b74-d59d00d20ba4
# ╟─389e990e-7c40-11eb-37c4-5ba0f59173b3
# ╟─5123c038-7ba2-11eb-1be2-19f789b02c1f
# ╟─9bfafcc0-7ba2-11eb-1b67-e3a3803ead08
# ╟─f153b4b8-7ba0-11eb-37ec-4f1a3dbe20e8
# ╟─9cfa9062-7ba0-11eb-3a93-197ac0287ab4
# ╟─1ba1ae44-7ba1-11eb-21ff-558c95446435
# ╟─ba570c4c-7ba2-11eb-2125-9f23e415a1dc
# ╠═d690f83a-7c2e-11eb-14d7-79a250deb473
# ╠═2fb40dc6-7c2f-11eb-2469-8deb4db59b5c
# ╠═35791bca-7c2f-11eb-1cfb-8d5ebd0208cb
# ╟─1d7dd328-7c2d-11eb-2b35-bdbf5df686f0
# ╟─d44c73b4-7c3e-11eb-1302-8ba9039ae789
# ╟─fe742fec-7c3e-11eb-1f54-55cdf02a1574
# ╠═23536420-7c2d-11eb-20b0-9523f7a5f9d7
# ╠═3828b94c-7c2d-11eb-2e01-79038b0f5226
# ╠═09b97be8-7c2e-11eb-05fd-65bbd097afb8
# ╠═18ce2fac-7c2e-11eb-03d2-b3a674621662
# ╠═ed605b90-7c3e-11eb-34e9-776a05a177dd
# ╠═35b5c5c6-7c3f-11eb-2723-4b406a809114
# ╟─4dd2322c-7ba0-11eb-2b3b-af7c6c1d60a0
# ╟─5c9edb2c-7ba0-11eb-14f6-3d5e52123bc7
# ╟─80917990-7ba0-11eb-029a-dba981c52b58
# ╟─af887dea-7ba1-11eb-3b0d-6925756382a7
# ╟─b7dc4666-7ba1-11eb-32eb-fd3d720c2960
# ╟─c519704c-7ba1-11eb-12da-8b9b176daa0d
# ╟─e1afc6ca-7ba1-11eb-3fb9-ef3a7f82d750
# ╠═1db66b0e-7ba4-11eb-2157-d5a399a73b1f
# ╠═923bde64-7ba4-11eb-21e9-a11993aaab2e
# ╟─61905ae0-7ba6-11eb-0773-17e9aa4e9991
# ╠═ff8b6aec-7ba5-11eb-0d83-19803b1bdda7
# ╠═2e2e5f0e-7c31-11eb-0da7-770b07ee6202
# ╟─1b77fada-7b9d-11eb-3266-ebb3895cb76a
# ╠═f25af026-7b9c-11eb-1f11-77a8b06b2d71
# ╠═515c23b6-7c2d-11eb-28c9-1b1d92eb4ba0
# ╟─395fd8e2-7c31-11eb-1933-dd719fa0cd22
# ╠═02b1b470-7c31-11eb-28f4-411956f73f12
# ╠═07a754da-7c31-11eb-0394-4bef4d79fc30
# ╠═5faa2784-7c31-11eb-34f1-3f8224dbdbde
# ╟─ee91563e-7c3e-11eb-3f65-1f336073869a
# ╠═786f8e78-7c2d-11eb-1bb8-c5cb2e349f45
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
