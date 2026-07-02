() -> begin
    base = get(ENV, "SNAPDOCS_BASE", "")

    feature(icon_svg, title, body) = Div(:class => "bg-base-100 rounded-box sn-bubble p-6 space-y-3",
        Div(:class => "w-10 h-10 rounded-box bg-primary/10 text-primary flex items-center justify-center", RawHtml(icon_svg)),
        H3(:class => "sn-display text-lg font-semibold text-base-content", title),
        P(:class => "text-sm text-base-content/60 leading-relaxed", body))

    Div(:class => "space-y-20",
        # Hero
        Div(:class => "text-center space-y-6 pt-8",
            H1(:class => "sn-display text-5xl md:text-6xl font-semibold text-base-content leading-tight",
                "Pluto notebooks,"),
            H1(:class => "sn-display text-5xl md:text-6xl font-semibold text-primary leading-tight",
                "live as Therapy components."),
            P(:class => "text-lg text-base-content/60 max-w-2xl mx-auto leading-relaxed",
                "A ",
                A(:href => "https://plutojl.org", :target => "_blank", :class => "link link-primary", "Pluto.jl"),
                " notebook's ", Code(:class => "sn-mono text-primary", "@bind"),
                "-dependent cells compile to WebAssembly via ",
                A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank", :class => "link link-primary", "WasmTarget.jl"),
                " and ship as ", Strong("interactive islands"), " inside a lean Therapy page — ",
                "real reactive DOM, no Julia server, themeable, droppable into any site."),
            Div(:class => "flex gap-3 justify-center pt-2 flex-wrap",
                A(:href => "$(base)/notebooks/", :class => "btn btn-primary", "Browse the Notebooks"),
                A(:href => "$(base)/how-it-works/", :class => "btn btn-ghost", "How it works →")),
        ),
        # Quickstart
        Div(:class => "max-w-3xl mx-auto space-y-4",
            H2(:class => "sn-display text-2xl font-semibold text-base-content", "Quickstart"),
            Pre(:class => "bg-neutral text-neutral-content p-6 rounded-box overflow-x-auto sn-mono text-sm leading-relaxed",
                Code("""using Snapshot

# lean, themeable Therapy-component export — every compilable bond group
# ships as a WasmGC island, verified against the real notebook first
export_notebook("notebook.jl"; therapy=true)

# → notebook.html + notebook.islands/   (serve anywhere static)""")),
            P(:class => "text-sm text-base-content/60 leading-relaxed",
                "At export time the notebook runs once in Pluto. Each group of co-dependent ",
                Code(:class => "sn-mono", "@bind"),
                " variables becomes a small WasmGC module, verified two ways before shipping. In the browser a tiny runtime drives the islands from plain HTML inputs — no Pluto frontend, no multi-megabyte statefile.")),
        # Features
        Div(:class => "grid grid-cols-1 md:grid-cols-3 gap-5",
            feature("""<svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>""",
                "Instant interactivity",
                "Slider moves are local WASM calls — no network round-trip, no Julia process, no precompute explosion. Continuous + infinite bond domains work."),
            feature("""<svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="10"/></svg>""",
                "Proven before shipping",
                "Every island passes an export-time differential oracle: byte-exact agreement with real notebook re-runs on sampled bond values. Mismatches degrade gracefully."),
            feature("""<svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>""",
                "Native Therapy components",
                "No iframe. The notebook is real DOM in the page — inherits the site's DaisyUI theme, flows inline, reskins with one click.")),
    )
end
