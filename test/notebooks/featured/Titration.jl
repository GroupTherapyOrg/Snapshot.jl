### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> license_url = "https://github.com/JuliaPluto/featured/blob/main/LICENSES/Unlicense"
#> image = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Vinegar_Titration_-_Color_of_the_Phenolphthalein_reacting_to_NaOH.jpg/960px-Vinegar_Titration_-_Color_of_the_Phenolphthalein_reacting_to_NaOH.jpg"
#> language = "en-US"
#> title = "Simulating titrations"
#> tags = ["chemistry", "plotting", "interactive"]
#> date = "2025-09-17"
#> description = "Learn about acid-base titrations by running a digital titration in your browser. The pH curve is computed and plotted live as WebAssembly — drag the sliders to change the acid strength, concentrations and volume."
#> license = "Unilicense"
#> 
#>     [[frontmatter.author]]
#>     name = "Lucas Hildebrandt"
#>     url = "https://github.com/lucashildebrandt"

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

# ╔═╡ 094598f7-8319-4551-b677-de5729672080
using WasmMakie, PlutoUI

# ╔═╡ 784c8ee4-df28-4bd8-bff7-f3bb2d097b12
md"""
# Simulating Titrations
"""

# ╔═╡ ce9c2c18-5b35-4b05-a3d9-6eb67c7a5529
md"""
In this notebook we use the interactive features of Pluto to understand one of the most common analytical techniques in chemistry: **titrations**. Everything below the sliders is computed and plotted **in your browser as WebAssembly** — no Julia server, no install.

!!! question "Is this for me?"

	This notebook is intended for highschool students, university students studying chemistry or another natural science, or anyone curious. Basic chemistry knowledge is recommended (acids and bases, the pH scale), but short reminders are included. Feel free to give the notebook a try nonetheless.
"""

# ╔═╡ 0f262891-af4b-4007-82f6-7aae20f91dbd
md"""
## The Basics
📚 *The explanations are based on [Titration (Wikipedia)](https://en.wikipedia.org/wiki/Titration), [Acid-base titration (Wikipedia)](https://en.wikipedia.org/wiki/Acid%E2%80%93base_titration) and [Binnewies et al., 2016](https://doi.org/10.1007/978-3-662-45067-3).*
"""

# ╔═╡ ee2a647a-0cba-46c6-afb0-ba16bf0f0150
md"""
Titrations are used to analyse samples and determine unknown concentrations. One of the most common types is the acid-base titration. To find the concentration of an analyte, e.g. an acid like hydrochloric acid (HCl), you use a titrant solution, e.g. a base like sodium hydroxide (NaOH), with a known concentration. The base and acid react in a neutralisation reaction to form water.

```math
\mathrm{H_{3}O^{+}} + \mathrm{OH^{-}} \rightarrow \mathrm{H_{2}O}
```

By measuring how much base is needed to convert the acid completely, the concentration of the acid is determined.

!!! question "Is that always the case?"
	This brief explanation is only valid for very strong acids and bases, which dissociate completely, while weaker acids and bases do not. Only for very strong acids is the concentration of hydronium ions (``\mathrm{H_{3}O^{+}}``) equal to the concentration of acid (``\mathrm{HA}`` in general form).

	```math
	c\mathrm{(H_3O^+)} = c\mathrm{(HA)}
	```

	For weaker acids the chemistry is a bit more complex, which is exactly what the interactive curve below lets you explore.
"""

# ╔═╡ 657f405a-a7f8-4915-ba60-46464a01873f
md"""
### Titration Curves
"""

# ╔═╡ ad925028-59c3-433d-a54a-3f644d11b639
md"""
To see whether the acid is completely converted, the pH value at each point of added base can be measured with a pH electrode. This allows the plotting of a **titration curve**. The inflection point of this curve is the **equivalence point**, where the acid has reacted completely with the added base.

For a **strong** acid (HCl) titrated with a strong base (NaOH), the neutralisation gives a neutral salt solution and the equivalence point sits at pH 7. For a **weak** acid (e.g. acetic acid, ``\mathrm{CH_3COOH}``) the curve is different: it starts at a higher pH, has a flat **buffer region** where ``\mathrm{pH} = \mathrm{p}K_\mathrm{a}`` at the half-equivalence point, and the equivalence point lies above pH 7.
"""

