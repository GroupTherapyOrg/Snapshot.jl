# islands/extract.jl — M1: bond-group → compilable Julia function extraction
#
# For each bond-connection group, find the cells that depend on its bonds and
# turn EACH dependent cell into a self-contained Julia function
#
#     cellbody_<id>(bond₁::T₁, bond₂::T₂, …) :: String
#
# that recomputes the cell's OUTPUT BODY string from bond values alone:
#   - bond variables become typed parameters (types observed from the live
#     workspace, where the notebook has already run with initial bond values);
#   - the transitive upstream cell code the target needs is inlined, in
#     topological order (struct/import/using/const cells are hoisted into a
#     module-level `preamble` instead — they can't live in a function body);
#   - recursion stops at @bind cells: bonds are parameters, not code;
#   - the body string is produced per the cell's original mime:
#       text/plain          → string(value)
#       text/html (md"…")   → sentinel-spliced static skeleton + string(slots)
#
# Extraction is *judged*: anything outside the supported shape marks the cell
# plan (and its group) not-ok with a reason. Compilation (M2) and the
# differential oracle (M4) judge further. Nothing silently degrades.

import Pluto
import Pluto: Notebook, Cell, ServerSession
import PlutoDependencyExplorer
import UUIDs: UUID
import WasmTarget


# ─────────────────────────────────────────────────────────────────────────────
# Result types
# ─────────────────────────────────────────────────────────────────────────────

Base.@kwdef struct CellPlan
    cell_id::UUID
    mime::String
    export_name::String
    fn_expr::Union{Expr,Nothing}     # function (bonds…) … end — nothing if !ok
    ok::Bool
    reasons::Vector{String} = String[]
    # :string — fn returns the body string; :tree — fn returns the raw value,
    # rendered into Pluto's tree+object body via the bridge read-side walker
    body_kind::Symbol = :string
end

Base.@kwdef struct ExtractedGroup
    bond_names::Vector{Symbol}             # sorted
    arg_types::Vector{DataType}            # observed from workspace, same order
    initial_values::Vector{Any}            # current (=initial) workspace values
    preamble::Vector{Expr}                 # struct/import/using/const cell exprs
    cell_plans::Vector{CellPlan}           # one per dependent cell, topo order
    ok::Bool
    reasons::Vector{String} = String[]
    # true when some workspace value was `missing` (headless run of a widget
    # without initial_value) and we synthesized initials from
    # possible_bond_values. Original bodies are then missing-tainted and NOT
    # reproducible — skip initial-body verification, trust the oracle.
    synthetic_initials::Bool = false
    # per-bond sampling domains for the oracle; `nothing` = use
    # possible_bond_values. Populated by HTML-widget introspection.
    domains::Vector{Any} = Any[]
end

is_ok(g::ExtractedGroup) = g.ok && all(p -> p.ok, g.cell_plans)

# ─────────────────────────────────────────────────────────────────────────────
# Cell classification helpers
# ─────────────────────────────────────────────────────────────────────────────

"Does this cell's code contain a @bind macrocall?"
is_bind_cell(cell::Cell) = occursin("@bind", cell.code)

"Top-level expr kinds that must live at module level, not in a function body."
function _is_preamble_expr(ex)
    ex isa Expr || return false
    ex.head in (:struct, :abstract, :primitive, :import, :using, :module) && return true
    ex.head === :macrocall && return false
    if ex.head === :const
        return true
    end
    false
end

"Split a cell's parsed expr into (preamble_exprs, body_exprs)."
function _split_preamble(ex)
    pre, body = Expr[], Any[]
    exprs = (ex isa Expr && ex.head === :block) ? ex.args : [ex]
    for sub in exprs
        sub isa LineNumberNode && continue
        if _is_preamble_expr(sub)
            push!(pre, sub)
        else
            push!(body, sub)
        end
    end
    (pre, body)
end

