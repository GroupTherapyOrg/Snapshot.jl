# /notebooks/ — the featured-notebook gallery.
#
# Reads docs/notebooks-static/index.json (written by docs/export_notebooks.jl,
# COMMITTED to the repo) at site-build time and renders one card per notebook.
# Clicking a card opens the actual Pluto export: wasm-islands interactive when
# ≥1 bond group shipped, plain static otherwise. Notebooks whose cells errored
# still export — Pluto shows the errors inside the cells. Notebooks that failed
# to run at all are listed with their error.

import JSON

() -> begin
    base = get(ENV, "PIDOCS_BASE", "")
    index_path = joinpath(@__DIR__, "..", "..", "notebooks-static", "index.json")
    entries = isfile(index_path) ? JSON.parsefile(index_path) : []

    badge(status, islands, degraded) =
        if status == "interactive"
            Span(:class => "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-accent-100 dark:bg-accent-900/50 text-accent-700 dark:text-accent-300",
                "🏝️ interactive — $(islands) island$(islands == 1 ? "" : "s")$(degraded > 0 ? " · $(degraded) fallback" : "")")
        elseif status == "static" && degraded > 0
            # has @bind groups, but none compiled yet — say so honestly
            Span(:class => "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300",
                "⚡ $(degraded) bond group$(degraded == 1 ? "" : "s") not yet wasm-compilable")
        elseif status == "static"
            Span(:class => "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-warm-200 dark:bg-warm-800 text-warm-700 dark:text-warm-300",
                "📄 static")
        else
            Span(:class => "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300",
                "⚠️ export failed")
        end

    Div(:class => "space-y-10",
        Div(:class => "space-y-4",
            H1(:class => "text-4xl font-serif font-bold text-warm-900 dark:text-warm-100", "Featured Notebooks"),
            P(:class => "text-warm-600 dark:text-warm-400 max-w-3xl leading-relaxed",
                "The ",
                A(:href => "https://github.com/JuliaPluto/featured", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "Pluto featured notebooks"),
                ", exported by this fork. ",
                Strong("🏝️ interactive"), " notebooks have at least one bond group running as a WasmTarget island — ",
                "move those sliders with no Julia server behind the page. ",
                Strong("📄 static"), " notebooks have no compilable bonds (yet — every fallback reason is a ",
                A(:href => "https://github.com/GroupTherapyOrg/PlutoIslands.jl/blob/main/WASM_FINDINGS.md", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "work item"),
                "). Cells that error show their errors inline, exactly like Pluto."
            )
        ),
        isempty(entries) ?
            P(:class => "text-warm-500 italic",
                "No exports found — run `julia --project=. docs/export_notebooks.jl` and commit docs/notebooks-static/.") :
            Div(:class => "grid grid-cols-1 md:grid-cols-2 gap-6",
                For(entries) do e
                    status = get(e, "status", "failed")
                    islands = get(e, "islands", 0)
                    degraded = get(e, "degraded", 0)
                    image = get(e, "image", "")
                    # internal route: the notebook opens INSIDE the docs layout
                    href = "$(base)/notebooks/$(replace(e["slug"], " " => "%20"))/"
                    # frontmatter URLs pass through; bare names are our own assets
                    img_src = startswith(image, "http") ? image : "$(base)/assets/$(image)"
                    card_inner = Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg overflow-hidden bg-white shadow-sm dark:shadow-none dark:bg-warm-900/50 hover:border-accent-400 dark:hover:border-accent-600 transition-colors h-full flex flex-col",
                        Div(:class => "h-36 w-full overflow-hidden bg-warm-200 dark:bg-warm-800",
                            Img(:src => img_src, :alt => e["title"], :loading => "lazy",
                                :class => "w-full h-full object-cover")),
                        Div(:class => "p-5 space-y-3 flex-1 flex flex-col",
                            Div(:class => "flex items-start justify-between gap-3",
                                H3(:class => "font-semibold text-warm-900 dark:text-warm-100 leading-snug", e["title"]),
                                badge(status, islands, degraded)
                            ),
                            P(:class => "text-sm text-warm-600 dark:text-warm-400 leading-relaxed flex-1",
                                get(e, "description", "")),
                            status == "failed" ?
                                Pre(:class => "text-xs bg-red-50 dark:bg-red-950/40 text-red-700 dark:text-red-300 p-3 rounded overflow-x-auto",
                                    Code(get(e, "error", "unknown error"))) :
                                Span(:class => "text-xs text-accent-600 dark:text-accent-400 font-medium", "Open notebook →")
                        )
                    )
                    status == "failed" ? card_inner : A(:href => href, :class => "no-underline block", card_inner)
                end
            )
    )
end
