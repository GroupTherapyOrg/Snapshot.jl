# /how-it-works/ — explains the lean "notebook → Therapy component" pipeline:
# extraction → wasm islands → SSR cells → signals/hydration → DaisyUI theming.
# Written for someone landing here to understand what PlutoIslands actually does.

() -> begin
    base = get(ENV, "PIDOCS_BASE", "")

    section(title, children...) = Div(:class => "space-y-4",
        H2(:class => "text-2xl font-serif font-bold text-warm-900 dark:text-warm-100 no-rule", title),
        children...)

    para(children...) = P(:class => "text-warm-600 dark:text-warm-400 leading-relaxed", children...)

    code(s) = Code(:class => "font-mono text-accent-600 dark:text-accent-400", s)

    italic(s) = Span(:class => "italic", s)

    # a numbered pipeline step
    step(n, title, body...) = Div(:class => "flex gap-4",
        Div(:class => "shrink-0 w-8 h-8 rounded-full bg-accent-100 dark:bg-accent-900/50 text-accent-700 dark:text-accent-300 flex items-center justify-center font-mono text-sm font-bold", string(n)),
        Div(:class => "space-y-1",
            H3(:class => "font-semibold text-warm-900 dark:text-warm-100", title),
            P(:class => "text-sm text-warm-600 dark:text-warm-400 leading-relaxed", body...)))

    # a Pluto-concept ↔ Therapy-primitive mapping row
    maprow(pluto, therapy, note) = Div(:class => "grid grid-cols-[1fr_auto_1fr] items-center gap-3 py-3 border-b border-warm-200 dark:border-warm-800 last:border-0",
        Div(:class => "font-mono text-sm text-warm-800 dark:text-warm-200", pluto),
        Span(:class => "text-accent-500 font-mono", "→"),
        Div(:class => "space-y-0.5",
            Div(:class => "font-mono text-sm text-warm-800 dark:text-warm-200", therapy),
            Div(:class => "text-xs text-warm-500 dark:text-warm-500", note)))

    usecard(title, desc, codestr) = Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 p-5 bg-white dark:bg-warm-900/40 space-y-3",
        H3(:class => "font-semibold text-warm-900 dark:text-warm-100", title),
        P(:class => "text-sm text-warm-600 dark:text-warm-400 leading-relaxed", desc),
        Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-4 rounded-lg overflow-x-auto border border-warm-800 text-xs",
            Code(:class => "language-julia font-mono", codestr)))

    Div(:class => "space-y-14 max-w-3xl mx-auto",
        # ── Hero ────────────────────────────────────────────────────────
        Div(:class => "space-y-5 pt-4",
            Span(:class => "inline-block px-2.5 py-0.5 rounded-full text-xs font-mono uppercase tracking-wider bg-accent-100 dark:bg-accent-900/50 text-accent-700 dark:text-accent-300",
                "How it works"),
            H1(:class => "no-rule text-4xl md:text-5xl font-serif font-bold text-warm-900 dark:text-warm-100",
                "A Pluto notebook becomes a Therapy component"),
            para(
                "PlutoIslands takes a ",
                A(:href => "https://plutojl.org", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "Pluto.jl"),
                " notebook and emits a ", Strong("lean, self-contained Therapy component"),
                " — interactive sliders and plots that run entirely in the browser as WebAssembly, ",
                "with no Julia server, no Pluto frontend, and no multi-megabyte session statefile. ",
                "The result drops into any static host as a standalone page, or into a larger ",
                A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "Therapy.jl"),
                " app as one component among many — themeable, with or without reactivity."
            )
        ),

        # ── Why ─────────────────────────────────────────────────────────
        section("The problem it solves",
            para(
                "Pluto's classic static export is faithful but heavy: it bakes the entire session ",
                "state — every cell's rendered output, around 2.6 MB — into the HTML and ships the full ",
                "Pluto frontend to re-hydrate it. For a page of sliders and a plot, that is a lot of bytes, ",
                "and it locks the look to Pluto's chrome."
            ),
            para(
                "The lean export keeps everything that makes the notebook ", italic("work"),
                " and drops everything that was only there to reconstruct Pluto's editor. ",
                "Most notebooks fall from megabytes to tens of kilobytes of HTML."
            )
        ),

        # ── Pipeline ────────────────────────────────────────────────────
        section("The pipeline",
            para("At export time the notebook runs once in Pluto. Then, per notebook:"),
            Div(:class => "space-y-5 pt-2",
                step(1, "Extract the reactive graph",
                    "Pluto already knows the dependency graph and which cells depend on a ", code("@bind"),
                    " widget. PlutoIslands groups co-dependent bond cells and lifts each dependent cell body into a pure Julia function."),
                step(2, "Compile to WebAssembly islands",
                    "Each bond group compiles to a small WasmGC module via ", code("WasmTarget.jl"),
                    " — the actual compute that regenerates a cell when a slider moves. It is verified at export time against real notebook re-runs before it ships."),
                step(3, "Server-render every cell",
                    "Each cell's output is written straight into the page as HTML, following Pluto's own decisions about ordering, what is and isn't output, and visibility. Nothing about the notebook's structure is invented."),
                step(4, "Hydrate with signals + islands",
                    "A tiny runtime wires each ", code("<bond>"), " input to the wasm island that owns it. Move a slider and only the dependent cells recompute — figures redraw on a live ", code("<canvas>"), ", numbers and text update in place. No virtual DOM, no full re-render."),
            )
        ),

        # ── Isomorphism ─────────────────────────────────────────────────
        section("Why it maps cleanly",
            para(
                "Pluto's reactive model and Therapy's signals model are essentially the same idea, ",
                "so the translation is direct rather than a reimplementation:"),
            Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 p-5 bg-white dark:bg-warm-900/40",
                maprow("@bind x Slider(…)", "signal + <input>", "a shared reactive value the widget writes and cells read"),
                maprow("bond-dependent cell", "island / effect", "wasm recomputes it when its inputs change"),
                maprow("static cell", "SSR HTML", "rendered once at export, no runtime needed"),
                maprow("figure output", "live <canvas>", "redrawn by WasmMakie on each change, not a baked image"),
                maprow("text / number / tree", "reactive DOM node", "updated in place — divs, not canvas"),
            )
        ),

        # ── Theming ─────────────────────────────────────────────────────
        section("Theming: copy Pluto, swap the variables",
            para(
                "Rather than re-style the output by hand, the export ports Pluto's own output CSS ",
                "almost verbatim — markdown, admonitions, tables, code, the array/tree viewer, the ",
                "table of contents — and re-points every one of Pluto's color variables at a ",
                A(:href => "https://daisyui.com", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "DaisyUI"),
                " token."
            ),
            para(
                "So the notebook renders exactly as Pluto does, but one attribute — ",
                code("data-theme=\"…\""),
                " — restyles the whole thing. The ", code("🎨"), " picker in the nav above does just that: ",
                "because each notebook is now real DOM on the page (no iframe), one dropdown sets the theme on ",
                "every notebook at once and remembers your choice — they reskin together, seamlessly, as part of the site."
            )
        ),

        # ── Usage ───────────────────────────────────────────────────────
        section("Two ways to use it",
            Div(:class => "grid grid-cols-1 md:grid-cols-2 gap-4",
                usecard("Standalone page",
                    "Export a notebook and serve the HTML anywhere — GitHub Pages, S3, a CDN. It carries its own theme picker and needs no server.",
                    "export_notebook(\"notebook.jl\";\n    therapy=true)\n# → notebook.html + notebook.islands/"),
                usecard("Component in a Therapy app",
                    "Embed the notebook inside a larger Therapy site — a docs page, a course, a dashboard — and let the host's theme drive it. This very gallery does exactly that.",
                    "export_notebook(\"notebook.jl\";\n    therapy=true,\n    theme_picker=false)  # host owns the picker"),
            )
        ),

        # ── CTA ─────────────────────────────────────────────────────────
        Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 p-6 bg-warm-50 dark:bg-warm-900/40 flex flex-col sm:flex-row items-center justify-between gap-4",
            Div(:class => "space-y-1",
                H3(:class => "font-semibold text-warm-900 dark:text-warm-100", "See it in action"),
                P(:class => "text-sm text-warm-600 dark:text-warm-400", "Every notebook in the gallery is a live Therapy component. Try the theme picker.")),
            A(:href => "$(base)/notebooks/",
                :class => "shrink-0 px-5 py-2.5 bg-accent-600 hover:bg-accent-700 text-white rounded-lg font-medium transition-colors no-underline",
                "Browse the Notebooks →")
        )
    )
end
