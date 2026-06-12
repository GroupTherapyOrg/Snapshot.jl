### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> license_url = "https://github.com/JuliaPluto/featured/blob/main/LICENSES/Unlicense"
#> image = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Vinegar_Titration_-_Color_of_the_Phenolphthalein_reacting_to_NaOH.jpg/960px-Vinegar_Titration_-_Color_of_the_Phenolphthalein_reacting_to_NaOH.jpg"
#> language = "en-US"
#> title = "Simulating titrations"
#> tags = ["chemistry", "plotting"]
#> date = "2025-09-17"
#> description = "Learn about titrations and indicators. Deepen your understanding by conducting a digital titration yourself! "
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
using WasmMakie, PlutoUI, DataFrames, LaTeXStrings, ColorSchemes, Colors, Handcalcs, StructuralUnits

# ╔═╡ 784c8ee4-df28-4bd8-bff7-f3bb2d097b12
md"""
# Simulating Titrations
"""

# ╔═╡ ce9c2c18-5b35-4b05-a3d9-6eb67c7a5529
md"""
In this notebook, we want to see how the interactive and reactive features of Pluto can help us understand one of the most common analytical techniques in chemistry: titrations.

!!! question "Is this for me?"
	
	This notebook is intended for highschool students, university students studying chemistry or another natural science, or others who are interested in seeing what this notebook has to offer. Basic chemistry knowledge is recommended (e.g. knowing acids and bases, familiarity with the pH scale), but some short reminders are included. Feel free to give the notebook a try nonetheless.

	For those further interested in how the titration curves were plotted and how the equations were derived, check out the code in combination to the appendix at the end of the notebook.
"""

# ╔═╡ 0f262891-af4b-4007-82f6-7aae20f91dbd
md"""
## The Basics
📚 *The explanations are based on [Titration (Wikipedia)](https://en.wikipedia.org/wiki/Titration), [Acid-base titration (Wikipedia)](https://en.wikipedia.org/wiki/Acid%E2%80%93base_titration) and [Binnewies et al., 2016](https://doi.org/10.1007/978-3-662-45067-3). For further reading, check out the links or take a look at a general chemistry textbook of your choice.*
"""

# ╔═╡ ee2a647a-0cba-46c6-afb0-ba16bf0f0150
md"""
Titrations are used to analyse samples and determine unknown concentrations. One of the most common types of titration is the acid-base titration. To find out the concentration of an analyte, e.g. an acid like hydrochloric acid (HCl), you use a titrant solution, e.g. a base like sodium hydroxide (NaOH), with a known concentration. The base and acid react with each other in a neutralisation reaction to form water.

```math
\mathrm{H_{3}O^{+}} + \mathrm{OH^{-}} \rightarrow \mathrm{H_{2}O}
```

By meassuring how much base is needed to convert the acid completly, the concentration of the acid is determined.

!!! question "Is that always the case?"
	This is a very brief explanation to illustrate the key idea of titrations and in this form it is only valid for very strong acids and bases, which dissociate completly, while weaker acids and bases do not. Therefore, only for very strong acids the concentration of hydronium ions (``\mathrm{H_{3}O^{+}}``) is equal to the concentration of acid (``\mathrm{HA}`` in general form).

	```math
	c\mathrm{(H_3O^+)} = c\mathrm{(HA)}
	```

	For the other cases (weaker acids, di- or triprotonic acids etc.) the chemistry is a bit more complex. We will look at some of these cases later. Of course, the analyte can also be a base, in which case an acid is used as titrant.
"""

# ╔═╡ 83a21840-a772-469e-999d-c066f60e2e0e
md"""
The experiment is done with a so called burette, which can be seen in the picture below. It allows the base to be added in very small steps, most common up to ``0.1~\mathrm{mL}``. 
"""

# ╔═╡ 7705230b-91dc-4851-9e1b-37a642e66657
Resource(
	"https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Acid_and_Base_Titration.jpg/250px-Acid_and_Base_Titration.jpg",
	:alt => "Burette and erlenmeyer flask",
	:width => 200 
)

# ╔═╡ 657f405a-a7f8-4915-ba60-46464a01873f
md"""
### Titration Curves
"""

# ╔═╡ 7c79ba77-e2b6-4e0d-8522-f0b540e6815f
md"""
#### Very Strong Acids
"""

# ╔═╡ ad925028-59c3-433d-a54a-3f644d11b639
md"""
To see if the acid is completly converted, the pH value at each point of added base can be measured with a pH electrode.
This allows the plotting of a titration curve. The inflection point of this curve is the equivalence point. At this stage, the acid has reacted completly with the added base. Because this example is a titration of a strong acid (HCl) and strong base (NaOH), the neutralisation results in a neutral sodium chloride solution (NaCl) and therefore the equivalence point is at pH 7.
"""

# ╔═╡ 8cea32f9-a670-4269-a586-c7bdb339a80d
begin
	begin
		pointX_strong = 25.0
		v_Base_end_ex = 25 * 0.1 / 0.1 * 2
		v_Base_ex::Vector{Float64} = Float64[]
		let t = 0.0
			while t <= v_Base_end_ex + 0.0025
				push!(v_Base_ex, t)
				t += 0.005
			end
		end
	end
	function calc_pH_strong(v_Base_added_ex::Float64) #v as elements of the vector v_Base
		if v_Base_added_ex*0.1 <= 25*0.1
			c_H_ex::Float64 = ((0.1 * 25 - 0.1 * v_Base_added_ex) / (25 + v_Base_added_ex)) + 10^(-7)
		else
			c_OH⁻_ex = (0.1 * v_Base_added_ex - 0.1 * 25) / (25 + v_Base_added_ex)
			c_H_ex = 10^(-14) / c_OH⁻_ex
		end
		pH = -log(10, c_H_ex)
	end
	#########
	pH_total_strong = map(calc_pH_strong, v_Base_ex)
	pH_Value_strong = round(calc_pH_strong(pointX_strong), sigdigits=3)

	fig_strong = Figure(size = (620, 420))
	ax_strong = Axis(fig_strong[1, 1];
		title = "Titration curve of 0.1 M HCl against 0.1 M NaOH",
		xlabel = "Added volume of titrant / [L]",
		ylabel = "pH-Value")
	ax_strong.xmin = -1.0
	ax_strong.xmax = Float64(v_Base_end_ex + 2)
	ax_strong.ymin = 0.0
	ax_strong.ymax = 14.0

	lines!(ax_strong, v_Base_ex, pH_total_strong; linewidth = 2, label = "titration curve")
	scatter!(ax_strong, [pointX_strong], [calc_pH_strong(pointX_strong)]; label = "Equivalence point")
	axislegend(ax_strong; position = :rb)
	fig_strong
end

# ╔═╡ 7205b4a5-d032-43c6-8232-a5d3cffb29d6
md"""
!!! question "Why is the curve shaped like this?"
	The shape of the curve can be explained by the logarithmic nature of the pH scale. The pH value of a solution is defined as the *negative decadic logarithm* of the hydronium-ion concentration

	```math
	\mathrm{pH} = -\log{c\mathrm{(H_3O^+)}}.
	```

	When 90 % of the acid is neutralised, the pH value is changed by one unit. When further 9 % are neutralised and overall 99 % acid is converted, the pH value changes by another unit. Next, only 0.9 % more acid needs to be converted, to change the pH value by another unit. Because of this logarithmic behaviour, the pH value does not change much at the beginning of the titration. As we get closer to the equivalence point, the pH value rises quickly until there is a jump around the equivalence point. Afterwards, the pH level rises because of the added base.
"""

# ╔═╡ d9adecaa-6ae8-46d4-955f-4a89a82a46c9
md"""
#### Strong and Medium-strong Acids
"""

