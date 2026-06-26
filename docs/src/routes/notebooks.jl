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

    # accurate CELL-level counts (coverage.json): interactive cells / total bond
    # cells, with any non-interactive fallback cells called out honestly.
    badge(e) = begin
        status = get(e, "status", "failed")
        ci = get(e, "cells_interactive", 0)
        ct = get(e, "cells_total", 0)
        cf = get(e, "cells_fallback", 0)
        degraded = get(e, "degraded", 0)
        if status == "interactive"
            Span(:class => "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-accent-100 dark:bg-accent-900/50 text-accent-700 dark:text-accent-300",
                ct > 0 ? "🏝️ $(ci)/$(ct) cells interactive$(cf > 0 ? " · $(cf) fallback" : "")" :
                         "🏝️ interactive")
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
    end

    # corpus totals (accurate cell-level) for the intro line
    tot_int = sum(e -> get(e, "cells_interactive", 0), entries; init=0)
    tot_cells = sum(e -> get(e, "cells_total", 0), entries; init=0)
    n_interactive_nb = count(e -> get(e, "status", "") == "interactive", entries)

    Div(:class => "space-y-10",
        Div(:class => "space-y-4",
            H1(:class => "text-4xl font-serif font-bold text-warm-900 dark:text-warm-100", "Featured Notebooks"),
            P(:class => "text-warm-600 dark:text-warm-400 max-w-3xl leading-relaxed",
                "The ",
                A(:href => "https://github.com/JuliaPluto/featured", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "Pluto featured notebooks"),
                ", exported by this fork. ",
                Strong("🏝️ interactive"), " notebooks run their reactive cells as WasmTarget islands — ",
                "move the sliders with no Julia server behind the page. Each badge shows how many of a notebook's ",
                "bond-dependent cells run live (interactive / total). ",
                Strong("📄 static"), " notebooks have no compilable bonds (yet — every fallback reason is a ",
                A(:href => "https://github.com/GroupTherapyOrg/PlutoIslands.jl/blob/main/WASM_FINDINGS.md", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "work item"),
                "). Cells that error show their errors inline, exactly like Pluto."
            ),
            tot_cells > 0 ?
                P(:class => "text-sm text-accent-700 dark:text-accent-300 font-medium",
                    "$(tot_int)/$(tot_cells) interactive cells live across $(n_interactive_nb) notebooks.") :
                nothing,
            # honest note: some notebooks are lightly adapted to today's WT subset
            Div(:class => "rounded-lg border border-accent-200 dark:border-accent-800 bg-accent-50 dark:bg-accent-950/30 px-4 py-3 text-sm text-warm-700 dark:text-warm-300 max-w-3xl",
                Strong("Note: "),
                "Some of these notebooks have been lightly adapted from the original Pluto featured versions to fit the current capabilities of ",
                A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "WasmTarget.jl"),
                " (the Julia→WebAssembly compiler). The concepts, demos, and teaching are preserved — only the implementation is adjusted to WT-supported patterns (e.g. ",
                A(:href => "https://github.com/GroupTherapyOrg/WasmMakie.jl", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "WasmMakie"),
                " figures and blessed bond/return types) so every cell can compile to a live in-browser island."
            )
        ),
        isempty(entries) ?
            P(:class => "text-warm-500 italic",
                "No exports found — run `julia --project=. docs/export_notebooks.jl` and commit docs/notebooks-static/.") :
            Div(:class => "grid grid-cols-1 md:grid-cols-2 gap-6",
                For(entries) do e
                    status = get(e, "status", "failed")
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
                                badge(e)
                            ),
                            P(:class => "text-sm text-warm-600 dark:text-warm-400 leading-relaxed flex-1",
                                get(e, "description", "")),
                            status == "failed" ?
                                Pre(:class => "text-xs bg-red-50 dark:bg-red-950/40 text-red-700 dark:text-red-300 p-3 rounded overflow-x-auto",
                                    Code(get(e, "error", "unknown error"))) :
                                Span(:class => "text-xs text-accent-600 dark:text-accent-400 font-medium", "Open notebook →")
                        )
                    )
                    # FULL page load so the inline notebook's island scripts run fresh
                    # (reactive), not a client-router innerHTML swap. The docs' Therapy
                    # router build predates `data-no-router`, but it DOES skip links with
                    # a `target` attribute — so target="_self" reliably forces the reload.
                    status == "failed" ? card_inner : A(:href => href, :target => "_self", Symbol("data-no-router") => "", :class => "no-underline block", card_inner)
                end
            )
    )
end
