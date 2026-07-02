# pluto_css.jl — AUTO-DERIVE Pluto's output CSS, re-themed to DaisyUI tokens.
#
# PLUTO_OUTPUT_CSS is generated at PRECOMPILE time, so it auto-resyncs whenever
# Pluto/PlutoUI (deps) are bumped (Snapshot recompiles). Editing the committed
# pluto-base.css snapshot needs a forced recompile (touch a .jl) to take effect.
#
# The lean export renders cell output.body using Pluto's OWN stylesheets. Rather
# than hand-maintain a copy, we assemble it here from Pluto's frontend source +
# PlutoUI, and remap EVERY Pluto colour variable to a DaisyUI --color-* token via
# PLUTO_VAR_MAP. A completeness GUARD scans the assembled CSS and fails loud (warns
# + sensible default) for any Pluto var that isn't mapped, so it can never silently
# drift / fall back to Pluto's hard-coded colours.
#
#   sources (auto-synced from the installed Pluto/PlutoUI):
#     - ansi-colors.css   (stdout / terminal colour)        ← Pluto frontend
#     - highlightjs.css   (code syntax highlight in output)  ← Pluto frontend
#     - error.css         (jlerror / error cell display)     ← Pluto frontend
#     - assets/pluto-base.css = editor.css pluto-output rules + treeview.css
#       (array/dict/tree) + PlutoUI TableOfContents — snapshot of Pluto's output
#       rules (regenerate via write_pluto_base() on a Pluto bump).
#   Editor-chrome files (binder/hide-ui/welcome/featured-card/index/all-styles) are
#   intentionally excluded — they style the editor, not cell output.