# ╔═╡ 9264917e-724d-4220-bbee-ec026285e475
md"""
Lets take a look at weaker acids like acetic acid (``\mathrm{CH_3COOH}``). As mentioned before, they do not dissociate completly, but an equilibrium

```math
\mathrm{CH_3COOH} + \mathrm{H_2O} \longleftrightarrow \mathrm{CH_3COO^-} + \mathrm{H_3O^+}
```

is formed. As every equilibrium, it can be described by an equilibrium constant ``K``. In the case of an acid, it is called the acid constant ``K_{\mathrm{a}}``. As seen before, while the concentration of hydronium-ions is often represented by the negative decadic logarithm, in the same fashion ``K_{\mathrm{a}}`` is often represented as

```math
\mathrm{p}K\mathrm{_a} = -\log{K_{\mathrm{a}}}.
```

These constants describe the strength of the acids. The lower the ``\mathrm{p}K\mathrm{_a}``, the stronger the acid. The classification of acids is as follows: very strong acids: ``\mathrm{p}K\mathrm{_a} < 0``, strong acids: ``0 < \mathrm{p}K\mathrm{_a} < 3`` and medium-strong acids: ``3 < \mathrm{p}K\mathrm{_a} < 7``.
"""

# ╔═╡ 4882a030-f1d6-4b8b-a86f-a20e64fe4a6c
md"""
Here is a table with some monoprotonic acids and their ``\mathrm{p}K\mathrm{_a}`` values. 

| Acid          		 | pKa     |
| ---------------------- |:-------:| 
| ``\mathrm{HClO_4}``    | ``-10`` |
| ``\mathrm{HCl}``       | ``-6``  |
| ``\mathrm{HSO_4^-}``   | ``1.92``|
| ``\mathrm{HNO_{2}}``   | ``3.15``|
| ``\mathrm{HF}``        | ``3.17``| 
| ``\mathrm{HCOOH}``     | ``3.75``| 
| ``\mathrm{CH_{3}COOH}``| ``4.76``| 
"""

# ╔═╡ 733fe755-796d-41db-883a-cfc8d7d077a4
md"""
Let's compare the titration curve below for acetic acid with the titration curve for hydrochloric acid

!!! info "Differences between titration curves for strong and weak acids"

	1) The pH value at the **start** is higher, although in both cases the starting concentration of the acid is ``c_0\mathrm{(HA)} = 0.1~\mathrm{M}``. Of course, this is the case because the weaker acid does not dissociate completly and forms less hydronium ions with water.

	2) After the curve rises, there is a flat section where the pH value does not change much by adding the base. This is the **buffer region** of the titration. Adding NaOH to the analyte solution leads to the formation of a sodium acetate solution (`` \mathrm{Na^+} + \mathrm{^-OOCCH_3}``), where the acetate anion is the conjugated base to acetic acid. Solutions consisting of a weak acid and its conjugated base are called buffer solutions. Further added acids or bases dont react with water or hydronium ions to further change the pH value, but react with the pair of weak acid and conjugated base first. The pH value in this region is described by the *Henderson-Hasselbalch equation*\
	```math
		\mathrm{pH} = \mathrm{p}K_{\mathrm{a}} + \log{\frac{c(\mathrm{A^-})}{c(\mathrm{HA})}}.
	```
	3) In the middle of the buffer region, there is a point where ``c(\mathrm{A^-}) = c(\mathrm{HA})``. The argument of the logarithm becomes one and therefore the logarithmic term becomes zero. This is the **half equivalence point**, where ``\mathrm{pH} = \mathrm{p}K_{\mathrm{a}}``.

	4) When the **equivalence point** is reached and acetic acid is completly converted to sodium acetate, the resulting solution is slightly basic, because acetate anions act as a weak base. For stronger conjugated bases or solutions of a higher concentration, the pH value at the equivalence point would be higher.

	5) The section after the equivalence point does not differ much from the curve shown before, as in both cases ``\mathrm{NaOH}`` solution was added to a neutralised solution.
"""

# ╔═╡ 6ba1348c-3cca-46a4-b109-bfb90f7ef7f2
begin
	pKa_ex = 4.75
	Ka_ex = 10^(-pKa_ex)
	pKb_ex = 14 - pKa_ex
	Kb_ex = 10^(-pKb_ex)

	c0_H⁺_ex::Float64 = -Ka_ex/2 + sqrt(Ka_ex^2 / 4 + Ka_ex*0.1) #The starting concentration for protons (at the same time for the deprotonated acid)
	c0_OH⁻_ex::Float64 = -Kb_ex/2 + sqrt(Kb_ex^2 / 4 + Kb_ex*0.1) # Concentration of OH⁻ at the equivalence point (EP), after the weak acid is completly neutralised
	function calc_pH_weak(v_Base_added_ex)
		if v_Base_added_ex == 0.0 #at the starting point
			pH = -log(10, c0_H⁺_ex)
		elseif round((0.1 - c0_H⁺_ex)*25, digits=3) > round(0.1*v_Base_added_ex, digits=3) #between starting point and EP
			c_H⁺ = Ka_ex*(0.1*25/(c0_H⁺_ex*25+0.1*v_Base_added_ex) - 1)
			pH = -log(10, c_H⁺)
		elseif round((0.1-c0_H⁺_ex)*25, digits=3) == round(0.1*v_Base_added_ex, digits=3) #at the EP
			pH = 14 - (-log(10, c0_OH⁻_ex))
		elseif round((0.1-c0_H⁺_ex)*25, digits=3) < round(0.1*v_Base_added_ex, digits=3) #after the EP
			c_OH⁻ = (0.1 * v_Base_added_ex - ((0.1-c0_H⁺_ex) * 25)) / (25 + v_Base_added_ex) + c0_OH⁻_ex
			c_H⁺ = 10^(-14) / c_OH⁻
			pH = -log(10, c_H⁺)
		end
	end
	######## Get the equivalence point saved globally
	half_equivalence_volume_ex = 0
	equivalence_volume_ex = 0
	for i in v_Base_ex
		if round(0.1*25/(c0_H⁺_ex*25+0.1*i), digits=3) == 2.000
			global half_equivalence_volume_ex = i
		elseif round((0.1-c0_H⁺_ex)*25, digits=3) == round(0.1*i, digits=3)
			global equivalence_volume_ex = i
		end
	end
	#########
	pH_total_weak = map(calc_pH_weak, v_Base_ex)
	pH_Value_weak = round(calc_pH_weak(equivalence_volume_ex), sigdigits=3)

	fig_weak = Figure(size = (620, 420))
	ax_weak = Axis(fig_weak[1, 1];
		title = "Titration curve of 0.1 M CH₃COOH against 0.1 M NaOH",
		xlabel = "Added volume of titrant / [L]",
		ylabel = "pH-Value")
	ax_weak.xmin = -1.0
	ax_weak.xmax = Float64(v_Base_end_ex + 2)
	ax_weak.ymin = 0.0
	ax_weak.ymax = 14.0

	lines!(ax_weak, v_Base_ex, pH_total_weak; linewidth = 2, label = "titration curve")
	scatter!(ax_weak, [equivalence_volume_ex], [calc_pH_weak(equivalence_volume_ex)]; label = "Equivalence point")
	scatter!(ax_weak, [half_equivalence_volume_ex], [calc_pH_weak(half_equivalence_volume_ex)]; label = "Half equivalence point")
	axislegend(ax_weak; position = :rb)
	fig_weak
end

# ╔═╡ 975a203f-e2d8-4f21-a4af-62212c7a9423
md"""
### Indicators
"""

# ╔═╡ 7f5a2d2a-62fe-4985-b0fb-8559d9124801
md"""
Another way of determining the equivalence point is by using a pH indicator. These are chemical compounds which change colour depending on the pH value of their environement. Every indicator changes colour at a characteristic pH range.
"""