function _parse_cell(cell::Cell)
    ex = Meta.parse(cell.code; raise=false)
    if ex isa Expr && ex.head in (:error, :incomplete)
        return nothing
    end
    ex
end

# ─────────────────────────────────────────────────────────────────────────────
# Dependency walking
# ─────────────────────────────────────────────────────────────────────────────

"Cells (excluding bind cells) whose definitions `cell` transitively needs."
function _upstream_closure(topology, cell::Cell)::Vector{Cell}
    seen = Set{Cell}()
    frontier = [cell]
    while !isempty(frontier)
        c = pop!(frontier)
        refs = topology.nodes[c].references
        ups = PlutoDependencyExplorer.where_assigned(topology, refs)
        for u in ups
            (u === cell || u in seen) && continue
            is_bind_cell(u) && continue   # bonds are parameters — stop here
            push!(seen, u)
            push!(frontier, u)
        end
    end
    order = PlutoDependencyExplorer.topological_order(topology, collect(seen))
    [c for c in order.runnable if c in seen]
end

"All cells downstream of the group's bonds (the cells an island must repaint)."
function _dependent_cells(topology, bond_names::Vector{Symbol})::Vector{Cell}
    first_layer = PlutoDependencyExplorer.where_referenced(topology, Set(bond_names))
    rest = Pluto.MoreAnalysis.downstream_recursive(topology, first_layer)
    chain = union(Set(first_layer), rest)
    order = PlutoDependencyExplorer.topological_order(topology, collect(chain))
    [c for c in order.runnable if c in chain]
end

# ─────────────────────────────────────────────────────────────────────────────
# md"…" sentinel splicing (Tier-2)
# ─────────────────────────────────────────────────────────────────────────────

const _SLOT = "QQXISLANDSLOT"   # survives markdown rendering verbatim

"""
Replace every `\$(expr)` / `\$var` interpolation in the RAW source of an
md\"…\" cell with a sentinel, returning (sentineled_code, slot_exprs).
"""
function _sentinelize_interpolations(code::String)
    slots = Expr[]
    out = IOBuffer()
    i = firstindex(code)
    n = lastindex(code)
    while i <= n
        c = code[i]
        if c == '$' && i < n
            j = nextind(code, i)
            if code[j] == '('
                # balanced-paren expression
                depth = 0
                k = j
                while k <= n
                    code[k] == '(' && (depth += 1)
                    code[k] == ')' && (depth -= 1)
                    depth == 0 && break
                    k = nextind(code, k)
                end
                inner = code[nextind(code, j):prevind(code, k)]
                ex = Meta.parse(inner; raise=false)
                push!(slots, ex isa Expr || ex isa Symbol ? Expr(:block, ex) : Expr(:block, ex))
                print(out, _SLOT, length(slots), "QQ")
                i = nextind(code, k)
                continue
            elseif code[j] == '_' || isletter(code[j])
                k = j
                while k <= n && (code[k] == '_' || isletter(code[k]) || isdigit(code[k]) || code[k] == '!')
                    k = nextind(code, k)
                end
                name = code[j:prevind(code, k)]
                push!(slots, Expr(:block, Symbol(name)))
                print(out, _SLOT, length(slots), "QQ")
                i = k
                continue
            end
        end
        print(out, c)
        i = nextind(code, i)
    end
    (String(take!(out)), slots)
end

"Is this cell a plain md\"…\" macrocall cell?"
function _is_md_cell(ex)
    ex isa Expr && ex.head === :macrocall && !isempty(ex.args) &&
        (ex.args[1] === Symbol("@md_str") ||
         (ex.args[1] isa GlobalRef && ex.args[1].name === Symbol("@md_str")))
end

