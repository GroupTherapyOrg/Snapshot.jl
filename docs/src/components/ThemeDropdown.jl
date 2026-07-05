# Site-wide theme picker — a DaisyUI dropdown of every built-in DaisyUI theme,
# each row showing 3 swatch dots (primary/secondary/accent in that theme). Clicking
# sets data-theme on <html> (the whole site + every inline .snap-notebook reskins) and
# persists to localStorage 'snap-theme'. The click handler lives in Layout.jl (delegated).
# classic-light/classic-dark are custom themes defined in docs/input.css — 1:1 ports
# of Pluto's own light/dark palettes onto DaisyUI tokens; the rest are built-ins.

const _THEMES = [
    "classic-light", "classic-dark",
    "light", "dark", "cupcake", "bumblebee", "emerald", "corporate", "synthwave",
    "retro", "cyberpunk", "valentine", "halloween", "garden", "forest", "aqua",
    "lofi", "pastel", "fantasy", "wireframe", "black", "luxury", "dracula", "cmyk",
    "autumn", "business", "acid", "lemonade", "night", "coffee", "winter", "dim",
    "nord", "sunset", "caramellatte", "abyss", "silk",
]

function ThemeDropdown()
    rows = join([
        """<li><button type="button" class="justify-between" data-theme-name="$(t)"><span class="capitalize">$(titlecase(replace(t, "-" => " ")))</span><span class="flex w-16 h-5 rounded-md overflow-hidden ring-1 ring-base-content/20 shrink-0" data-theme="$(t)"><i class="flex-1" style="background:var(--color-base-100)"></i><i class="flex-1" style="background:var(--color-base-300)"></i><i class="flex-1" style="background:var(--color-primary)"></i><i class="flex-1" style="background:var(--color-secondary)"></i><i class="flex-1" style="background:var(--color-accent)"></i></span></button></li>"""
        for t in _THEMES
    ], "")
    Div(:class => "dropdown dropdown-end",
        RawHtml("""<div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-circle" title="Theme" aria-label="Theme"><svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.49 2 2 6.49 2 12s4.49 10 10 10c.93 0 1.68-.75 1.68-1.68 0-.43-.16-.83-.43-1.13-.27-.31-.43-.71-.43-1.13 0-.93.75-1.68 1.68-1.68H16c3.31 0 6-2.69 6-6 0-4.96-4.49-9-10-9zM6.5 13c-.83 0-1.5-.67-1.5-1.5S5.67 10 6.5 10 8 10.67 8 11.5 7.33 13 6.5 13zm3-4C8.67 9 8 8.33 8 7.5S8.67 6 9.5 6s1.5.67 1.5 1.5S10.33 9 9.5 9zm5 0c-.83 0-1.5-.67-1.5-1.5S13.67 6 14.5 6s1.5.67 1.5 1.5S15.33 9 14.5 9zm3 4c-.83 0-1.5-.67-1.5-1.5S16.67 10 17.5 10s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z"/></svg></div>"""),
        RawHtml("""<ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-30 mt-2 w-56 max-h-96 overflow-y-auto shadow-xl flex-nowrap p-2">$(rows)</ul>"""),
    )
end