# ╔═╡ ffe30f1b-cde3-4f41-ac69-70f4d2634b3a
begin
	df_color_grad = DataFrame(Dict(
		"Indicator" => [L"\text{Methyl orange}", L"\text{Litmus}", L"\text{Bromothymol blue}", L"\text{Phenolphthalein}", L"\text{Alizarin yellow}"],
		"pH range" => [L"3.1 - 4.4", L"5.0 - 8.0", L"6.0 - 7.6", L"8.3 - 10.0", L"10.1 - 12.0"],
		"Change in color" => [ColorScheme(range(colorant"orange", colorant"red", length=20)), ColorScheme(range(colorant"red", colorant"blue", length=20)), ColorScheme(range(colorant"yellow", colorant"blue", length=20)), ColorScheme(range(colorant"white", colorant"magenta", length=20)), ColorScheme(range(colorant"yellow", colorant"red", length=20))]
	))

	desired_order_grad = ["Indicator", "pH range", "Change in color"]
	df_color_grad = df_color_grad[:, desired_order_grad]
end

# ╔═╡ b3420e1d-413e-463b-9bed-ac6182ce863a
md"""
Indicators themselves are weak organic acids which form conjugated acid-base pairs, where acid and base are of different colors.
As shown before for weak acids, an equilibrium is formed and it shifts when changing the pH value of the environment. 
In the following picture, the acid-base pair for the indicator methyl red can be seen.
"""

# ╔═╡ 512a3218-e9e9-482e-b0b0-59650ea55fd1
Resource(
	"https://i.imgur.com/LxB3LeP.png",
	:alt => "Structure of the corresponding aci-base pair of the indicator methyl red.",
	:width => 700
)

# ╔═╡ 724c61e2-7237-4f3e-ab30-655164288aaf
md"""
To see the color of either the acid or base distinctively, one of them has to be present in tenfold excess.
This is the reason why indicators change their colors inside a range of pH values and not at a single pH value, as this big change in concentrations is necessary.
However, that is not a problem.
As can be seen in the titration curves before, the jump in pH around the equivalence point is usually large enough.
"""

# ╔═╡ cd5bcc78-ad78-40c8-9356-140a04ea1a69
md"""
## Interactive Titration Curve
"""

# ╔═╡ 7c465102-7d68-4827-bd8e-ed8e8ef0e303
md"""
The table with some monoprotonic acids and their ``\mathrm{p}K\mathrm{_a}`` values is shown here again.
"""

# ╔═╡ fa8df29f-be0a-498d-8fac-4cbe016f034a
begin 
	latexacids = [L"\mathrm{HClO_4}",L"\mathrm{HCl}",L"\mathrm{HSO_4^-}",L"\mathrm{HNO_{2}}",L"\mathrm{HF}",L"\mathrm{HCOOH}",L"\mathrm{CH_{3}COOH}"]
	stringacids = ["HClO4","HCl","HSO4-","HNO2","HF","HCOOH","CH3COOH"]
	acidmap = Dict(s => l for (s,l) in zip(stringacids, latexacids))
	df = DataFrame(Dict("Acid" => latexacids, "pKa" => [-10.0,-6.0,1.92,3.15,3.17,3.75,4.76]))
end

# ╔═╡ eb8979e7-b163-435d-a909-f020194ffc15
md"""
Here you can choose from one of the given acids.
"""

# ╔═╡ 563df061-7e97-4745-b101-cf4aa200da60
@bind Acid Select(stringacids)

# ╔═╡ 7cab03c4-048d-4df7-a3a5-b20dfd1e6e9d
md"""
### Control the Added Volume and Check the Indicators
"""

# ╔═╡ f2b5c3e7-29c1-4f7b-82bb-cfa8da90d494
md"""
Here you can track the titration by visualising the point in the titration curve at a given added volume of titrant. The slider can also be controlled with the arrow keys for more precise control, which is most important around the equivalence point.
"""

# ╔═╡ a7e6ac40-51bd-46d7-a21c-ad294fa23d5a
md"""
#### Exercises I
"""

# ╔═╡ ab20be4e-d214-4c0e-85df-c293724c978e
md"""
1) Take a look at the titration of a strong acid (e.g. HCl) against NaOH and add the base step by step with the slider. Which indicators can you use for the titration and which are not suitable? Just like in the lab, at which stages can you add the titrant faster and at which point should you add the base more slowly and carefully?
2) Now take a look at the titration of a weak acid (e.g. acetic acid) against NaOH. Check again, which indicators are usable for this titration. Did it change compared to the titration against a strong acid?
3) Now try the other acids. Are there differences between medium-strong acids or do they behave the same?
"""

# ╔═╡ fa5deb25-ee07-4917-bf57-595bced01394
md"""
### Adjust the Settings
"""

# ╔═╡ 1a229a8e-2378-4aff-871f-69446b9a4dd2
md"""
Here you can experiment with some parameters and how they change the titration curve.
"""

# ╔═╡ 006a4f14-2cd1-439f-8b64-aab99601aba8
md"To plot a titration curve, you need to know the concentration of the acid you are analysing. It is always important to keep the units in mind! Here you can write it down in ``\frac{\text{mol}}{\text{L}}``. Of course in an analytical titration, this is the value you don't know and need to find out."

# ╔═╡ 41536d79-8949-42ea-971c-8069918c455d
@bind c0_Acid_string TextField(default="0.1")

# ╔═╡ 1462be43-386b-4f9a-bae0-304fd058dd93
md"Additionally, you need to know the volume of the solution you are analysing, which you can write down here in ``\text{mL}``."

# ╔═╡ 95b20797-e804-4c15-b0d0-7aeb36540234
@bind v0_Acid_string TextField(default="25") # in mL

# ╔═╡ 5b088b11-f0af-461a-bc92-61fbfed0e768
md"""
Next, you need to know the concentration of your titrant, in this example the base, also in ``\frac{\text{mol}}{\text{L}}``.
"""

# ╔═╡ 2e016b07-2ac0-4fd0-9c0a-3062616666f3
@bind c0_Base_string TextField(default="0.1")

# ╔═╡ 8af4355b-b5cf-4017-a660-0b0ca884ad95
md"""
#### Exercises II
"""

# ╔═╡ 38c319e0-0124-41fa-9910-173e645e7d03
md"""
1) Change the concentration of the analyte. What changes in the curve and what stays the same? Can you see any proportionality ("If I double the concentration, [...] is doubled / halved")?
"""

# ╔═╡ 3b77b70e-be0b-46a7-948d-7289fcc72924
details("Hint",
md"""
Keep an eye out for the scaling on the x-axis!!
"""
)

# ╔═╡ 05063b3d-8769-4d54-ad70-f38e95dca7a3
md"""
2) Before you change the volume of the analyte, try to predict how the curve changes. Now change the volume and check the curve again. Look out for proportionalities!
"""

# ╔═╡ 38ba4eb9-4cd1-41d1-8b14-e07b3c76be3b
md"""
3) Finally, let's take a look at the concentration of the titrant. Try to make a prediction, how it affects the curve and check it afterwards in the same way as before.
"""

# ╔═╡ d2fe14b6-59a9-4b9d-9028-3c9f41e91d1c
md"""
## Appendix
"""

# ╔═╡ 76baa379-4a48-4268-871e-9e68db92c528
md"""
### Modelling the Titration Curve for Strong Acids
"""

# ╔═╡ d2323592-e4eb-4ac1-ab86-741910e1738c
md"""
At the beginning (no Base added), the acid dissociates completly and the concentration of hydronium ions is 
```math
	c_0\mathrm{(H_3O^+)} = c_0\mathrm{(HA)}
```
and therefore the pH value is 
```math
	\mathrm{pH} = -\log{c_0\mathrm{(H_3O^+)}}.
```
The concentration is given in the unit ``\mathrm{\frac{mol}{L}}``.
"""

# ╔═╡ 241fc16e-d252-4ef8-8e6d-267fc327ee88
details("Unit of the logarithms argument",
md"""
The argument of a logarithm needs to be a dimensionless quantitiy. When using concentrations, the exact description would be
```math
	\mathrm{pH} = -\log{\frac{c_0\mathrm{(H_3O^+)}}{c^0}}.
```
To be even more precise, the **activity** of ``\mathrm{H_3O^+}`` should be used. 
```math
	\mathrm{pH} = -\log{a\mathrm{(H_3O^+)}}.
```	

It is a dimensionless quantity, somtetimes called "effective concentration" and considers intermolecular interactions of ions in solution. For further information, click [here](https://en.wikipedia.org/wiki/Thermodynamic_activity) or look into a general chemistry textbook.
"""
)