# Pluto colour/feature variable → DaisyUI expression. Source of truth for theming.
const PLUTO_VAR_MAP = Dict{String,String}(
    # fonts + misc (non-colour)
    "--system-ui-font-stack" => raw"""ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif""",
    "--julia-mono-font-stack" => raw""""JuliaMono", ui-monospace, "SF Mono", Menlo, monospace""",
    "--roboto-mono-font-stack" => raw""""Roboto Mono", ui-monospace, Menlo, monospace""",
    "--inter-ui-font-stack" => "var(--system-ui-font-stack)",
    "--system-fonts-mono" => "var(--julia-mono-font-stack)",
    "--pluto-cell-spacing" => "12px",
    "--image-filters" => "none",
    "--before-content" => "\"\"",
    # surfaces / text
    "--main-bg-color" => "var(--color-base-100)",
    "--pluto-output-bg-color" => "var(--color-base-100)",
    "--pluto-output-color" => "var(--color-base-content)",
    "--pluto-output-h-color" => "var(--color-base-content)",
    "--rule-color" => "var(--color-base-300)",
    "--cursor-color" => "var(--color-base-content)",
    "--black" => "var(--color-base-content)",
    "--white" => "var(--color-base-100)",
    "--gray" => "color-mix(in oklab, var(--color-base-content) 50%, transparent)",
    # links / quotes / code
    "--a-underline" => "color-mix(in oklab, var(--color-primary) 45%, transparent)",
    "--blockquote-color" => "color-mix(in oklab, var(--color-base-content) 65%, transparent)",
    "--blockquote-bg" => "var(--color-base-200)",
    "--code-background" => "var(--color-base-200)",
    "--code-section-bg-color" => "var(--color-base-200)",
    "--kbd-border-color" => "var(--color-base-300)",
    # tables / footnotes
    "--table-border-color" => "var(--color-base-300)",
    "--table-bg-hover-color" => "var(--color-base-200)",
    "--footnote-border-color" => "var(--color-base-300)",
    # trees / schema / logs
    "--pluto-tree-color" => "color-mix(in oklab, var(--color-base-content) 60%, transparent)",
    "--pluto-schema-types-color" => "color-mix(in oklab, var(--color-base-content) 55%, transparent)",
    "--pluto-schema-types-border-color" => "var(--color-base-300)",
    "--pluto-logs-key-color" => "color-mix(in oklab, var(--color-base-content) 60%, transparent)",
    "--pkg-terminal-border-color" => "var(--color-base-300)",
    # admonitions (Pluto/Documenter !!! note/info/warning/danger/debug)
    "--admonition-title-color" => "var(--color-primary-content)",
    "--jl-message-color" => "color-mix(in oklab, var(--color-success, #16a34a) 16%, var(--color-base-100))",
    "--jl-message-accent-color" => "var(--color-success, #16a34a)",
    "--jl-info-color" => "color-mix(in oklab, var(--color-info, #3b82f6) 14%, var(--color-base-100))",
    "--jl-info-acccolor" => "color-mix(in oklab, var(--color-info, #3b82f6) 14%, var(--color-base-100))",
    "--jl-info-accent-color" => "var(--color-info, #3b82f6)",
    "--jl-warn-color" => "color-mix(in oklab, var(--color-warning, #d97706) 16%, var(--color-base-100))",
    "--jl-warn-accent-color" => "var(--color-warning, #d97706)",
    "--jl-danger-color" => "color-mix(in oklab, var(--color-error, #dc2626) 14%, var(--color-base-100))",
    "--jl-danger-accent-color" => "var(--color-error, #dc2626)",
    "--jl-debug-color" => "color-mix(in oklab, var(--color-secondary, #7c3aed) 14%, var(--color-base-100))",
    "--jl-debug-accent-color" => "var(--color-secondary, #7c3aed)",
    "--pluto-logs-debug-color" => "color-mix(in oklab, var(--color-secondary, #7c3aed) 14%, var(--color-base-100))",
    # error cell (jlerror)
    "--jlerror-header-color" => "var(--color-error, #dc2626)",
    "--jlerror-mark-bg-color" => "var(--color-base-200)",
    "--jlerror-mark-color" => "var(--color-base-content)",
    "--jlerror-a-bg-color" => "color-mix(in oklab, var(--color-warning, #d97706) 14%, var(--color-base-100))",
    "--jlerror-a-border-left-color" => "var(--color-error, #dc2626)",
    # code-token colours (highlightjs / CodeMirror) — match the Lezer tok-* palette
    "--cm-color-variable" => "var(--color-base-content)",
    "--cm-color-editor-text" => "var(--color-base-content)",
    "--cm-color-type" => "var(--color-info, #0891b2)",
    "--cm-color-builtin" => "var(--color-info, #0891b2)",
    "--cm-color-keyword" => "#8b5cf6",
    "--cm-color-comment" => "color-mix(in oklab, var(--color-base-content) 50%, transparent)",
    "--cm-color-string" => "#16a34a",
    "--cm-color-literal" => "#d97706",
    "--cm-color-symbol" => "#d97706",
    "--cm-color-macro" => "#db2777",
    "--cm-color-line-numbers" => "color-mix(in oklab, var(--color-base-content) 50%, transparent)",
    "--cm-highlighted" => "color-mix(in oklab, var(--color-primary) 15%, transparent)",
    "--cm-color-clickable-underline" => "var(--color-primary)",
    "--docs-binding-bg" => "color-mix(in oklab, var(--color-base-content) 4%, transparent)",
    # ANSI terminal colours (stdout) → DaisyUI semantic tokens (theme-aware)
    "--ansi-black" => "var(--color-base-content)",
    "--ansi-red" => "var(--color-error, #dc2626)",
    "--ansi-green" => "var(--color-success, #16a34a)",
    "--ansi-yellow" => "var(--color-warning, #d97706)",
    "--ansi-blue" => "var(--color-info, #3b82f6)",
    "--ansi-magenta" => "var(--color-secondary, #7c3aed)",
    "--ansi-cyan" => "var(--color-accent, #0891b2)",
    "--ansi-white" => "color-mix(in oklab, var(--color-base-content) 35%, var(--color-base-100))",
    "--ansi-bright-black" => "color-mix(in oklab, var(--color-base-content) 60%, transparent)",
    "--ansi-bright-red" => "var(--color-error, #ef4444)",
    "--ansi-bright-green" => "var(--color-success, #22c55e)",
    "--ansi-bright-yellow" => "var(--color-warning, #eab308)",
    "--ansi-bright-blue" => "var(--color-info, #60a5fa)",
    "--ansi-bright-magenta" => "var(--color-secondary, #a855f7)",
    "--ansi-bright-cyan" => "var(--color-accent, #22d3ee)",
    "--ansi-bright-white" => "var(--color-base-content)",
    # misc treeview / ToC / error vars (incl. NON-colour ones the guard can't default)
    "--bg" => "var(--color-base-100)",
    "--br" => "0.4rem",
    "--crop" => "0",
    "--icon-filter" => "none",
    "--gray1" => "color-mix(in oklab, var(--color-base-content) 45%, transparent)",
    "--cm-var-color" => "var(--color-base-content)",
    "--sidebar-li-active-bg" => "color-mix(in oklab, var(--color-primary) 12%, transparent)",
)

"""Literal colours Pluto baked into the included CSS as hex/rgb (NOT via a var, so the
var-map can't catch them) → DaisyUI tokens, so they stay theme-aware."""
const HARDCODED_COLOR_MAP = Dict{String,String}(
    "#ff002d42" => "color-mix(in oklab, var(--color-error) 26%, transparent)",       # error.css stacktrace left bar
    "#c7c7c7" => "color-mix(in oklab, var(--color-base-content) 22%, transparent)",   # error.css gray
)

