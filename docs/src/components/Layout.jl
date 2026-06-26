const PIDOCS_BASE = get(ENV, "PIDOCS_BASE", "")
const REPO_URL = "https://github.com/GroupTherapyOrg/PlutoIslands.jl"

"""PlutoIslands.jl wordmark with colored .jl suffix (Therapy docs style)"""
function PIWordmark()
    NavLink("$(PIDOCS_BASE)/",
        RawHtml("""PlutoIslands<span style="color:var(--jl-dot)">.</span><span style="color:var(--jl-j)">j</span><span style="color:var(--jl-l)">l</span>""");
        class = "text-xl font-serif font-bold text-warm-900 dark:text-warm-100 hover:opacity-80 transition-opacity no-underline",
        active_class = ""
    )
end

# DaisyUI theme picker in the docs chrome — a CLEAR demo that the inline notebooks
# (.pi-notebook) re-theme natively: one select sets data-theme on every notebook on
# the page AND persists the choice (each notebook's own load script re-applies it).
function NotebookThemePicker()
    RawHtml(raw"""
    <label class="hidden sm:flex items-center gap-1.5 text-xs text-warm-500 dark:text-warm-400" title="Re-theme the notebooks — DaisyUI themes">
      <span aria-hidden="true">🎨</span>
      <select id="pi-docs-theme" aria-label="Notebook theme"
        onchange="(function(t){try{localStorage.setItem('pi-theme',t)}catch(e){}document.querySelectorAll('.pi-notebook').forEach(function(n){n.setAttribute('data-theme',t)})})(this.value)"
        class="bg-warm-100 dark:bg-warm-900 text-warm-700 dark:text-warm-300 border border-warm-300 dark:border-warm-700 rounded-md px-1.5 py-1 cursor-pointer">
        <optgroup label="Snapshot"><option value="snapshot">Snapshot light</option><option value="snapshot-dark">Snapshot dark</option></optgroup>
        <optgroup label="DaisyUI"><option>light</option><option>dark</option><option>cupcake</option><option>bumblebee</option><option>emerald</option><option>corporate</option><option>synthwave</option><option>retro</option><option>cyberpunk</option><option>valentine</option><option>halloween</option><option>garden</option><option>forest</option><option>aqua</option><option>lofi</option><option>pastel</option><option>fantasy</option><option>wireframe</option><option>black</option><option>luxury</option><option>dracula</option><option>cmyk</option><option>autumn</option><option>business</option><option>acid</option><option>lemonade</option><option>night</option><option>coffee</option><option>winter</option><option>dim</option><option>nord</option><option>sunset</option></optgroup>
      </select>
    </label>
    <script>/* __therapy: sync the picker to the saved theme */(function(){try{var t=localStorage.getItem('pi-theme');var s=document.getElementById('pi-docs-theme');if(s&&t)s.value=t;if(t)document.querySelectorAll('.pi-notebook').forEach(function(n){n.setAttribute('data-theme',t)});}catch(e){}})();</script>
    """)
end

function Layout(content)
    Div(:class => "min-h-screen flex flex-col bg-warm-100 dark:bg-warm-950 text-warm-800 dark:text-warm-200 transition-colors",
        Nav(:class => "sticky top-0 z-40 border-b border-warm-200 dark:border-warm-800 h-16 px-6 bg-warm-100/80 dark:bg-warm-950/80 backdrop-blur supports-[backdrop-filter]:bg-warm-100/60 supports-[backdrop-filter]:dark:bg-warm-950/60",
            Div(:class => "max-w-5xl mx-auto h-full flex items-center justify-between",
                PIWordmark(),
                Div(:class => "flex items-center gap-6",
                    NavLink("$(PIDOCS_BASE)/how-it-works/", "How it works";
                        class = "text-sm transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium",
                        inactive_class = "text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400"
                    ),
                    NavLink("$(PIDOCS_BASE)/notebooks/", "Notebooks";
                        class = "text-sm transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium",
                        inactive_class = "text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400"
                    ),
                    A(:href => REPO_URL, :target => "_blank",
                        :class => "text-warm-600 dark:text-warm-400 hover:text-warm-700 dark:hover:text-warm-300 transition-colors",
                        RawHtml("""<svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>""")
                    ),
                    NotebookThemePicker(),
                    DarkModeToggle()
                )
            )
        ),
        MainEl(:id => "page-content", :class => "flex-1 w-full max-w-5xl mx-auto px-6 py-12",
            content
        ),
        Footer(:class => "border-t border-warm-200 dark:border-warm-800 px-6 py-6",
            Div(:class => "max-w-5xl mx-auto flex items-center justify-between",
                A(:href => "https://github.com/JuliaPluto/PlutoIslands.jl", :target => "_blank",
                    :class => "text-sm text-warm-600 dark:text-warm-400 hover:text-warm-700 dark:hover:text-warm-300 transition-colors no-underline",
                    "a fork of JuliaPluto/PlutoIslands.jl"
                ),
                Div(:class => "flex items-center gap-2 text-sm text-warm-500 dark:text-warm-500",
                    A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank",
                        :class => "hover:text-warm-600 dark:hover:text-warm-300 transition-colors no-underline", "WasmTarget.jl"),
                    Span("/"),
                    A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :target => "_blank",
                        :class => "hover:text-warm-600 dark:hover:text-warm-300 transition-colors no-underline", "Therapy.jl"),
                    Span("/"),
                    A(:href => "https://plutojl.org", :target => "_blank",
                        :class => "hover:text-warm-600 dark:hover:text-warm-300 transition-colors no-underline", "Pluto.jl")
                ),
                P(:class => "text-sm text-warm-500 dark:text-warm-500",
                    "Built with ",
                    RawHtml("""<span class="font-serif">Therapy<span style="color:var(--jl-dot)">.</span><span style="color:var(--jl-j)">j</span><span style="color:var(--jl-l)">l</span></span>""")
                )
            )
        )
    )
end