# ╔═╡ c1799961-2ae2-4fb0-8934-55fc2a16cc7e
md"""
As we only consider a strong base (NaOH), we can also define
```math
	c_0\mathrm{(OH^-)} = c_0\mathrm{(NaOH)}.
```
While base is added, we need to consider how much hydronium ions are converted.
The easiest way is to consider the amount of substance 
```math
	n\mathrm{(H_3O^+)} = c\mathrm{(H_3O^+)} * V_{\mathrm{total}}
```
in the unit ``\text{mol}``. The amount of substance of the added ``\mathrm{OH^-}`` can at any point be written as
```math
	n\mathrm{(OH^-)} = c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)}.
```

Because the hydronium ions are directly converted, the amount of substance between starting point and equivalence point can be written as

```math
\begin{align}
n\mathrm{(H_3O^+)} &= n_0\mathrm{(H_3O^+)} - n_{\text{added}}\mathrm{(NaOH)} \\
	&= c_0\mathrm{(H_3O^+)} * V_0{\mathrm{(HA)}} - c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)}.
\end{align}
``` 
To convert the amount of substance into a concentration c``\mathrm{(H_3O^+)}`` to calculate the pH at any given point between starting point and equivalence point, it needs to be divided by the total volume
```math
	V_{\mathrm{total}} = V_0{\mathrm{(HA)}} + V_{\text{added}}\mathrm{(NaOH)},
```
resulting in the expression
```math
c\mathrm{(H_3O^+)} = \frac{c_0\mathrm{(H_3O^+)} * V_0{\mathrm{(HA)}} - c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)}}{V_0{\mathrm{(HA)}} + V_{\text{added}}\mathrm{(NaOH)}}.
``` 
The only thing left to consider is the autoprotolysis of water, which can be neglected at high concentrations of ``\mathrm{H_3O^+}``, but needs to be considered for lower concentrations starting at roughly ``10^{-5}~\mathrm{\frac{mol}{L}}``. Although it is not correct, as an approximation it works to add ``10^{-7}~\mathrm{\frac{mol}{L}}`` to the expression above to account for ``c\mathrm{(H_3O^+)}`` at a neutral pH, as for higher concentrations the presence of this term is easily neglectable.

Finally, we arrive at the expression used in the function for
```math
c\mathrm{(H_3O^+)} = \frac{c_0\mathrm{(H_3O^+)} * V_0{\mathrm{(HA)}} - c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)}}{V_0{\mathrm{(HA)}} + V_{\text{added}}\mathrm{(NaOH)}} + 10^{-7}~\mathrm{\frac{mol}{L}}.
``` 
between the starting point and equivalence point.

"""

# ╔═╡ 874bdbe5-d512-4566-9780-b78f141a8ba0
md"""
After the equivalence point, we are looking at a neutral solution and further adding the base leads to a diluted basic solution. Therefore, it is easier to talk about he concentration of ``\mathrm{OH^-}`` and convert it to ``c\mathrm{(H_3O^+)}`` afterwards by using the autoprotolysis of water
```math
	K_{\mathrm{w}} = 10^{-14} = c\mathrm{(H_3O^+)} * c\mathrm{(OH^-)}.
```
The concentration of ``\mathrm{OH^-}`` after the equivalence point can be written as
```math
	c\mathrm{(OH^-)} = \frac{c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)} - c_0\mathrm{(H_3O^+)} * V_0{\mathrm{(HA)}}}{V_0{\mathrm{(HA)}} + V_{\text{added}}\mathrm{(NaOH)}}
```
and converted to
```math
	c\mathrm{(H_3O^+)} = \frac{10^{-14}~\mathrm{\frac{mol^2}{L^2}}}{c\mathrm{(OH^-)}}.
```
Alternatively, the pOH value can be calculated in the same way as pH values are calculated. The pOH can be transformed into the pH value with
```math
\mathrm{pOH} = 14 - \mathrm{pH},
```
based on the autoprotolysis of water.
"""

# ╔═╡ 4811fcde-5bfa-4c45-a32f-d39343651c90
md"""
### Modelling the Titration Curve for Medium-strong and Weak Acids
"""

# ╔═╡ 587040b9-c31a-4900-8b5d-26bf7000c570
md"""
#### At the Starting Point
"""

# ╔═╡ c780180d-4ca9-464c-9d14-74f9ce5c4501
md"""
When no Base was added.
"""

# ╔═╡ 70ccb345-b0bc-456f-bda8-79a501059e6a
md"""
##### Expression for ``c\mathrm{(H_3O^+)}``
"""

# ╔═╡ 50437455-4784-43ff-ac9c-5abdb43787fe
md"""
The concentration of hydronium ions of medium-strong and weak acids is given as
```math
c_0\mathrm{(H_3O^+)} = -\frac{K_{\mathrm{a}}}{2} + \sqrt{\frac{K_{\mathrm{a}}^2}{4} + K_{\mathrm{a}} * c_0{\mathrm{(HA)}}}.
``` 
Now the acid constant needs to be considered because of the equilibrium
```math
\mathrm{HA} + \mathrm{H_2O} \longleftrightarrow \mathrm{A^-} + \mathrm{H_3O^+}
```
and the incomplete dissociation of the acid.
"""

# ╔═╡ ba25c716-b754-4887-b3b9-b85dba0f90d2
md"""
#### Between Starting Point and Equivalence Point
"""

# ╔═╡ 8bc4224f-0142-448c-be95-98cbb160071c
md"""
While 
```math
\begin{align}
n_0\mathrm{(HA)} &> n_{\mathrm{added}}\mathrm{(OH^-)} \\
(c_0\mathrm{(HA)} - c_0\mathrm{(H_3O^+)}) * V_0\mathrm{(HA)} &> c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)}
\end{align}
```
"""

# ╔═╡ fb20a23a-4102-4ee3-a73f-64c2640b0adb
md"""
##### Expression for ``c\mathrm{(H_3O^+)}``
"""

# ╔═╡ a27a4577-151d-45c0-9675-288076d2da59
md"""
With the definition of ``K_{\mathrm{a}}`` out of the law of mass action
```math
K_{\mathrm{a}} = \frac{c\mathrm{(A^-)} * c\mathrm{(H_3O^+)}}{c\mathrm{(HA)}},
```
we get for the concentration of hydronium ions
```math
c\mathrm{(H_3O^+)} = K_{\mathrm{a}} * \frac{c\mathrm{(HA)}}{c\mathrm{(A^-)}}.
```
The concentration of acid at any given point can also be written as ``c\mathrm{(HA)} = c_0\mathrm{(HA)} - c\mathrm{(A^-)}``, thus
```math
\begin{align}
c\mathrm{(H_3O^+)} &= K_{\mathrm{a}} * \frac{c_0\mathrm{(HA)} - c\mathrm{(A^-)}}{c\mathrm{(A^-)}} \\
&= K_{\mathrm{a}} * \left(\frac{c_0\mathrm{(HA)}}{c\mathrm{(A^-)}} - 1\right).
\end{align}
```
As only the ratio of concentrations is important here, it can easily be converted to a molar ratio
```math
\frac{c_0\mathrm{(H_3O^+)}}{c\mathrm{(A^-)}} = \frac{\frac{n_0\mathrm{(H_3O^+)}}{V_{\mathrm{total}}}}{\frac{n\mathrm{(A^-)}}{V_{\mathrm{total}}}} = \frac{n_0\mathrm{(H_3O^+)}}{n\mathrm{(A^-)}}
```
and the expression above turns to
```math
c\mathrm{(H_3O^+)} = K_{\mathrm{a}} * \left(\frac{n_0\mathrm{(HA)}}{n\mathrm{(A^-)}} - 1\right).
```
The amount of substance of acid at the starting point can easily be expressed by
```math
n_0\mathrm{(HA)} = c_0\mathrm{(HA)} * V_0\mathrm{(HA)}.
```
"""

