# NotebookPage — renders an exported notebook as a NATIVE INLINE Therapy component
# (no iframe). It reads the committed <slug>.fragment.html — a self-contained
# <div class="pi-notebook"> with @scope-isolated CSS + the wasm-island shim/wiring —
# rewrites the asset-base placeholder for the docs base_path, and injects it as REAL
# DOM in the page. Notebook pages are reached via a FULL page load (the gallery card
# links carry data-no-router), so the island scripts run fresh on each visit —
# reactive sliders + live figures, themeable by the host's DaisyUI picker.

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
        Span(:class => "px-2 py-0.5 rounded-full bg-accent-100 dark:bg-accent-900/50 text-accent-700 dark:text-accent-300 normal-case tracking-normal",
            cells_total > 0 ? "🏝️ $(cells_interactive)/$(cells_total) cells interactive — runs in your browser" :
                              "🏝️ $(islands) wasm island$(islands == 1 ? "" : "s") — runs in your browser") :
        Span(:class => "px-2 py-0.5 rounded-full bg-warm-200 dark:bg-warm-800 text-warm-600 dark:text-warm-400 normal-case tracking-normal",
            "📄 static export")

    frag = _notebook_fragment(slug, base)
    notebook = frag === nothing ?
        Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 p-8 text-center text-warm-500",
            "Notebook export not found — run docs/export_notebooks.jl.") :
        RawHtml(frag)

    Div(:class => "max-w-5xl mx-auto space-y-4",
        Div(:class => "flex items-center justify-between gap-3 text-[10px] tracking-[0.2em] uppercase font-mono text-warm-500 dark:text-warm-500",
            Div(:class => "flex items-center gap-3 flex-wrap",
                A(:href => "$(base)/notebooks/", Symbol("data-no-router") => "",
                    :class => "hover:text-accent-600 dark:hover:text-accent-400 no-underline transition-colors",
                    "← Notebooks"
                ),
                Span(:class => "text-warm-300 dark:text-warm-700", "/"),
                Span(:class => "text-warm-700 dark:text-warm-300", title),
                badge,
            ),
            A(:href => "$(_NOTEBOOK_GITHUB_BASE)/$(replace(slug, " " => "%20")).jl", :target => "_blank", :rel => "noopener",
                :class => "flex items-center gap-2 px-3 py-1.5 rounded-full border border-warm-300 dark:border-warm-700 hover:border-accent-400 dark:hover:border-accent-600 hover:text-accent-600 dark:hover:text-accent-400 transition-colors no-underline shrink-0",
                Span(".jl source"),
            ),
        ),
        # the notebook itself — native DOM, @scope-isolated, reactive
        notebook,
    )
end