# ╔═╡ 9264917e-724d-4220-bbee-ec026285e475
md"""
Weaker acids do not dissociate completely; instead an equilibrium

```math
\mathrm{HA} + \mathrm{H_2O} \longleftrightarrow \mathrm{A^-} + \mathrm{H_3O^+}
```

is formed, described by the acid constant ``K_{\mathrm{a}}``, usually reported as

```math
\mathrm{p}K\mathrm{_a} = -\log{K_{\mathrm{a}}}.
```

The lower the ``\mathrm{p}K\mathrm{_a}``, the stronger the acid: very strong acids ``\mathrm{p}K\mathrm{_a} < 0``, strong acids ``0 < \mathrm{p}K\mathrm{_a} < 3``, medium-strong acids ``3 < \mathrm{p}K\mathrm{_a} < 7``.
"""

# ╔═╡ 4882a030-f1d6-4b8b-a86f-a20e64fe4a6c
md"""
Here are some monoprotonic acids and their ``\mathrm{p}K\mathrm{_a}`` values. Use them as a guide when setting the ``\mathrm{p}K_\mathrm{a}`` slider below.

| Acid          		 | pKa     |
| ---------------------- |:-------:|
| ``\mathrm{HCl}``       | ``-6``  |
| ``\mathrm{HSO_4^-}``   | ``1.92``|
| ``\mathrm{HNO_{2}}``   | ``3.15``|
| ``\mathrm{HF}``        | ``3.17``|
| ``\mathrm{HCOOH}``     | ``3.75``|
| ``\mathrm{CH_{3}COOH}``| ``4.76``|
"""

# ╔═╡ cd5bcc78-ad78-40c8-9356-140a04ea1a69
md"""
## Interactive Titration Curve
"""

# ╔═╡ 1a229a8e-2378-4aff-871f-69446b9a4dd2
md"""
Drag the sliders to set up your titration. Each slider is independent — change the acid strength (``\mathrm{p}K_\mathrm{a}``), the concentration and volume of the acid you are analysing, and the concentration of the titrant (NaOH). The curve, the current titration point and the equivalence point update live.
"""

# ╔═╡ ce44554e-847f-4129-8841-1a729dfa7a2e
md"""
acid strength pKₐ = $(@bind pKa Slider(-6.0:0.25:6.0, show_value=true, default=4.75))
"""

# ╔═╡ 41536d79-8949-42ea-971c-8069918c455d
md"""
acid concentration c₀(HA) / (mol/L) = $(@bind c0_Acid Slider(0.02:0.02:0.5, show_value=true, default=0.1))
"""

# ╔═╡ 95b20797-e804-4c15-b0d0-7aeb36540234
md"""
acid volume V₀(HA) / mL = $(@bind v0_Acid Slider(5.0:1.0:50.0, show_value=true, default=25.0))
"""

# ╔═╡ 2e016b07-2ac0-4fd0-9c0a-3062616666f3
md"""
titrant concentration c₀(NaOH) / (mol/L) = $(@bind c0_Base Slider(0.02:0.02:0.5, show_value=true, default=0.1))
"""

# ╔═╡ 831198d1-d22c-42b5-a198-3bd34139eb0e
md"""
added volume of titrant V(NaOH) / mL = $(@bind pointX Slider(0.0:0.25:80.0, show_value=true, default=25.0))
"""

# ╔═╡ d67aad9b-1b53-48e1-bb39-82a2ac52b17c
md"""
### The chemistry, as compilable numeric code

`calc_pH` returns the pH of the solution after `v_Base_added` mL of titrant have
been added. It handles three regimes with hand-written analytic formulas — strong
acids dissociate completely, while weak acids follow the acid-constant equilibrium
before the equivalence point and behave as a weak base after it. The autoprotolysis
of water (``10^{-7}``) keeps the pH finite near neutrality.
"""