# ╔═╡ 631559da-b114-4932-a031-c555ac56b3bf
md"""
##### Expression for ``n\mathrm{(A^-)}``
"""

# ╔═╡ 3f7feb3d-99db-4b5e-a7e5-4f26c9c5ae68
md"""
As for the deprotonated acid ``\mathrm{A^-}``, we need to consider the amount of substance at the beginning ``n_0\mathrm{(A^-)}`` caused by the equilibrium shown above and additionally the amount of substance formed by the deprotonation of acid ``n_{\mathrm{d}}\mathrm{(A^-)}`` with the added base
```math
\mathrm{HA} + \mathrm{NaOH} \longleftrightarrow \mathrm{Na^+} + \mathrm{A^-} + \mathrm{H_2O}.
```
Consequently, we can write
```math
n\mathrm{(A^-)} = n_0\mathrm{(A^-)} + n_{\mathrm{d}}\mathrm{(A^-)}.
```
"""

# ╔═╡ 975f4b7b-d6a4-4d72-96cc-90832ef22db4
md"""
Note, that when ``\mathrm{HA}`` reacts with water at the beginning, it forms ``\mathrm{A^-}`` and ``\mathrm{H_3O^+}`` with the same amount
```math
n_0\mathrm{(A^-)} = n_0\mathrm{(H_3O^+)}
```
and can be written as
```math
n_0\mathrm{(A^-)} = c_0\mathrm{(H_3O^+)} * V_0\mathrm{(HA)}
```
with the expression for ``c_0\mathrm{(H_3O^+)}`` from the starting point.
"""

# ╔═╡ 8818efcf-704c-41c2-b0b4-b9da3ce53205
md"""
When ``\mathrm{HA}`` reacts with ``\mathrm{NaOH}``, the base is completly converted to ``\mathrm{H_2O}`` and ``\mathrm{Ac^-}``. Therefore, ``n_{\mathrm{d}}\mathrm{(A^-)}`` can be written as
```math
n_{\mathrm{d}}\mathrm{(A^-)} = c_0\mathrm{(NaOH)} * V_{\mathrm{added}}\mathrm{(NaOH)}.
```
In summary, the amount of substance of deprotonated acid at any given point is
```math
n\mathrm{(A^-)} = c_0\mathrm{(H_3O^+)} * V_0\mathrm{(HA)} + c_0\mathrm{(NaOH)} * V_{\mathrm{added}}\mathrm{(NaOH)}
```
and thus, the concentration of hydronium ions between the starting point and equivalence point is
```math
c\mathrm{(H_3O^+)} = K_{\mathrm{a}} * \left(\frac{c_0\mathrm{(H_3O^+)} * V_0\mathrm{(HA)}}{c_0\mathrm{(H_3O^+)} * V_0\mathrm{(HA)} + c_0\mathrm{(NaOH)} * V_{\mathrm{added}}\mathrm{(NaOH)}} - 1\right).
```
"""

# ╔═╡ adc9907a-a224-4400-99e8-5fb6e385adfc
md"""
#### At the Equivalence Point
"""

# ╔═╡ 5834c3bb-be94-4103-817c-4102bad491cf
md"""
When
```math
\begin{align}
n_0\mathrm{(HA)} &= n_{\mathrm{added}}\mathrm{(OH^-)} \\
(c_0\mathrm{(HA)} - c_0\mathrm{(H_3O^+)}) * V_0\mathrm{(HA)} &= c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)}
\end{align}
```
"""

# ╔═╡ 8435c139-ec9b-4ab1-82fc-4f0a20073f81
md"""
##### Expression for ``c\mathrm{(H_3O^+)}``
"""

# ╔═╡ 7e8946ca-8168-4b3a-851b-1e4458c6be77
md"""
At the equivalence point, the salt of the medium-strong or weak acid remains, which is itself a medium-strong or weak base. Therefore, the concentration of hydroxy ions can be calculated with
```math
c_0\mathrm{(OH^-)} = -\frac{K_{\mathrm{b}}}{2} + \sqrt{\frac{K_{\mathrm{b}}^2}{4} + K_{\mathrm{b}} * c_0{\mathrm{(A^-)}}},
``` 
from which then the pOH and thus the pH value can be calculated or it can first be converted to the concentration of hydronium ions as can be seen in the case of strong acids.
"""

# ╔═╡ 5e2cdf07-4cf4-4347-a10d-58322aee46eb
md"""
#### After the Equivalence Point
"""

# ╔═╡ eabac306-fca3-42d4-add8-29c053e5f97d
md"""
When
```math
\begin{align}
n_0\mathrm{(HA)} &< n_{\mathrm{added}}\mathrm{(OH^-)} \\
(c_0\mathrm{(HA)} - c_0\mathrm{(H_3O^+)}) * V_0\mathrm{(HA)} &< c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)}
\end{align}
```
"""

# ╔═╡ ab27ac5f-8e35-4c90-bbc5-e60bf699281d
md"""
##### Expression for ``c\mathrm{(OH^-)}``
"""

# ╔═╡ c44d318d-a710-4adb-acac-fd7f0f53cec3
md"""
This is almost the same as for strong acids with some minor differences. Firstly, the amount of substance of ``\mathrm{OH^-}`` from the added base is calculated slightly differently with
```math
\begin{align}
	c_{\mathrm{A}}\mathrm{(OH^-)} &= \frac{n_{\mathrm{added}}\mathrm{(OH^-)} - n_0\mathrm{(HA)}}{V_{\mathrm{total}}} \\
	&= \frac{c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)} - (c_0\mathrm{(HA)} - c_0\mathrm{(H_3O^+)}) * V_0\mathrm{(HA)}}{V_0\mathrm{(HA)} + V_{\text{added}}\mathrm{(NaOH)}}
\end{align}
```
"""

# ╔═╡ 4b5214a5-e35f-431a-9f3e-63eff56d1f45
md"""
Secondly, the concentration of hydroxide from the weak base present at the equivalence point needs to be additionally considered.
```math
c_{\mathrm{B}}\mathrm{(OH^-)} = -\frac{K_{\mathrm{b}}}{2} + \sqrt{\frac{K_{\mathrm{b}}^2}{4} + K_{\mathrm{b}} * c_0{\mathrm{(A^-)}}}
```
In total, we get the expression
```math
\begin{align}
c\mathrm{(OH^-)} =& c_{\mathrm{A}}\mathrm{(OH^-)} + c_{\mathrm{B}}\mathrm{(OH^-)} \\
	=&  \frac{c_0\mathrm{(NaOH)} * V_{\text{added}}\mathrm{(NaOH)} - (c_0\mathrm{(HA)} - c_0\mathrm{(H_3O^+)}) * V_0\mathrm{(HA)}}{V_0\mathrm{(HA)} + V_{\text{added}}\mathrm{(NaOH)}} \\
	&-\frac{K_{\mathrm{b}}}{2} + \sqrt{\frac{K_{\mathrm{b}}^2}{4} + K_{\mathrm{b}} * c_0{\mathrm{(A^-)}}}
\end{align}
```
"""

# ╔═╡ 435fb7e5-4afd-4c37-b21a-9dd1935c4fe2
md"""
## Code
"""

# ╔═╡ 1a9060ae-f257-4892-881a-09c7e7b71747
md"""
### Packages & Table of Contents
"""

# ╔═╡ ffc3c232-12c1-408a-af0a-25fadb418a21
PlutoUI.TableOfContents(include_definitions=true)

# ╔═╡ d67aad9b-1b53-48e1-bb39-82a2ac52b17c
md"""
### Defining Variables and Functions
"""

# ╔═╡ 50caa04e-880d-4224-90b4-0a8d9004576b
md"""
#### Titration Curve
"""

