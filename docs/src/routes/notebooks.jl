# /notebooks/ — the featured-notebook gallery (Snapshot-style cards).
#
# Reads docs/notebooks-static/index.json (committed) at build time → one card per
# notebook. Clicking a card FULL-loads the inline notebook showcase (target=_self,
# so the island scripts run fresh and the notebook is reactive).

import JSON

() -> begin
    base = get(ENV, "SNAPDOCS_BASE", "")
    index_path = joinpath(@__DIR__, "..", "..", "notebooks-static", "index.json")
    entries = isfile(index_path) ? JSON.parsefile(index_path) : []

    badge(e) = begin
        status = get(e, "status", "failed")
        ci = get(e, "cells_interactive", 0); ct = get(e, "cells_total", 0)
        cf = get(e, "cells_fallback", 0); degraded = get(e, "degraded", 0)
        if status == "interactive"
            Span(:class => "badge badge-success badge-sm gap-1 shrink-0",
                ct > 0 ? "🏝️ $(ci)/$(ct)$(cf > 0 ? " · $(cf) fb" : "")" : "🏝️ live")
        elseif status == "static" && degraded > 0
            Span(:class => "badge badge-warning badge-sm gap-1 shrink-0", "⚡ $(degraded) pending")
        elseif status == "static"
            Span(:class => "badge badge-ghost badge-sm gap-1 shrink-0", "📄 static")
        else
            Span(:class => "badge badge-error badge-sm gap-1 shrink-0", "⚠️ failed")
        end
    end

    tot_int = sum(e -> get(e, "cells_interactive", 0), entries; init=0)
    tot_cells = sum(e -> get(e, "cells_total", 0), entries; init=0)
    n_interactive_nb = count(e -> get(e, "status", "") == "interactive", entries)
    covers = ["sn-cover-a", "sn-cover-b", "sn-cover-c", "sn-cover-d"]

    Div(:class => "space-y-10",
        Div(:class => "space-y-4",
            H1(:class => "sn-display text-4xl sm:text-5xl font-semibold text-base-content", "Featured Notebooks"),
            P(:class => "text-base-content/60 max-w-3xl leading-relaxed",
                "The ",
                A(:href => "https://github.com/JuliaPluto/featured", :target => "_blank", :class => "link link-primary", "Pluto featured notebooks"),
                ", exported by this fork as lean Therapy components. ",
                Strong("🏝️ live"), " notebooks run their reactive cells as WasmTarget islands — move the sliders, no Julia server. ",
                Strong("📄 static"), " notebooks have no compilable bonds yet."),
            tot_cells > 0 ?
                P(:class => "text-sm text-primary font-medium",
                    "$(tot_int)/$(tot_cells) interactive cells live across $(n_interactive_nb) notebooks.") : nothing,
            Div(:class => "rounded-box border border-base-300 bg-base-100 px-4 py-3 text-sm text-base-content/70 max-w-3xl",
                Strong("Note: "),
                "Some notebooks are lightly adapted from the originals to fit the current ",
                A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank", :class => "link link-primary", "WasmTarget.jl"),
                " subset (e.g. ",
                A(:href => "https://github.com/GroupTherapyOrg/WasmMakie.jl", :target => "_blank", :class => "link link-primary", "WasmMakie"),
                " figures) so every cell can compile to a live in-browser island. Concepts preserved.")
        ),
        isempty(entries) ?
            P(:class => "text-base-content/50 italic",
                "No exports found — run `julia --project=. docs/export_notebooks.jl` and commit docs/notebooks-static/.") :
            Div(:class => "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5",
                For(entries) do e
                    status = get(e, "status", "failed")
                    href = "$(base)/notebooks/$(replace(e["slug"], " " => "%20"))/"
                    cover = covers[mod1(length(get(e, "slug", "x")), 4)]
                    emoji = status == "interactive" ? "🏝️" : "📄"
                    card_inner = Div(:class => "bg-base-100 rounded-box sn-bubble sn-bubble-hover overflow-hidden flex flex-col h-full",
                        Div(:class => "sn-cover $(cover)",
                            RawHtml("""<span class="sn-cover-emoji">$(emoji)</span>""")),
                        Div(:class => "p-5 flex flex-col gap-2.5 flex-1",
                            Div(:class => "flex items-start justify-between gap-2",
                                H3(:class => "sn-display text-lg font-semibold text-base-content leading-snug", e["title"]),
                                badge(e)),
                            P(:class => "text-sm text-base-content/60 leading-relaxed flex-1 line-clamp-3",
                                get(e, "description", "")),
                            status == "failed" ?
                                Pre(:class => "text-xs bg-error/10 text-error p-2 rounded overflow-x-auto",
                                    Code(get(e, "error", "unknown error"))) :
                                Span(:class => "text-sm text-primary font-medium mt-auto", "Open notebook →"))
                    )
                    # target=_self → FULL page load so the inline notebook hydrates (the
                    # served router build ignores data-no-router but skips target'd links).
                    status == "failed" ? card_inner :
                        A(:href => href, :target => "_self", Symbol("data-no-router") => "", :class => "no-underline block h-full", card_inner)
                end
            )
    )
end