# ╔═╡ af04638c-2615-4195-a45e-d6d85af6d6cd
"pH after adding `v_Base_added` mL of NaOH to the acid described by the other args."
function calc_pH(v_Base_added::Float64, pKa::Float64, c0_Acid::Float64,
                 v0_Acid::Float64, c0_Base::Float64)
    Ka = 10.0^(-pKa)
    pKb = 14.0 - pKa
    Kb = 10.0^(-pKb)

    if pKa <= 1.74   # very strong / strong acid: dissociates completely
        c_H = 0.0
        if v_Base_added * c0_Base <= v0_Acid * c0_Acid   # up to the equivalence point
            c_H = (c0_Acid * v0_Acid - c0_Base * v_Base_added) / (v0_Acid + v_Base_added) + 1.0e-7
        else                                             # after the equivalence point
            c_OH = (c0_Base * v_Base_added - c0_Acid * v0_Acid) / (v0_Acid + v_Base_added)
            c_H = 1.0e-14 / c_OH
        end
        return -log(10.0, c_H)
    else             # medium-strong / weak acid: acid-constant equilibrium
        # starting concentrations of H3O+ (acid) and OH- (conjugate base at EP)
        c0_H = -Ka / 2.0 + sqrt(Ka * Ka / 4.0 + Ka * c0_Acid)
        c0_OH = -Kb / 2.0 + sqrt(Kb * Kb / 4.0 + Kb * c0_Acid)

        n_acid = (c0_Acid - c0_H) * v0_Acid   # mol of acid still to be neutralised
        n_base = c0_Base * v_Base_added       # mol of base added

        if v_Base_added == 0.0                # at the starting point
            return -log(10.0, c0_H)
        elseif n_acid > n_base                # buffer region, before the EP
            c_H = Ka * (c0_Acid * v0_Acid / (c0_H * v0_Acid + c0_Base * v_Base_added) - 1.0)
            return -log(10.0, c_H)
        else                                  # at / after the EP: weak-base solution
            c_OH = (c0_Base * v_Base_added - n_acid) / (v0_Acid + v_Base_added) + c0_OH
            c_H = 1.0e-14 / c_OH
            return -log(10.0, c_H)
        end
    end
end

# ╔═╡ d690f83a-7c2e-11eb-14d7-79a250deb473
"Volume of titrant (mL) at the equivalence point: n(acid) = n(base added)."
function equivalence_volume(pKa::Float64, c0_Acid::Float64, v0_Acid::Float64, c0_Base::Float64)
    if pKa <= 1.74
        return c0_Acid * v0_Acid / c0_Base
    else
        Ka = 10.0^(-pKa)
        c0_H = -Ka / 2.0 + sqrt(Ka * Ka / 4.0 + Ka * c0_Acid)
        return (c0_Acid - c0_H) * v0_Acid / c0_Base
    end
end

# ╔═╡ 02c0320c-7c56-4fe5-8f8c-9ab0f733b28e
let
    # end of the x-axis: twice the equivalence volume (or the slider reach)
    v_end = max(2.0 * equivalence_volume(pKa, c0_Acid, v0_Acid, c0_Base), 1.0)

    # sample the titration curve into flat Float64 vectors with an explicit loop
    xs = Float64[]
    ys = Float64[]
    steps = 400
    k = 0
    while k <= steps
        v = v_end * k / steps
        push!(xs, v)
        push!(ys, calc_pH(v, pKa, c0_Acid, v0_Acid, c0_Base))
        k += 1
    end

    ev = equivalence_volume(pKa, c0_Acid, v0_Acid, c0_Base)

    fig = Figure(size = (560, 380))
    ax = Axis(fig[1, 1];
        title = "Titration curve against NaOH",
        xlabel = "Added volume of titrant V(NaOH) / mL",
        ylabel = "pH value")
    ax.xmin = 0.0
    ax.xmax = v_end
    ax.ymin = 0.0
    ax.ymax = 14.0

    lines!(ax, xs, ys; linewidth = 2.0, label = "titration curve")
    scatter!(ax, [pointX], [calc_pH(pointX, pKa, c0_Acid, v0_Acid, c0_Base)];
        color = :green, markersize = 12.0, label = "current point")
    scatter!(ax, [ev], [calc_pH(ev, pKa, c0_Acid, v0_Acid, c0_Base)];
        color = :red, markersize = 12.0, label = "equivalence point")
    axislegend(ax; position = :rb)
    fig
end

# ╔═╡ 9dee0462-b5af-4962-a65b-7ac7b2faf3df
md"""### Current titration point"""

# ╔═╡ f153b4b8-7ba0-11eb-37ec-4f1a3dbe20e8
md"""**pH at the current added volume:** $(round(calc_pH(pointX, pKa, c0_Acid, v0_Acid, c0_Base), digits=2))"""