"""
Render the sentineled markdown in the live workspace → HTML skeleton segments.
Returns `nothing` if rendering fails or sentinels were mangled.
"""
function _md_skeleton(session::ServerSession, notebook::Notebook, sentineled_code::String, n_slots::Int)
    render_expr = Meta.parse("repr(MIME\"text/html\"(), $(sentineled_code))"; raise=false)
    render_expr isa Expr && render_expr.head in (:error, :incomplete) && return nothing
    html = try
        Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook), render_expr)
    catch
        return nothing
    end
    html isa String || return nothing
    segments = String[]
    rest = html
    for k in 1:n_slots
        marker = "$(_SLOT)$(k)QQ"
        parts = split(rest, marker; limit=2)
        length(parts) == 2 || return nothing   # slot rendered non-verbatim
        push!(segments, String(parts[1]))
        rest = parts[2]
    end
    push!(segments, String(rest))
    segments
end

# ─────────────────────────────────────────────────────────────────────────────
# Per-cell plan
# ─────────────────────────────────────────────────────────────────────────────

"Rewrite a cell's body exprs so the cell's VALUE lands in `val_sym`."
function _capture_value!(stmts::Vector{Any}, body::Vector{Any}, val_sym::Symbol)
    isempty(body) && return false
    for (i, ex) in enumerate(body)
        last = i == length(body)
        if last
            if ex isa Expr && ex.head === :(=) && ex.args[1] isa Symbol
                push!(stmts, ex)
                push!(stmts, :($val_sym = $(ex.args[1])))
            else
                push!(stmts, :($val_sym = $ex))
            end
        else
            push!(stmts, ex)
        end
    end
    true
end

function _plan_cell(
    session::ServerSession,
    notebook::Notebook,
    topology,
    cell::Cell,
    bond_names::Vector{Symbol},
    arg_types::Vector{DataType},
    original_state::Dict,
)::Tuple{CellPlan,Vector{Expr}}
    id = cell.cell_id
    export_name = "cellbody_" * replace(string(id), "-" => "")[1:12]
    # cell_results is keyed by UUID in-process (notebook_to_js) but by String
    # after a msgpack round-trip (statefile) — accept either. Values may be
    # Pluto ImmutableMarker wrappers (AbstractDict with getindex but no get).
    _sget(d, k, default) = try d[k] catch; default end
    crs = _sget(original_state, "cell_results", Dict())
    cr = something(_sget(crs, id, nothing), _sget(crs, string(id), nothing), Some(nothing))
    mime = cr === nothing ? "?" : string(_sget(_sget(cr, "output", Dict()), "mime", "?"))

    fail(reasons...) = (CellPlan(; cell_id=id, mime, export_name, fn_expr=nothing, ok=false,
                                  reasons=collect(String, reasons)), Expr[])

    cr === nothing && return fail("cell has no output in original state")
    is_bind_cell(cell) && return fail("dependent cell re-defines a bond (bond-defines-bond) — unsupported in v0")

    ex = _parse_cell(cell)
    ex === nothing && return fail("cell failed to parse")

    # Gather upstream code (topo order), splitting out preamble exprs
    preamble = Expr[]
    stmts = Any[]
    for up in _upstream_closure(topology, cell)
        upex = _parse_cell(up)
        upex === nothing && return fail("upstream cell $(up.cell_id) failed to parse")
        pre, body = _split_preamble(upex)
        append!(preamble, pre)
        append!(stmts, body)
    end

    # The target cell itself → value capture + body strategy
    pre_t, body_t = _split_preamble(ex)
    append!(preamble, pre_t)
    val = gensym(:cellval)

    body_kind = :string
    body_string_expr = if mime == "text/html" && length(body_t) == 1 && _is_md_cell(body_t[1])
        sentineled, slots = _sentinelize_interpolations(cell.code)
        isempty(slots) && return fail("md cell with no interpolations should never re-run — why is it in the chain?")
        segments = _md_skeleton(session, notebook, sentineled, length(slots))
        segments === nothing && return fail("md skeleton render/split failed (non-verbatim slot?)")
        # seg₀ * string(slot₁) * seg₁ * … — as a LEFT-FOLD of binary `*`:
        # n-ary string `*` with ≥4 operands currently traps in WasmTarget
        # (`unreachable`); binary chains compile fine. See WASM_FINDINGS.md.
        parts = Any[segments[1]]
        for (k, slot) in enumerate(slots)
            push!(parts, :(string($slot)))
            push!(parts, segments[k + 1])
        end
        foldl((a, b) -> :($a * $b), parts)
    elseif mime == "text/plain"
        _capture_value!(stmts, body_t, val) || return fail("empty cell body")
        # Pluto's text/plain body is repr-flavoured: bare Strings render WITH
        # quotes/escapes. The function object is interpolated directly so the
        # sandbox eval resolves it regardless of module context.
        :($(_plain_body)($val))
    elseif mime == "text/html"
        # non-md HTML cells: support values that ARE html wrappers (html"…" →
        # Docs.HTML{String}) or raw strings; anything needing real show()
        # machinery probe-fails honestly at compile
        _capture_value!(stmts, body_t, val) || return fail("empty cell body")
        :($(_html_body)($val))
    elseif mime == "application/vnd.pluto.tree+object"
        _capture_value!(stmts, body_t, val) || return fail("empty cell body")
        # raw value out; compile-time discovers the concrete type and attaches
        # the bridge read descriptor (leaf/shape gates live in compile)
        body_kind = :tree
        val
    else
        return fail("unsupported output mime $(mime) in v0 (text/plain & md-text/html only)")
    end

    args = [Expr(:(::), n, t) for (n, t) in zip(bond_names, arg_types)]
    fn_expr = Expr(:function, Expr(:tuple, args...), Expr(:block, stmts..., :(return $body_string_expr)))

    (CellPlan(; cell_id=id, mime, export_name, fn_expr, ok=true, body_kind), preamble)
