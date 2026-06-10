# NotebookPage — wraps an exported Pluto notebook in an iframe with Therapy
# chrome (breadcrumb back-link + source link), so notebooks open WITHIN the
# docs webapp instead of navigating away from it. BasisSimulator.jl docs
# pattern. Pluto's CSS/JS stays sandboxed inside the iframe — no style
# collisions with the Tailwind layout, and the wasm-islands shim runs
# untouched inside the frame.

const _NOTEBOOK_GITHUB_BASE =
    "https://github.com/GroupTherapyOrg/PlutoIslands.jl/blob/main/test/notebooks/featured"

function NotebookPage(slug::AbstractString, title::AbstractString, html_name::AbstractString, status::AbstractString, islands::Int)
    base = get(ENV, "PIDOCS_BASE", "")
    badge = status == "interactive" ?
        Span(:class => "px-2 py-0.5 rounded-full bg-accent-100 dark:bg-accent-900/50 text-accent-700 dark:text-accent-300 normal-case tracking-normal",
            "🏝️ $(islands) wasm island$(islands == 1 ? "" : "s") — sliders need no server") :
        Span(:class => "px-2 py-0.5 rounded-full bg-warm-200 dark:bg-warm-800 text-warm-600 dark:text-warm-400 normal-case tracking-normal",
            "📄 static export")

    Div(:class => "max-w-6xl mx-auto space-y-4",
        Div(:class => "flex items-center justify-between gap-3 text-[10px] tracking-[0.2em] uppercase font-mono text-warm-500 dark:text-warm-500",
            Div(:class => "flex items-center gap-3",
                A(:href => "$(base)/notebooks/",
                    :class => "hover:text-accent-600 dark:hover:text-accent-400 no-underline transition-colors",
                    "← Notebooks"
                ),
                Span(:class => "text-warm-300 dark:text-warm-700", "/"),
                Span(:class => "text-warm-700 dark:text-warm-300", title),
                badge,
            ),
            A(:href => "$(_NOTEBOOK_GITHUB_BASE)/$(replace(slug, " " => "%20")).jl", :target => "_blank", :rel => "noopener",
                :class => "flex items-center gap-2 px-3 py-1.5 rounded-full border border-warm-300 dark:border-warm-700 hover:border-accent-400 dark:hover:border-accent-600 hover:text-accent-600 dark:hover:text-accent-400 transition-colors no-underline",
                Span(".jl source"),
            ),
        ),
        # Pluto static HTML, sandboxed. Forced white background: Pluto's
        # export is light-mode — on dark:bg-warm-950 it would be unreadable.
        Iframe(
            :src => "$(base)/notebooks-static/$(replace(html_name, " " => "%20"))",
            :class => "w-full h-[calc(100vh-10rem)] border border-warm-200 dark:border-warm-800 rounded-lg",
            :style => "background-color: #ffffff;",
            :loading => "eager",
            :title => title,
        ),
    )
end