# ╔═╡ f153b4b8-7ba0-11eb-37ec-4f1a3dbe20e9
md"""**Equivalence-point volume of titrant (mL):** $(round(equivalence_volume(pKa, c0_Acid, v0_Acid, c0_Base), digits=2))"""

# ╔═╡ a7e6ac40-51bd-46d7-a21c-ad294fa23d5a
md"""
#### Exercises
"""

# ╔═╡ ab20be4e-d214-4c0e-85df-c293724c978e
md"""
1) Set ``\mathrm{p}K_\mathrm{a} = -6`` (a strong acid like HCl) and add base step by step. Where is the equivalence point, and where does the pH jump?
2) Now set ``\mathrm{p}K_\mathrm{a} = 4.75`` (acetic acid). Notice the higher starting pH, the flat **buffer region**, and that the equivalence point now sits *above* pH 7.
3) Change the acid concentration. What changes in the curve and what stays the same? Keep an eye on the equivalence-point volume.
4) Before you change the acid volume or the titrant concentration, predict how the curve will move — then check.
"""

# ╔═╡ 975a203f-e2d8-4f21-a4af-62212c7a9423
md"""
### Indicators
"""

# ╔═╡ 7f5a2d2a-62fe-4985-b0fb-8559d9124801
md"""
Another way of finding the equivalence point is a **pH indicator** — a compound that changes colour over a characteristic pH range. The jump in pH around the equivalence point is usually large enough that the colour change pinpoints it. A few common indicators and their ranges:

| Indicator         | pH range    |
| ----------------- |:-----------:|
| Methyl orange     | 3.1 – 4.4   |
| Litmus            | 5.0 – 8.0   |
| Bromothymol blue  | 6.0 – 7.6   |
| Phenolphthalein   | 8.3 – 10.0  |
| Alizarin yellow   | 10.1 – 12.0 |

Compare the current pH above with these ranges: which indicator would change colour right at *your* equivalence point?
"""

# ╔═╡ d2fe14b6-59a9-4b9d-9028-3c9f41e91d1c
md"""
## Appendix — Modelling the curve
"""

# ╔═╡ 76baa379-4a48-4268-871e-9e68db92c528
md"""
### Strong acids
"""

# ╔═╡ d2323592-e4eb-4ac1-ab86-741910e1738c
md"""
At the start (no base added) a strong acid dissociates completely, so
``c_0\mathrm{(H_3O^+)} = c_0\mathrm{(HA)}`` and ``\mathrm{pH} = -\log{c_0\mathrm{(H_3O^+)}}``.
While base is added, hydronium ions are consumed one for one, giving (before the equivalence point)

```math
c\mathrm{(H_3O^+)} = \frac{c_0\mathrm{(HA)}\,V_0\mathrm{(HA)} - c_0\mathrm{(NaOH)}\,V_{\text{added}}}{V_0\mathrm{(HA)} + V_{\text{added}}} + 10^{-7}.
```

The ``10^{-7}`` term accounts for the autoprotolysis of water near neutral pH.
After the equivalence point the solution is a diluted base, so we use

```math
c\mathrm{(OH^-)} = \frac{c_0\mathrm{(NaOH)}\,V_{\text{added}} - c_0\mathrm{(HA)}\,V_0\mathrm{(HA)}}{V_0\mathrm{(HA)} + V_{\text{added}}},\qquad
c\mathrm{(H_3O^+)} = \frac{10^{-14}}{c\mathrm{(OH^-)}}.
```
"""

# ╔═╡ 4811fcde-5bfa-4c45-a32f-d39343651c90
md"""
### Medium-strong and weak acids
"""