end

"text/html body for value-is-markup cells (html\"…\" wrappers, raw strings)."
_html_body(v::Base.Docs.HTML{String})::String = v.content
_html_body(v::AbstractString)::String = String(v)
# anything else needs show(io, MIME"text/html", v) — not wasm-compilable;
# typed to fail inference/probe rather than silently mis-render
_html_body(v) = error("text/html rendering of $(typeof(v)) unsupported")

"Pluto text/plain body semantics: strings repr-quoted, everything else string()."
_plain_body(x)::String = string(x)
# escape_string traps `unreachable` in wasm (WASM_FINDINGS #4) — replace-chain
# covers backslash+quote, the dominant cases; the oracle catches exotica.
_plain_body(s::String)::String =
    "\"" * replace(replace(s, "\\" => "\\\\"), "\"" => "\\\"") * "\""

# ─────────────────────────────────────────────────────────────────────────────
# Raw-HTML widget introspection — bonds with no initial_value/possible_values
# (plain `html"<input …>"` elements). Parse the widget's RENDERED html (the
# bond-defining cell's output body) the way Pluto's own frontend reads it:
# range/number → min:step:max numeric domain, checkbox → Bool. Gives these
# bonds a verifiable domain — the oracle samples it like any finite widget.
# ─────────────────────────────────────────────────────────────────────────────

