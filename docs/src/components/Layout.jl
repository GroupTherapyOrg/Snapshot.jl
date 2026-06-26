const PIDOCS_BASE = get(ENV, "PIDOCS_BASE", "")
const REPO_URL = "https://github.com/GroupTherapyOrg/PlutoIslands.jl"

"""PlutoIslands.jl wordmark — serif, with the tri-color .jl suffix."""
function PIWordmark()
    A(:href => "$(PIDOCS_BASE)/", :class => "flex items-center gap-2 group no-underline",
        RawHtml("""<svg width="24" height="24" viewBox="0 0 100 100" aria-hidden="true" class="transition-transform duration-200 group-hover:-translate-y-0.5"><g transform="translate(-3 0)"><rect x="18" y="15" width="50" height="50" rx="11" fill="var(--color-base-100)" stroke="currentColor" stroke-width="5"/><rect x="30" y="27" width="50" height="50" rx="11" fill="var(--color-base-100)" stroke="currentColor" stroke-width="5"/><rect x="42" y="39" width="50" height="50" rx="11" fill="var(--color-primary)" stroke="currentColor" stroke-width="5"/></g></svg>"""),
        RawHtml("""<span class="sn-display text-xl font-semibold text-base-content">PlutoIslands<span class="text-primary">.</span><span class="text-secondary">j</span><span class="text-accent">l</span></span>"""),
    )
end

function Layout(content)
    base = PIDOCS_BASE
    Fragment(
        # npm-built Tailwind+DaisyUI stylesheet (Therapy tailwind=false), served via the
        # assets/ staticfiles route (base-path aware, works dev + GH Pages build).
        RawHtml("""<link rel="stylesheet" href="$(base)/assets/styles.css">"""),
        # theme init (before paint): ?theme= → saved 'pi-theme' → system prefers-dark → light
        RawHtml("""<script>(function(){try{var u=new URLSearchParams(location.search).get('theme');var s=localStorage.getItem('pi-theme');var dk=window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches;var t=u||s||(dk?'dark':'light');document.documentElement.setAttribute('data-theme',t);if(u){try{localStorage.setItem('pi-theme',u)}catch(e){}}if(window.matchMedia){var mq=window.matchMedia('(prefers-color-scheme: dark)');var f=function(e){if(!localStorage.getItem('pi-theme'))document.documentElement.setAttribute('data-theme',e.matches?'dark':'light');};if(mq.addEventListener)mq.addEventListener('change',f);}}catch(e){}})();</script>"""),
        RawHtml("""<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400..700;1,9..144,400..600&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">"""),
        Div(:class => "min-h-screen flex flex-col",
            Header(:class => "sn-topbar sticky top-0 z-30",
                Div(:class => "w-full max-w-6xl mx-auto px-5 sm:px-8 h-16 flex items-center justify-between",
                    PIWordmark(),
                    Nav(:class => "flex items-center gap-3 sm:gap-5",
                        A(:href => "$(base)/how-it-works/", :class => "text-sm text-base-content/60 hover:text-primary transition-colors no-underline hidden sm:inline", "How it works"),
                        A(:href => "$(base)/notebooks/", :class => "text-sm text-base-content/60 hover:text-primary transition-colors no-underline", "Notebooks"),
                        A(:href => REPO_URL, :target => "_blank", :class => "text-base-content/50 hover:text-base-content/80 transition-colors",
                            RawHtml("""<svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>"""),
                        ),
                        ThemeDropdown(),
                    ),
                ),
            ),
            MainEl(:id => "page-content", :class => "flex-1 w-full max-w-6xl mx-auto px-5 sm:px-8 py-10 sm:py-14",
                content
            ),
            Footer(:class => "w-full max-w-6xl mx-auto px-5 sm:px-8 py-12 text-center space-y-2",
                P(:class => "text-sm text-base-content/60",
                    "Pluto notebooks as lean Therapy components — interactive WebAssembly, no server."),
                P(:class => "text-xs text-base-content/40",
                    A(:href => REPO_URL, :target => "_blank", :class => "hover:text-base-content/70 no-underline", "a fork of JuliaPluto/PlutoIslands.jl"),
                    Span(:class => "mx-2", "·"),
                    A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank", :class => "hover:text-base-content/70 no-underline", "WasmTarget.jl"),
                    Span(:class => "mx-2", "·"),
                    A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :target => "_blank", :class => "hover:text-base-content/70 no-underline", "Therapy.jl"),
                    Span(:class => "mx-2", "·"),
                    A(:href => "https://plutojl.org", :target => "_blank", :class => "hover:text-base-content/70 no-underline", "Pluto.jl")),
            ),
        ),
        # theme-picker click → set data-theme on <html> (whole site + every inline
        # notebook) + persist. Delegated on document so it survives SPA swaps.
        RawHtml("""<script>(function(){if(window.__piThemeWired)return;window.__piThemeWired=1;document.addEventListener('click',function(e){var b=e.target.closest('[data-theme-name]');if(!b)return;var t=b.getAttribute('data-theme-name');document.documentElement.setAttribute('data-theme',t);try{localStorage.setItem('pi-theme',t)}catch(e){}document.querySelectorAll('.pi-notebook').forEach(function(n){n.setAttribute('data-theme',t)});if(document.activeElement&&document.activeElement.blur)document.activeElement.blur();});})();</script>"""),
    )
end