# ╔═╡ 41bed3bd-75f9-4b1a-9ea8-786b338b7503
#Defining constants and parameters (Acid and Base constants, concentrations and volumes)
begin
	pKa = filter(row -> row."Acid" == acidmap[Acid], df)."pKa"[1]
	Ka = 10^(-pKa)
	pKb = 14 - pKa
	Kb = 10^(-pKb)
	c0_Acid = parse(Float64, c0_Acid_string)
	v0_Acid = parse(Float64, v0_Acid_string)
	c0_Base = parse(Float64, c0_Base_string)
	v_Base_end = v0_Acid * c0_Acid / c0_Base * 2
	v_Base::Vector{Float64} = Float64[]
	let t = 0.0
		while t <= v_Base_end + 0.0025
			push!(v_Base, t)
			t += 0.005
		end
	end
	if pKa <= 0 #Very strong acids
		c0_H⁺ = Float64(c0_Acid*v0_Acid)
		c0_OH⁻ = Float64(10^(-7))
	else #Medium-strong and weak acid
		c0_H⁺ = -Ka/2 + sqrt(Ka^2 / 4 + Ka*c0_Acid) #The starting concentration for protons (at the same time for the deprotonated acid)
		c0_OH⁻ = -Kb/2 + sqrt(Kb^2 / 4 + Kb*c0_Acid) # Concentration of OH⁻ at the EP, after the weak acid is completly neutralised
	end
end; nothing

# ╔═╡ 831198d1-d22c-42b5-a198-3bd34139eb0e
@bind pointX Slider(0.0:0.05:v_Base_end)

# ╔═╡ af04638c-2615-4195-a45e-d6d85af6d6cd
# define Functions
begin
	function calc_pH(v_Base_added::Float64)#v as the elements of the vector v_Base
		if pKa <= 1.74 #for very strong acids
			if v_Base_added*c0_Base <= v0_Acid*c0_Acid #until the equivalence point (EP) is reached
				c_H⁺::Float64 = ((c0_Acid * v0_Acid - c0_Base * v_Base_added) / (v0_Acid + v_Base_added)) + 10^(-7)
			else #after the EP
				c_OH⁻::Float64 = (c0_Base * v_Base_added - c0_Acid * v0_Acid) / (v0_Acid + v_Base_added)
				c_H⁺ = 10^(-14) / c_OH⁻
			end
			pH = -log(10, c_H⁺)
		else #for medium-strong and weak acids
			if v_Base_added == 0.0 #at the starting point
				pH = -log(10, c0_H⁺)
			elseif round((c0_Acid - c0_H⁺)*v0_Acid, digits=3) > round(c0_Base*v_Base_added, digits=3) #between starting point and EP
				c_H⁺ = Ka*(c0_Acid*v0_Acid/(c0_H⁺*v0_Acid+c0_Base*v_Base_added) - 1)
				pH = -log(10, c_H⁺)
			elseif round((c0_Acid-c0_H⁺)*v0_Acid, digits=3) == round(c0_Base*v_Base_added, digits=3) #at the EP
				pH = 14 - (-log(10, c0_OH⁻))
			elseif round((c0_Acid-c0_H⁺)*v0_Acid, digits=3) < round(c0_Base*v_Base_added, digits=3) #after the EP
				c_OH⁻ = (c0_Base * v_Base_added - ((c0_Acid-c0_H⁺) * v0_Acid)) / (v0_Acid + v_Base_added) + c0_OH⁻
				c_H⁺ = 10^(-14) / c_OH⁻
				pH = -log(10, c_H⁺)
			end
		end
	end
end ; nothing

# ╔═╡ 02c0320c-7c56-4fe5-8f8c-9ab0f733b28e
begin
	if pKa < 7.0
		pH_total = map(calc_pH, v_Base)

		pH_Value = round(calc_pH(pointX), sigdigits=3)

		fig_titr = Figure(size = (620, 420))
		ax_titr = Axis(fig_titr[1, 1];
			title = "Titration curve of " * c0_Acid_string * " M " * Acid * " against " * c0_Base_string * " M NaOH",
			xlabel = "Added volume of titrant / [mL]",
			ylabel = "pH-Value")
		ax_titr.xmin = -1.0
		ax_titr.xmax = Float64(v_Base_end + 2)
		ax_titr.ymin = 0.0
		ax_titr.ymax = 14.0

		lines!(ax_titr, v_Base, pH_total; linewidth = 2, label = "titration curve")
		scatter!(ax_titr, [Float64(pointX)], [Float64(calc_pH(pointX))]; label = "Current point of titration")

		if pKa <= 1.74
			let ev = 0.0
				for i in v_Base
					if i*c0_Base == v0_Acid*c0_Acid
						ev = i
					end
				end
				scatter!(ax_titr, [ev], [calc_pH(ev)]; label = "Equivalence point")
			end
		else
			let hev = 0.0, ev = 0.0
				for i in v_Base
					if round(c0_Acid*v0_Acid/(c0_H⁺*v0_Acid+c0_Base*i), digits=3) == 2.000
						hev = i
					elseif round((c0_Acid-c0_H⁺)*v0_Acid, digits=3) == round(c0_Base*i, digits=3)
						ev = i
					end
				end
				scatter!(ax_titr, [ev], [calc_pH(ev)]; label = "Equivalence point")
				scatter!(ax_titr, [hev], [calc_pH(hev)]; label = "Half equivalence point")
			end
		end
		axislegend(ax_titr; position = :rb)
		fig_titr
	else
		println("The given pKa-value does not match a strong or weak acid.")
	end
end

# ╔═╡ 9dee0462-b5af-4962-a65b-7ac7b2faf3df
println("At this point, $pointX millilitre of titrant were added. The pH Value of the \nsolution is $pH_Value.")

# ╔═╡ 8b9e6746-b731-4b39-a0b8-4b9e4c752cc6
md"""
#### Indicators
"""

# ╔═╡ 4127a0c7-897b-41c2-9319-2b1c48369699
begin
	begin #The indicators with their pH range and their colors
		Methyl_orange = ColorScheme(range(colorant"red", colorant"yellow", length=130));
		Litmus = ColorScheme(range(colorant"red", colorant"blue", length=300));
		Bromothymol_blue = ColorScheme(range(colorant"yellow", colorant"blue", length=160)); 
		Phenolphthalein = ColorScheme(range(colorant"white", colorant"magenta", length=180));
		Alizarin_yellow = ColorScheme(range(colorant"yellow", colorant"red", length=190)); nothing
	end
	# Indexing Methyl Orange
	if pH_Value < 3.10
		a::Int64 = 1
	elseif 3.10 <= pH_Value < 4.40
		a::Int64 = Int64(round(100*pH_Value - 309))
	elseif pH_Value >= 4.40
		a::Int64 = size(Methyl_orange)
	end
	# Indexing Litmus
	if pH_Value < 5.00
		b::Int64 = 1
	elseif 5.00 <= pH_Value < 8.00
		b::Int64 = Int64(round(100*pH_Value - 499))
	elseif pH_Value >= 8.00
		b::Int64 = size(Litmus)
	end
	# Indexing Bromothymol Blue
	if pH_Value < 6.00
		c::Int64 = 1
	elseif 6.00 <= pH_Value < 7.60
		c::Int64 = Int64(round(100*pH_Value - 599))
	elseif pH_Value >= 7.60
		c::Int64 = size(Bromothymol_blue)
	end
	# Indexing Phenolphthalein
	if pH_Value < 8.30
		d::Int64 = 1
	elseif 8.30 <= pH_Value < 10.00
		d::Int64 = Int64(round(100*pH_Value - 829))
	elseif pH_Value >= 10.00
		d::Int64 = size(Phenolphthalein)
	end
	# Indexing Alizarin yellow
	if pH_Value < 10.10
		e::Int64 = 1
	elseif 10.10 <= pH_Value < 12.00
		e::Int64 = Int64(round(100*pH_Value - 1009))
	elseif pH_Value >= 12.00
		e::Int64 = size(Alizarin_yellow)
	end