function _widget_introspect(original_state, topology, bond_name::Symbol)
    cells = PlutoDependencyExplorer.where_assigned(topology, Set([bond_name]))
    isempty(cells) && return nothing
    _sget(d, k, default) = try d[k] catch; default end
    crs = _sget(original_state, "cell_results", Dict())
    id = cells[1].cell_id
    cr = something(_sget(crs, id, nothing), _sget(crs, string(id), nothing), Some(nothing))
    cr === nothing && return nothing
    body = _sget(_sget(cr, "output", Dict()), "body", nothing)
    body isa String || return nothing
    m = match(r"<input\b[^>]*>"i, body)
    m === nothing && return nothing
    tag = m.match
    attr(name) = (am = match(Regex("\\b$(name)\\s*=\\s*[\"']?([^\"'\\s>]+)", "i"), tag);
                  am === nothing ? nothing : String(am.captures[1]))
    typ = something(attr("type"), "text")
    if typ in ("range", "number")
        pnum(x, dflt) = x === nothing ? dflt : something(tryparse(Int64, x),
                                                         something(tryparse(Float64, x), dflt))
        lo = pnum(attr("min"), typ == "range" ? 0 : nothing)
        hi = pnum(attr("max"), typ == "range" ? 100 : nothing)
        st = pnum(attr("step"), 1)
        (lo === nothing || hi === nothing) && return nothing
        v0 = pnum(attr("value"), typ == "range" ? lo + div(hi - lo, 2) : lo)
        if lo isa Int64 && hi isa Int64 && st isa Int64 && v0 isa Int64
            return (initial=v0, domain=collect(lo:st:hi))
        else
            return (initial=Float64(v0), domain=collect(Float64(lo):Float64(st):Float64(hi)))
        end
    elseif typ == "checkbox"
        return (initial=attr("checked") !== nothing, domain=[false, true])
    end
    nothing   # text/select etc: no verifiable finite domain in v1
end

# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────

"""
    extract_groups(session, notebook; connections, original_state) -> Vector{ExtractedGroup}

Extract one island candidate per bond-connection group of `notebook` (which
must be running in `session`, with its initial run complete).
"""
function extract_groups(
    session::ServerSession,
    notebook::Notebook;
    connections::Dict{Symbol,Vector{Symbol}}=bound_variable_connections_graph(session, notebook),
    original_state::Dict=Pluto.notebook_to_js(notebook),
)::Vector{ExtractedGroup}
    topology = notebook.topology
    groups = sort(collect(Set(values(connections))); by=g -> string(sort(g)))

    map(filter(!isempty, groups)) do group
        bond_names = sort(group)

        # Observe types + initial values from the live workspace
        arg_types = DataType[]
        initial_values = Any[]
        reasons = String[]
        synthetic_initials = false
        domains = Any[]
        for n in bond_names
            fetch_failed = false
            v = try
                Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook), n)
            catch e
                fetch_failed = true   # un-serializable over the workspace boundary
                missing
            end
            bond_domain = nothing
            if v === missing
                # widget without initial_value, run headless — synthesize the
                # initial from the bond's domain (same source precompute trusts)
                domain = try
                    Pluto.possible_bond_values(session, notebook, n)
                catch e
                    Symbol("possible_bond_values failed: $(typeof(e))")
                end
                if domain isa Symbol || isempty(domain)
                    # last resort: read the widget's own rendered <input> html
                    wi = _widget_introspect(original_state, topology, n)
                    if wi !== nothing
                        v = wi.initial
                        bond_domain = wi.domain
                        synthetic_initials = true
                    else
                        push!(reasons, "bond $(n) is $(fetch_failed ? "unfetchable" : "missing") and has no usable possible_values ($(domain isa Symbol ? domain : "empty")) or introspectable widget html")
                    end
                else
                    v = first(domain)
                    synthetic_initials = true
                end
            end
            push!(domains, bond_domain)
            push!(initial_values, v)
            push!(arg_types, typeof(v))
            # the bridge marshals Int/UInt/Float/Bool/Char/String/Tuple/
            # NamedTuple/struct/Vector (nested) — anything outside is honest
            if !WasmTarget.Bridge.args_supported(typeof(v))
                push!(reasons, "bond $(n) value type $(typeof(v)) is outside the bridge universe")
            end
        end

        plans = CellPlan[]
        preamble = Expr[]
        if isempty(reasons)
            for cell in _dependent_cells(topology, bond_names)
                plan, pre = _plan_cell(session, notebook, topology, cell, bond_names, arg_types, original_state)
                push!(plans, plan)
                append!(preamble, pre)
            end
            unique!(string, preamble)
        end

        ExtractedGroup(;
            bond_names, arg_types, initial_values,
            preamble, cell_plans=plans,
            ok=isempty(reasons), reasons,
            synthetic_initials, domains,
        )
    end
end
