# NotebookPage — wraps an exported notebook in an iframe with Therapy chrome
# (breadcrumb back-link + source link + a DaisyUI theme picker), so notebooks
# open WITHIN the docs webapp instead of navigating away.
#
# The export is now the LEAN therapy=true page (SSR cells + wasm islands, no
# Pluto frontend / 2.6 MB statefile) — a true Therapy component. Its CSS reads
# DaisyUI --color-* tokens, so the theme picker reskins the WHOLE notebook by
# setting <html data-theme> inside the (same-origin) iframe. The choice persists
# in localStorage, which the notebook's own head script re-applies on every load
# → one picker themes every notebook seamlessly, like part of the docs site.

const _NOTEBOOK_GITHUB_BASE =
    "https://github.com/GroupTherapyOrg/PlutoIslands.jl/blob/main/test/notebooks/featured"

# snapshot/snapshot-dark = our brand themes; the rest are DaisyUI 5 built-ins
# (the notebook page already loads daisyui@5/themes.css).
const _NB_THEMES = [
    ("Snapshot", ["snapshot" => "Snapshot — light", "snapshot-dark" => "Snapshot — dark"]),
    ("DaisyUI", [t => t for t in [
        "light", "dark", "cupcake", "bumblebee", "emerald", "corporate", "synthwave",
        "retro", "cyberpunk", "valentine", "halloween", "garden", "forest", "aqua",
        "lofi", "pastel", "fantasy", "wireframe", "black", "luxury", "dracula", "cmyk",
        "autumn", "business", "acid", "lemonade", "night", "coffee", "winter", "dim",
        "nord", "sunset"]]),
]

function _theme_options_html()
    io = IOBuffer()
    for (group, opts) in _NB_THEMES
        print(io, "<optgroup label=\"", group, "\">")
        for (val, label) in opts
            print(io, "<option value=\"", val, "\">", label, "</option>")
        end
        print(io, "</optgroup>")
    end
    String(take!(io))
end

# Fully-INLINE handlers (no reliance on a <script> running — robust to the
# client router): the <select> applies + persists the theme; the iframe re-applies
# the saved theme and syncs the dropdown on load (same-origin contentDocument).
function _ThemePicker()
    RawHtml("""
    <label class="flex items-center gap-2 normal-case tracking-normal text-warm-500 dark:text-warm-400" title="Reskin this notebook — DaisyUI themes">
      <span aria-hidden="true">🎨</span><span>theme</span>
      <select id="pi-nb-theme"
        onchange="(function(t){try{localStorage.setItem('pi-theme',t)}catch(e){}var f=document.getElementById('pi-nb-frame');if(f){try{f.contentDocument.documentElement.setAttribute('data-theme',t)}catch(e){}}})(this.value)"
        class="bg-warm-100 dark:bg-warm-900 text-warm-700 dark:text-warm-300 border border-warm-300 dark:border-warm-700 rounded-md px-2 py-1 cursor-pointer font-sans">
        $(_theme_options_html())
      </select>
    </label>""")
end

function NotebookPage(slug::AbstractString, title::AbstractString, html_name::AbstractString, status::AbstractString, islands::Int, cells_interactive::Int=0, cells_total::Int=0)
    base = get(ENV, "PIDOCS_BASE", "")
    badge = status == "interactive" ?
        Span(:class => "px-2 py-0.5 rounded-full bg-accent-100 dark:bg-accent-900/50 text-accent-700 dark:text-accent-300 normal-case tracking-normal",
            cells_total > 0 ? "🏝️ $(cells_interactive)/$(cells_total) cells interactive — sliders need no server" :
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
            Div(:class => "flex items-center gap-4",
                _ThemePicker(),
                A(:href => "$(_NOTEBOOK_GITHUB_BASE)/$(replace(slug, " " => "%20")).jl", :target => "_blank", :rel => "noopener",
                    :class => "flex items-center gap-2 px-3 py-1.5 rounded-full border border-warm-300 dark:border-warm-700 hover:border-accent-400 dark:hover:border-accent-600 hover:text-accent-600 dark:hover:text-accent-400 transition-colors no-underline",
                    Span(".jl source"),
                ),
            ),
        ),
        # The lean Therapy notebook, same-origin. Its own head script applies the
        # saved theme; this onload re-applies it + syncs the picker (belt + braces).
        Iframe(
            :id => "pi-nb-frame",
            :src => "$(base)/notebooks-static/$(replace(html_name, " " => "%20"))",
            :class => "w-full h-[calc(100vh-9rem)] border border-warm-200 dark:border-warm-800 rounded-lg bg-warm-50",
            :loading => "eager",
            :title => title,
            :onload => "try{var d=this.contentDocument;if(!d)return;var t=null;try{t=localStorage.getItem('pi-theme')}catch(e){}if(t){d.documentElement.setAttribute('data-theme',t);var s=document.getElementById('pi-nb-theme');if(s)s.value=t;}}catch(e){}",
        ),
    )
end