end; nothing

# ╔═╡ 6ebfa6d8-b4a7-4d5e-8d3d-ccf0ba596f25
# Output of the Indicator color in a Dataframe
begin
	df_color = DataFrame(Dict(
		"Methyl orange" => [Methyl_orange[a]],
		"Litmus" => [Litmus[b]],
		"Bromothymol blue" => [Bromothymol_blue[c]],
		"Phenolphthalein" => [Phenolphthalein[d]],
		"Alizarin yellow" => [Alizarin_yellow[e]]
							))
	desired_order = ["Methyl orange", "Litmus", "Bromothymol blue", "Phenolphthalein", "Alizarin yellow"]
	df_color = df_color[:, desired_order]
end

# ╔═╡ c59b620d-a6dd-4e19-ac30-5840568efba4
md"""
##### Alternative
"""

# ╔═╡ 67136d72-c447-4268-8c17-b6d9ad3652ca
md"""
Constructing a function and using the existing clamp function, instead of constructing multiple if/else blocks.
"""

# ╔═╡ ab1430fd-ddd9-48d6-94e8-465cea45ff25
begin
	struct IndicatorRange #Define structure which can be applied to every single indicator with color at beginning / end and the pH range
		mincolor
		maxcolor
		minph
		maxph
	end

	
	function getcolorant(range::IndicatorRange, ph) #Using the structure, define function to return the right color at given pH
		factor = (ph - range.minph) / (range.maxph - range.minph) #Inside pH range: gives factor between 0 and 1


		factor = clamp(factor, 0, 1) #clamps the factor between 0 and 1, shorter than the if/else block for every indicator above
		
		range.maxcolor * factor + range.mincolor * (1 - factor) #mixes the color according to the factor depending on pH value
	end

	range_Methyl_orange = IndicatorRange(colorant"red", colorant"yellow",3.1,4.4)
	range_Litmus = IndicatorRange(colorant"red", colorant"blue",5.0,8.0)
	range_Bromothymol_blue = IndicatorRange(colorant"yellow", colorant"blue",6.0,7.6)
	range_Phenolphtalein = IndicatorRange(colorant"white", colorant"magenta",8.3,10.0)
	range_Alizarin_yellow = IndicatorRange(colorant"yellow", colorant"red",10.1,12.0)

end

# ╔═╡ 2ffcfcc2-ac5f-4293-bab0-3fede68c115a
begin
	df_color_alt = DataFrame(Dict(
		"Methyl orange" => [getcolorant(range_Methyl_orange, pH_Value)],
		"Litmus" => [getcolorant(range_Litmus, pH_Value)],
		"Bromothymol blue" => [getcolorant(range_Bromothymol_blue, pH_Value)],
		"Phenolphthalein" => [getcolorant(range_Phenolphtalein, pH_Value)],
		"Alizarin yellow" => [getcolorant(range_Alizarin_yellow, pH_Value)]
							))
	df_color_alt = df_color_alt[:, desired_order]
end

# ╔═╡ cec8f377-dc41-41ba-a3b3-d916acba1147
md"""
## Interested in Contributing?
"""

