# NotebookPage — renders an exported notebook as a NATIVE INLINE Therapy component
# (no iframe). It reads the committed <slug>.fragment.html — a self-contained
# <div class="pi-notebook"> with @scope-isolated CSS + the wasm-island shim/wiring —
# rewrites the asset-base placeholder for the docs base_path, and injects it as REAL
# DOM in the page. The notebook inherits the site's DaisyUI theme and flows into the
# page (no card/box). Reached via a FULL page load (cards use target=_self), so the
# island scripts run fresh on each visit → reactive sliders + live figures.

const _NOTEBOOK_GITHUB_BASE =
    "https://github.com/GroupTherapyOrg/PlutoIslands.jl/blob/main/test/notebooks/featured"

"Read the committed inline fragment and point its asset URLs at the served path."
function _notebook_fragment(slug::AbstractString, base::AbstractString)
    path = joinpath(@__DIR__, "..", "..", "notebooks-static", slug * ".fragment.html")
    isfile(path) || return nothing
    replace(read(path, String), "__PI_ASSETS_BASE__" => "$(base)/notebooks-static")
end

function NotebookPage(slug::AbstractString, title::AbstractString, html_name::AbstractString, status::AbstractString, islands::Int, cells_interactive::Int=0, cells_total::Int=0)
    base = get(ENV, "PIDOCS_BASE", "")
    badge = status == "interactive" ?
        Span(:class => "badge badge-success badge-sm gap-1 normal-case",
            cells_total > 0 ? "🏝️ $(cells_interactive)/$(cells_total) cells interactive" :
                              "🏝️ $(islands) wasm island$(islands == 1 ? "" : "s")") :
        Span(:class => "badge badge-ghost badge-sm gap-1 normal-case", "📄 static")

    frag = _notebook_fragment(slug, base)
    notebook = frag === nothing ?
        Div(:class => "rounded-box border border-base-300 p-8 text-center text-base-content/50",
            "Notebook export not found — run docs/export_notebooks.jl.") :
        RawHtml(frag)

    Div(:class => "max-w-3xl mx-auto space-y-5",
        Div(:class => "flex items-center justify-between gap-3 flex-wrap",
            Div(:class => "flex items-center gap-2.5 text-sm flex-wrap",
                # target=_self → full reload (served router build ignores data-no-router)
                A(:href => "$(base)/notebooks/", :target => "_self", Symbol("data-no-router") => "",
                    :class => "text-base-content/50 hover:text-primary no-underline transition-colors", "← Notebooks"),
                Span(:class => "text-base-content/30", "/"),
                Span(:class => "sn-display font-semibold text-base-content", title),
                badge,
            ),
            A(:href => "$(_NOTEBOOK_GITHUB_BASE)/$(replace(slug, " " => "%20")).jl", :target => "_blank", :rel => "noopener",
                :class => "btn btn-ghost btn-sm gap-1.5 no-underline",
                RawHtml("""<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>"""),
                Span(".jl source"),
            ),
        ),
        # the notebook itself — native DOM, @scope-isolated, reactive, inherits the
        # site theme. A soft .sn-bubble panel (same language as the gallery cards)
        # delineates where the notebook starts/ends — distinctive, but built-in (it
        # reskins with the theme), NOT a hard iframe box.
        Div(:class => "bg-base-100 rounded-box sn-bubble px-5 sm:px-8 py-7 overflow-hidden", notebook),
    )
end