# ╔═╡ 50437455-4784-43ff-ac9c-5abdb43787fe
md"""
For weak acids the acid constant ``K_\mathrm{a}`` must be considered. At the starting point

```math
c_0\mathrm{(H_3O^+)} = -\frac{K_{\mathrm{a}}}{2} + \sqrt{\frac{K_{\mathrm{a}}^2}{4} + K_{\mathrm{a}}\,c_0\mathrm{(HA)}}.
```

Between the starting point and the equivalence point the solution is a **buffer**, with

```math
c\mathrm{(H_3O^+)} = K_{\mathrm{a}}\left(\frac{c_0\mathrm{(H_3O^+)}\,V_0\mathrm{(HA)}}{c_0\mathrm{(H_3O^+)}\,V_0\mathrm{(HA)} + c_0\mathrm{(NaOH)}\,V_{\text{added}}} - 1\right).
```

At and after the equivalence point the conjugate base ``\mathrm{A^-}`` acts as a weak base, with

```math
c_0\mathrm{(OH^-)} = -\frac{K_{\mathrm{b}}}{2} + \sqrt{\frac{K_{\mathrm{b}}^2}{4} + K_{\mathrm{b}}\,c_0\mathrm{(A^-)}},\qquad K_\mathrm{b} = \frac{10^{-14}}{K_\mathrm{a}},
```

which is added to the excess hydroxide from the added base before converting to ``c\mathrm{(H_3O^+)}``. These are exactly the formulas implemented in `calc_pH` above.
"""

# ╔═╡ cec8f377-dc41-41ba-a3b3-d916acba1147
md"""
## Interested in Contributing?
"""

# ╔═╡ 4336e057-2a02-47d6-8fd9-e9cf9ec29399
md"""
There is still a lot that can be done — here are some ideas:

- Di- and triprotonic acids as options (*Medium*)
- A hidden-concentration exercise: determine the concentration from the curve and check your answer (*Medium*)
- Titrations against weak bases, or of bases against acids (*Medium*)
- Animate an erlenmeyer flask whose colour changes with the indicator (*Hard*)
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
# ╟─784c8ee4-df28-4bd8-bff7-f3bb2d097b12
# ╟─ce9c2c18-5b35-4b05-a3d9-6eb67c7a5529
# ╟─0f262891-af4b-4007-82f6-7aae20f91dbd
# ╟─ee2a647a-0cba-46c6-afb0-ba16bf0f0150
# ╟─657f405a-a7f8-4915-ba60-46464a01873f
# ╟─ad925028-59c3-433d-a54a-3f644d11b639
# ╟─9264917e-724d-4220-bbee-ec026285e475
# ╟─4882a030-f1d6-4b8b-a86f-a20e64fe4a6c
# ╟─cd5bcc78-ad78-40c8-9356-140a04ea1a69
# ╟─1a229a8e-2378-4aff-871f-69446b9a4dd2
# ╟─ce44554e-847f-4129-8841-1a729dfa7a2e
# ╟─41536d79-8949-42ea-971c-8069918c455d
# ╟─95b20797-e804-4c15-b0d0-7aeb36540234
# ╟─2e016b07-2ac0-4fd0-9c0a-3062616666f3
# ╟─831198d1-d22c-42b5-a198-3bd34139eb0e
# ╟─d67aad9b-1b53-48e1-bb39-82a2ac52b17c
# ╠═af04638c-2615-4195-a45e-d6d85af6d6cd
# ╠═d690f83a-7c2e-11eb-14d7-79a250deb473
# ╠═02c0320c-7c56-4fe5-8f8c-9ab0f733b28e
# ╟─9dee0462-b5af-4962-a65b-7ac7b2faf3df
# ╟─f153b4b8-7ba0-11eb-37ec-4f1a3dbe20e8
# ╟─f153b4b8-7ba0-11eb-37ec-4f1a3dbe20e9
# ╟─a7e6ac40-51bd-46d7-a21c-ad294fa23d5a
# ╟─ab20be4e-d214-4c0e-85df-c293724c978e
# ╟─975a203f-e2d8-4f21-a4af-62212c7a9423
# ╟─7f5a2d2a-62fe-4985-b0fb-8559d9124801
# ╟─d2fe14b6-59a9-4b9d-9028-3c9f41e91d1c
# ╟─76baa379-4a48-4268-871e-9e68db92c528
# ╟─d2323592-e4eb-4ac1-ab86-741910e1738c
# ╟─4811fcde-5bfa-4c45-a32f-d39343651c90
# ╟─50437455-4784-43ff-ac9c-5abdb43787fe
# ╟─cec8f377-dc41-41ba-a3b3-d916acba1147
# ╟─4336e057-2a02-47d6-8fd9-e9cf9ec29399
# ╠═094598f7-8319-4551-b677-de5729672080
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