# ╔═╡ 4336e057-2a02-47d6-8fd9-e9cf9ec29399
md"""
If you are interested in contributing, there is still a lot that can be done! Here are some more ideas listed with some estimation of their *difficulty*. But, if you got some ideas of your own, they are more than welcome!

- Di- and Triprotonic acids as options (*Medium*)

- Add a curve with a hidden concentration as an exercise; the concentration can be determined with the curve and checked as an input (*Medium*)

- Enumerate the equations with the ```\tag{}``` option to improve references to specific equations (*Easy*)

- Titrations against weak bases can be added (*Medium*)

- Flip acids and bases: Titrations of bases against acids (*Medium*)

- Contribute to the visualisation: (*hard*)

  - Add animations of erlenmeyer flask with colorful liquids inside, which maybe even change in volume depending on the added titrant
  - change the slider to a tab, which can be openedto fill a flask (new widget)

- Bugfixing: Further testing of the notebook and find errors and fix them (*medium - hard*)
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
ColorSchemes = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Handcalcs = "e8a07092-c156-4455-ab8e-ed8bc81edefb"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
StructuralUnits = "ec81c399-378c-4a82-baa1-80fb2fc85b6c"
WasmMakie = "782397d3-b2e0-4093-86f4-3070b4a5c6bd"

[sources]
WasmMakie = {url = "https://github.com/GroupTherapyOrg/WasmMakie.jl"}

[compat]
ColorSchemes = "~3.31.0"
Colors = "~0.13.1"
DataFrames = "~1.8.2"
Handcalcs = "~0.5.4"
LaTeXStrings = "~1.4.0"
PlutoUI = "~0.7.83"
StructuralUnits = "~0.2.0"
WasmMakie = "~0.1.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "691b9d554df9d853b56748f435ef2b4071fcdeea"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.CodeTracking]]
deps = ["InteractiveUtils", "REPL", "UUIDs"]
git-tree-sha1 = "cfb7a2e89e245a9d5016b70323db412b3a7438d5"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "3.0.2"

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

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "9d8a54ce4b17aa5bdce0ea5c34bc5e7c340d16ad"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.18.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.Compiler]]
git-tree-sha1 = "382d79bfe72a406294faca39ef0c3cef6e6ce1f1"
uuid = "807dbc54-b67e-4c79-8afb-eafe4df6f2e1"
version = "0.1.1"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "5fab31e2e01e70ad66e3e24c968c264d1cf166d6"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.8.2"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "6fb53a69613a0b2b68a0d12671717d307ab8b24e"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.5"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

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

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

[[deps.Handcalcs]]
deps = ["AbstractTrees", "CodeTracking", "InteractiveUtils", "LaTeXStrings", "Latexify", "MacroTools", "PrecompileTools", "Revise", "TestHandcalcFunctions"]
git-tree-sha1 = "6c1d1cc641e110b551ded513dbe3d2249c7ed558"
uuid = "e8a07092-c156-4455-ab8e-ed8bc81edefb"
version = "0.5.4"

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

[[deps.InlineStrings]]
git-tree-sha1 = "8f3d257792a522b4601c24a577954b0a8cd7334d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.5"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c0c9b76f3520863909825cbecdef58cd63de705a"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.5+0"

[[deps.JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "58927c485919bf17ea308d9d82156de1adf4b006"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.10.12"

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

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoweredCodeUtils]]
deps = ["CodeTracking", "Compiler", "JuliaInterpreter"]
git-tree-sha1 = "0aad96d7b987a5600e260eec50147b254d5ff7e6"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "3.6.0"

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

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

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

[[deps.OrderedCollections]]
git-tree-sha1 = "94ba93778373a53bfd5a0caaf7d809c445292ff4"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.2"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

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

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "REPL", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "624de6279ab7d94fc9f672f0068107eb6619732c"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "3.3.2"

    [deps.PrettyTables.extensions]
    PrettyTablesTypstryExt = "Typstry"

    [deps.PrettyTables.weakdeps]
    Typstry = "f0ed7684-a786-439e-b1e3-3b82803b501e"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.REPL]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
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

[[deps.Revise]]
deps = ["CodeTracking", "FileWatching", "InteractiveUtils", "JuliaInterpreter", "LibGit2", "LoweredCodeUtils", "OrderedCollections", "Preferences", "REPL", "UUIDs"]
git-tree-sha1 = "65569cca6282716a14177af1358db91ef79300f0"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.15.0"

    [deps.Revise.extensions]
    DistributedExt = "Distributed"

    [deps.Revise.weakdeps]
    Distributed = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "084c47c7c5ce5cfecefa0a98dff69eb3646b5a80"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.10"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "d05693d339e37d6ab134c5ab53c29fce5ee5d7d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.4"

[[deps.StructuralUnits]]
deps = ["Reexport", "Unitful", "UnitfulLatexify"]
git-tree-sha1 = "0e2a61508c26a096c3c032a55f9f997b13011b59"
uuid = "ec81c399-378c-4a82-baa1-80fb2fc85b6c"
version = "0.2.0"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "f2c1efbc8f3a609aadf318094f8fc5204bdaf344"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.1"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TestHandcalcFunctions]]
git-tree-sha1 = "54dac4d0a0cd2fc20ceb72e0635ee3c74b24b840"
uuid = "6ba57fb7-81df-4b24-8e8e-a3885b6fcae7"
version = "0.2.4"

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

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "6258d453843c466d84c17a58732dda5deeb8d3af"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.24.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    ForwardDiffExt = "ForwardDiff"
    InverseFunctionsUnitfulExt = "InverseFunctions"
    PrintfExt = "Printf"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"
    Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.UnitfulLatexify]]
deps = ["LaTeXStrings", "Latexify", "Unitful"]
git-tree-sha1 = "af305cc62419f9bd61b6644d19170a4d258c7967"
uuid = "45397f5d-5981-4c77-b2b3-fc36d6e9b728"
version = "1.7.0"

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
# ╟─83a21840-a772-469e-999d-c066f60e2e0e
# ╟─7705230b-91dc-4851-9e1b-37a642e66657
# ╟─657f405a-a7f8-4915-ba60-46464a01873f
# ╟─7c79ba77-e2b6-4e0d-8522-f0b540e6815f
# ╟─ad925028-59c3-433d-a54a-3f644d11b639
# ╟─8cea32f9-a670-4269-a586-c7bdb339a80d
# ╟─7205b4a5-d032-43c6-8232-a5d3cffb29d6
# ╟─d9adecaa-6ae8-46d4-955f-4a89a82a46c9
# ╟─9264917e-724d-4220-bbee-ec026285e475
# ╟─4882a030-f1d6-4b8b-a86f-a20e64fe4a6c
# ╟─733fe755-796d-41db-883a-cfc8d7d077a4
# ╟─6ba1348c-3cca-46a4-b109-bfb90f7ef7f2
# ╟─975a203f-e2d8-4f21-a4af-62212c7a9423
# ╟─7f5a2d2a-62fe-4985-b0fb-8559d9124801
# ╟─ffe30f1b-cde3-4f41-ac69-70f4d2634b3a
# ╟─b3420e1d-413e-463b-9bed-ac6182ce863a
# ╟─512a3218-e9e9-482e-b0b0-59650ea55fd1
# ╟─724c61e2-7237-4f3e-ab30-655164288aaf
# ╟─cd5bcc78-ad78-40c8-9356-140a04ea1a69
# ╟─7c465102-7d68-4827-bd8e-ed8e8ef0e303
# ╟─fa8df29f-be0a-498d-8fac-4cbe016f034a
# ╟─eb8979e7-b163-435d-a909-f020194ffc15
# ╟─563df061-7e97-4745-b101-cf4aa200da60
# ╟─7cab03c4-048d-4df7-a3a5-b20dfd1e6e9d
# ╟─f2b5c3e7-29c1-4f7b-82bb-cfa8da90d494
# ╟─831198d1-d22c-42b5-a198-3bd34139eb0e
# ╟─02c0320c-7c56-4fe5-8f8c-9ab0f733b28e
# ╟─9dee0462-b5af-4962-a65b-7ac7b2faf3df
# ╟─6ebfa6d8-b4a7-4d5e-8d3d-ccf0ba596f25
# ╟─a7e6ac40-51bd-46d7-a21c-ad294fa23d5a
# ╟─ab20be4e-d214-4c0e-85df-c293724c978e
# ╟─fa5deb25-ee07-4917-bf57-595bced01394
# ╟─1a229a8e-2378-4aff-871f-69446b9a4dd2
# ╟─006a4f14-2cd1-439f-8b64-aab99601aba8
# ╟─41536d79-8949-42ea-971c-8069918c455d
# ╟─1462be43-386b-4f9a-bae0-304fd058dd93
# ╟─95b20797-e804-4c15-b0d0-7aeb36540234
# ╟─5b088b11-f0af-461a-bc92-61fbfed0e768
# ╟─2e016b07-2ac0-4fd0-9c0a-3062616666f3
# ╟─8af4355b-b5cf-4017-a660-0b0ca884ad95
# ╟─38c319e0-0124-41fa-9910-173e645e7d03
# ╟─3b77b70e-be0b-46a7-948d-7289fcc72924
# ╟─05063b3d-8769-4d54-ad70-f38e95dca7a3
# ╟─38ba4eb9-4cd1-41d1-8b14-e07b3c76be3b
# ╟─d2fe14b6-59a9-4b9d-9028-3c9f41e91d1c
# ╟─76baa379-4a48-4268-871e-9e68db92c528
# ╟─d2323592-e4eb-4ac1-ab86-741910e1738c
# ╟─241fc16e-d252-4ef8-8e6d-267fc327ee88
# ╟─c1799961-2ae2-4fb0-8934-55fc2a16cc7e
# ╟─874bdbe5-d512-4566-9780-b78f141a8ba0
# ╟─4811fcde-5bfa-4c45-a32f-d39343651c90
# ╟─587040b9-c31a-4900-8b5d-26bf7000c570
# ╟─c780180d-4ca9-464c-9d14-74f9ce5c4501
# ╟─70ccb345-b0bc-456f-bda8-79a501059e6a
# ╟─50437455-4784-43ff-ac9c-5abdb43787fe
# ╟─ba25c716-b754-4887-b3b9-b85dba0f90d2
# ╟─8bc4224f-0142-448c-be95-98cbb160071c
# ╟─fb20a23a-4102-4ee3-a73f-64c2640b0adb
# ╟─a27a4577-151d-45c0-9675-288076d2da59
# ╟─631559da-b114-4932-a031-c555ac56b3bf
# ╟─3f7feb3d-99db-4b5e-a7e5-4f26c9c5ae68
# ╟─975f4b7b-d6a4-4d72-96cc-90832ef22db4
# ╟─8818efcf-704c-41c2-b0b4-b9da3ce53205
# ╟─adc9907a-a224-4400-99e8-5fb6e385adfc
# ╟─5834c3bb-be94-4103-817c-4102bad491cf
# ╟─8435c139-ec9b-4ab1-82fc-4f0a20073f81
# ╟─7e8946ca-8168-4b3a-851b-1e4458c6be77
# ╟─5e2cdf07-4cf4-4347-a10d-58322aee46eb
# ╟─eabac306-fca3-42d4-add8-29c053e5f97d
# ╟─ab27ac5f-8e35-4c90-bbc5-e60bf699281d
# ╟─c44d318d-a710-4adb-acac-fd7f0f53cec3
# ╟─4b5214a5-e35f-431a-9f3e-63eff56d1f45
# ╟─435fb7e5-4afd-4c37-b21a-9dd1935c4fe2
# ╟─1a9060ae-f257-4892-881a-09c7e7b71747
# ╠═094598f7-8319-4551-b677-de5729672080
# ╠═ffc3c232-12c1-408a-af0a-25fadb418a21
# ╟─d67aad9b-1b53-48e1-bb39-82a2ac52b17c
# ╟─50caa04e-880d-4224-90b4-0a8d9004576b
# ╠═41bed3bd-75f9-4b1a-9ea8-786b338b7503
# ╠═af04638c-2615-4195-a45e-d6d85af6d6cd
# ╟─8b9e6746-b731-4b39-a0b8-4b9e4c752cc6
# ╠═4127a0c7-897b-41c2-9319-2b1c48369699
# ╟─c59b620d-a6dd-4e19-ac30-5840568efba4
# ╟─67136d72-c447-4268-8c17-b6d9ad3652ca
# ╠═ab1430fd-ddd9-48d6-94e8-465cea45ff25
# ╟─2ffcfcc2-ac5f-4293-bab0-3fede68c115a
# ╟─cec8f377-dc41-41ba-a3b3-d916acba1147
# ╟─4336e057-2a02-47d6-8fd9-e9cf9ec29399
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