"Strip @charset / @import lines (invalid inside an inlined <style>)."
_strip_at_rules(css::AbstractString) =
    replace(css, r"^[ \t]*@charset[^;\n]*;?[ \t]*\n?"m => "", r"^[ \t]*@import[^;\n]*;?[ \t]*\n?"m => "")

"""
    generate_pluto_output_css() -> String

Assemble Pluto's output CSS (re-themed to DaisyUI) from Pluto/PlutoUI source, with
a completeness guard: every `var(--x)` used (excluding DaisyUI's own --color-*/
--radius* tokens) must be defined by PLUTO_VAR_MAP, else it's defaulted + warned.
"""
function generate_pluto_output_css()
    pf = joinpath(pkgdir(Pluto), "frontend")
    base = read(joinpath(@__DIR__, "..", "assets", "pluto-base.css"), String)
    src(name) = isfile(joinpath(pf, name)) ? _strip_at_rules(read(joinpath(pf, name), String)) : ""
    # error.css has a few BARE element rules (notably `pre { border-left: 8px solid
    # #ff002d42 }` — the stacktrace red bar) that leak onto normal code blocks. Scope
    # them to `jlerror …` so they only style real error output, not .pl-code / markdown.
    err = replace(src("error.css"), r"^([ \t]*)(pre|code)\b"m => s"\1jlerror \2")
    body = join([
        base,
        "/* ── ansi-colors.css (stdout colour) ── */", src("ansi-colors.css"),
        "/* ── highlightjs.css (code highlight in output) ── */", src("highlightjs.css"),
        "/* ── error.css (jlerror / error cell, bare pre/code scoped) ── */", err,
    ], "\n\n")

    # Re-theme HARDCODED colours the var-map can't catch (it only rewrites var(--x)).
    hc_mapped = 0
    for (lit, repl) in HARDCODED_COLOR_MAP
        occursin(lit, body) || continue
        body = replace(body, lit => repl)
        hc_mapped += 1
    end

    # completeness guard
    used = Set{String}()
    for m in eachmatch(r"var\((--[a-zA-Z0-9-]+)", body)
        push!(used, String(m.captures[1]))
    end
    varmap = copy(PLUTO_VAR_MAP)
    defaulted = String[]
    for v in sort(collect(used))
        (startswith(v, "--color-") || startswith(v, "--radius")) && continue
        haskey(varmap, v) && continue
        d = occursin("bg", v) ? "var(--color-base-100)" :
            occursin(r"border|rule|line", v) ? "var(--color-base-300)" :
            occursin(r"font|stack", v) ? "var(--system-ui-font-stack)" :
            "var(--color-base-content)"
        varmap[v] = d
        push!(defaulted, v)
    end
    isempty(defaulted) ||
        @warn "Pluto→DaisyUI: $(length(defaulted)) var(s) defaulted — add to PLUTO_VAR_MAP" defaulted
    @info "Pluto→DaisyUI CSS: $(length(varmap) - length(defaulted))/$(length(used)) Pluto vars mapped, $(length(defaulted)) defaulted"

    # surface any HARDCODED colours remaining in property VALUES (var-definition lines
    # like `--ansi-red: rgb(...)` are overridden by the :root map above → skip them).
    # This class of issue was previously silent (the var-only mapper missed literal hex/rgb).
    hc_remaining = String[]
    for line in eachsplit(body, '\n')
        startswith(strip(line), "--") && continue
        for m in eachmatch(r"#[0-9a-fA-F]{6,8}\b|rgba?\([0-9 ,.%]+\)", line)
            push!(hc_remaining, m.match)
        end
    end
    isempty(hc_remaining) ||
        @warn "Pluto→DaisyUI: $(length(hc_remaining)) hardcoded colour(s) remain in values (add to HARDCODED_COLOR_MAP if they affect visible output)" sample = first(hc_remaining, 6)
    @info "Pluto→DaisyUI hardcoded colours: $hc_mapped mapped, $(length(hc_remaining)) remaining"

    io = IOBuffer()
    println(io, "/* AUTO-GENERATED by src/pluto_css.jl — Pluto's output CSS re-themed to DaisyUI.")
    println(io, "   Every Pluto colour var below → a DaisyUI --color-* token. Do not hand-edit;")
    println(io, "   edit PLUTO_VAR_MAP / pluto-base.css and regenerate (write_pluto_css()). */")
    println(io, ":root {")
    for k in sort(collect(keys(varmap)))
        println(io, "  ", k, ": ", varmap[k], ";")
    end
    println(io, "}")
    string(String(take!(io)), "\n", body)
end

# Generated ONCE at module load (not per notebook).
const PLUTO_OUTPUT_CSS = generate_pluto_output_css()

"Write the generated CSS to assets/pluto-output.css (a committed snapshot)."
write_pluto_css() = write(joinpath(@__DIR__, "..", "assets", "pluto-output.css"), PLUTO_OUTPUT_CSS)
