() -> begin
    base = get(ENV, "PIDOCS_BASE", "")
    Div(:class => "space-y-16",
        # Hero
        Div(:class => "text-center space-y-6 pt-8",
            H1(:class => "no-rule text-5xl md:text-6xl font-serif font-bold text-warm-900 dark:text-warm-100",
                "Interactive Pluto Exports"
            ),
            H1(:class => "no-rule text-5xl md:text-6xl font-serif font-bold text-accent-500",
                "No Julia Server"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-400 max-w-2xl mx-auto leading-relaxed",
                Code(:class => "text-accent-500 font-mono", "@bind"),
                "-dependent cells of a ",
                A(:href => "https://plutojl.org", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "Pluto.jl"),
                " notebook compile to WebAssembly via ",
                A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank", :class => "text-accent-500 hover:text-accent-600 underline", "WasmTarget.jl"),
                " and ship as ", Strong("interactive islands"), " inside the classic static export. Sliders work on any static host — ",
                "no slider server, no precomputed request files. Cells that can't compile keep their ",
                "original content and say so, beautifully."
            ),
            Div(:class => "flex gap-4 justify-center pt-4",
                A(:href => "$(base)/notebooks/",
                    :class => "px-6 py-3 bg-accent-600 hover:bg-accent-700 text-white rounded-lg font-medium transition-colors",
                    "Browse the Notebooks"
                ),
                A(:href => "https://github.com/GroupTherapyOrg/PlutoIslands.jl", :target => "_blank",
                    :class => "px-6 py-3 border border-warm-300 dark:border-warm-700 rounded-lg font-medium text-warm-700 dark:text-warm-300 hover:bg-warm-100 dark:hover:bg-warm-900 transition-colors",
                    "View on GitHub"
                )
            )
        ),
        # Quickstart
        Div(:class => "w-full max-w-3xl mx-auto space-y-4",
            H2(:class => "text-2xl font-serif font-bold text-warm-900 dark:text-warm-100", "Quickstart"),
            Pre(:class => "bg-warm-900 dark:bg-warm-950 text-warm-200 p-6 rounded-lg overflow-x-auto border border-warm-800",
                Code(:class => "language-julia text-sm font-mono", """using PlutoIslands

# classic HTML export, plus: every compilable bond group ships as a
# WasmGC island — verified against the real notebook before shipping
export_notebook("notebook.jl")

# → notebook.html + notebook.islands/   (serve anywhere static)""")
            ),
            P(:class => "text-sm text-warm-600 dark:text-warm-400 leading-relaxed",
                "At export time the notebook runs once in Pluto. Each group of co-dependent ",
                Code(:class => "font-mono", "@bind"),
                " variables is extracted into pure Julia functions (one per dependent cell), compiled to a small ",
                "WasmGC module, and verified two ways: original output bodies must reproduce byte-exactly, and a ",
                "differential oracle re-runs the notebook on sampled bond values and compares against the wasm. ",
                "In the browser, a small shim answers Pluto's slider-server protocol locally from the wasm — the ",
                "stock Pluto frontend is untouched."
            )
        ),
        # Feature cards
        Div(:class => "grid grid-cols-1 md:grid-cols-3 gap-6",
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-6 bg-white shadow-sm dark:shadow-none dark:bg-warm-900/50",
                Div(:class => "w-10 h-10 rounded-lg bg-accent-100 dark:bg-accent-900/50 flex items-center justify-center mb-4",
                    RawHtml("""<svg class="w-5 h-5 text-accent-600 dark:text-accent-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>""")
                ),
                H3(:class => "font-semibold mb-2 text-warm-900 dark:text-warm-100", "Instant Interactivity"),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm leading-relaxed",
                    "Slider moves are local WASM calls — no network round-trip, no Julia process, no combinatorial precompute explosion. Continuous and infinite bond domains work.")
            ),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-6 bg-white shadow-sm dark:shadow-none dark:bg-warm-900/50",
                Div(:class => "w-10 h-10 rounded-lg bg-accent-secondary-100 dark:bg-accent-secondary-900/50 flex items-center justify-center mb-4",
                    RawHtml("""<svg class="w-5 h-5 text-accent-secondary-600 dark:text-accent-secondary-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="10"/></svg>""")
                ),
                H3(:class => "font-semibold mb-2 text-warm-900 dark:text-warm-100", "Proven Before Shipping"),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm leading-relaxed",
                    "Every island passes an export-time differential oracle: byte-exact agreement with real notebook re-runs on sampled bond values. Mismatches degrade to the classic fallbacks — nothing ships unverified.")
            ),
            Div(:class => "border border-warm-200 dark:border-warm-800 rounded-lg p-6 bg-white shadow-sm dark:shadow-none dark:bg-warm-900/50",
                Div(:class => "w-10 h-10 rounded-lg bg-accent-100 dark:bg-accent-900/50 flex items-center justify-center mb-4",
                    RawHtml("""<svg class="w-5 h-5 text-accent-600 dark:text-accent-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>""")
                ),
                H3(:class => "font-semibold mb-2 text-warm-900 dark:text-warm-100", "Stock Pluto Frontend"),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm leading-relaxed",
                    "No Pluto fork. A fetch-interception shim answers the standard slider-server protocol in-tab; per-group fallbacks pass through to precomputed files or a live server.")
            )
        )
    )
end
