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
import Dates


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
    # per-bond transform tables (raw widget value ⇒ transform_value output)
    # for finite-domain widgets whose transform is not the identity —
    # `nothing` = identity. The shim looks raw values up before marshalling.
    transforms::Vector{Any} = Any[]
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
    ex.head in (:struct, :abstract, :primitive, :import, :using, :module, :macro) && return true
    ex.head === :macrocall && return false
    if ex.head === :const
        return true
    end
    false
end

"Is this a NAMED top-level function/method definition — `function f(…) … end`,
short-form `f(x) = …`, or with a `where`? (Anonymous `(x)->…` and plain
assignments `x = …` are NOT.) Such definitions belong at top level: inlined
into a recompute-function body Julia lowers them to a gensym local closure
(`#NNNN#f`) that shadows the global (constructors self-recurse / `UndefVar`).
They are hoisted to the preamble UNLESS they close over a bond (see
`_split_preamble`)."
function _is_funcdef_expr(ex)
    ex isa Expr || return false
    ex.head === :function && return true
    if ex.head === :(=)
        lhs = ex.args[1]
        while lhs isa Expr && lhs.head === :where
            lhs = lhs.args[1]
        end
        return lhs isa Expr && lhs.head === :call
    end
    false
end

"Does `ex` reference any symbol in `names` (recursive)? Used to keep
bond-closing definitions in the body, where the bond is a parameter."
function _refs_any(ex, names::Set{Symbol})
    isempty(names) && return false
    ex isa Symbol && return ex in names
    ex isa Expr || return false
    for a in ex.args
        _refs_any(a, names) && return true
    end
    false
end

"Parameter names a function-def signature binds (they SHADOW outer names, so a
def with `f(n) = …` does NOT close over a bond named `n`)."
function _funcdef_params(def::Expr)
    sig = def.args[1]
    while sig isa Expr && sig.head === :where
        sig = sig.args[1]
    end
    params = Symbol[]
    sig isa Expr && sig.head === :call || return params
    for a in sig.args[2:end]
        _collect_param_names!(params, a)
    end
    params
end
function _collect_param_names!(acc, a)
    if a isa Symbol
        push!(acc, a)
    elseif a isa Expr
        if a.head === :(::)
            a.args[1] isa Symbol && push!(acc, a.args[1])
        elseif a.head in (:kw, :(...))
            _collect_param_names!(acc, a.args[1])
        elseif a.head === :parameters
            for p in a.args; _collect_param_names!(acc, p); end
        end
    end
end

"A named def hoists unless it references a bond it does NOT itself shadow as a
parameter (a `f(n)=…` with bond `n` is fine to hoist — `n` is the param)."
_funcdef_hoistable(def::Expr, bonds::Set{Symbol}) =
    !_refs_any(def, setdiff(bonds, Set(_funcdef_params(def))))

"Rewrite a type-annotated top-level assignment `x::T = v` → `x = convert(T, v)`.
Top-level `x::T = v` is legal global-binding syntax in Pluto, but once inlined
into a recompute-function body `x` is a local: the annotation is then either
illegal (the name is used outside the block — \"type of `x` declared in inner
scope\") or collides with another cell's/branch's decl (\"multiple type
declarations for `x`\"). `x::T = v` binds `x` to `convert(T, v)` — so the
`convert` form preserves the value AND its type (e.g. `n::Int64 = 100.0` stays
`Int64(100)`, not `Float64`) without a local type declaration. Leaves
everything else untouched."
function _strip_toplevel_type_annot(ex)
    ex isa Expr || return ex
    if ex.head === :(=) && ex.args[1] isa Expr &&
       ex.args[1].head === :(::) && ex.args[1].args[1] isa Symbol
        name, T, v = ex.args[1].args[1], ex.args[1].args[2], ex.args[2]
        return Expr(:(=), name, Expr(:call, :convert, T, v))
    end
    # Recurse into SAME-SCOPE control flow so branch-local `x::T = v` (e.g. a
    # value set with the same type across `if`/`elseif` arms) is caught too —
    # once inlined those arms share the recompute fn's scope and collide. Do
    # NOT descend into new scopes (`let`/`for`/`while`/`function`/`->`): a typed
    # local there is genuinely isolated and legal.
    if ex.head in (:if, :elseif, :block, :begin, :&&, :||, :try)
        return Expr(ex.head, map(_strip_toplevel_type_annot, ex.args)...)
    end
    ex
end

# ─────────────────────────────────────────────────────────────────────────────
# Export-time partial evaluation of bond-INDEPENDENT upstream
#
# The recompute fn inlines the upstream closure as CODE. But an upstream cell
# that does NOT depend on the group's bonds produces the SAME value for every
# bond setting — so its producer code is dead weight that still has to compile.
# When that producer pulls heavy library machinery (objectid/Method/show via
# symbolic diff, image loads, Dicts), inlining it sinks the whole group. If the
# produced VALUE is a simple constant, we evaluate it once in the workspace and
# bake the literal instead — the producer code is never compiled. Non-bakeable
# values (functions, matrices, structs, huge arrays) fall back to inlining, so
# this is strictly an optimization: it can only remove a compile burden, never
# add one.
# ─────────────────────────────────────────────────────────────────────────────

"Can `v` be baked into the recompute fn as a literal constant? Conservative:
scalars / strings / (named)tuples of those. Excludes functions, matrices,
structs, and VECTORS — a baked vector constant adds an array type to the module
and surfaces a WasmTarget `compile_multi` type-index collision (array vs bridge
accessor func types — gap recorded; conv1d/Collatz). Re-allow vectors once that
WT bug is fixed."
function _bakeable_const(v)
    v isa Union{Bool,Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64,
                Float16,Float32,Float64,Char} && return true
    v isa AbstractString && return true
    v isa Tuple && return all(_bakeable_const, v)
    v isa NamedTuple && return all(_bakeable_const, values(v))
    false
end

"If every global this bond-independent upstream cell defines is a bakeable
constant, return `[var = <literal>, …]` (the producer code is then dropped);
otherwise `nothing` → inline the producer as before. Bails on functions so a
body-defined closure is never lost."
function _try_bake_cell(session::ServerSession, notebook::Notebook, up::Cell, topology)
    defs = collect(topology.nodes[up].definitions)
    isempty(defs) && return nothing
    baked = Any[]
    for v in defs
        val = try
            Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook), v)
        catch
            return nothing
        end
        (val isa Function || val isa Type) && return nothing
        _bakeable_const(val) || return nothing
        push!(baked, Expr(:(=), v, QuoteNode(val)))
    end
    baked
end

# ─────────────────────────────────────────────────────────────────────────────
# Baked finite-domain transforms
#
# A finite-domain widget (Select/Slider of options) sends a small client KEY;
# `transform_bond_value` maps that key to the value the notebook sees. When that
# transformed value is OUTSIDE the bridge universe (e.g. a `Function` chosen
# from `Slider([sin, cos, sqrt])`), we cannot marshal it into wasm. But the key
# IS marshallable — so type the wasm arg by the key and BAKE the key⇒value
# lookup into the recompute fn as a conditional. WasmTarget compiles a
# function-typed local selected by a branch (spike: `k==1 ? sin : cos` then
# `fn(x)` validates), so this turns function-valued bonds into real islands.
# ─────────────────────────────────────────────────────────────────────────────

"Can this transformed value be baked into the fn body as a literal selection?
Functions are the target case (they reference cleanly and WasmTarget calls
them); large/heap values (Matrices) are intentionally excluded — embedding them
as constants is heavy and trips WasmTarget's color-type codegen."
_bakeable(tv) = tv isa Function

"Build `keyarg == k₁ ? v₁ : keyarg == k₂ ? v₂ : … : vₙ` from a raw⇒transformed
table, with the transformed VALUES (functions) spliced in as objects and the
raw keys as literals."
function _bake_select_expr(keyarg::Symbol, table)
    expr = table[end][2]                                   # default: last value
    for i in (length(table) - 1):-1:1
        rk, tv = table[i]
        expr = Expr(:if, Expr(:call, :(==), keyarg, rk), tv, expr)
    end
    expr
end

"Top-level `Pkg.<setup>(…)` calls (the nbpkg-disabling escape hatch for
unregistered packages, e.g. `Pkg.activate(...)`) — environment setup is the
HOST's concern (`compile_group(env_dir=…)` activates the notebook env around
eval/compile), so these are DROPPED from extraction: inlined into a
recompute fn they would probe-fail every dependent cell."
function _is_pkg_setup_expr(ex)
    ex isa Expr && ex.head === :call || return false
    f = ex.args[1]
    f isa Expr && f.head === :. && length(f.args) == 2 || return false
    f.args[1] === :Pkg && f.args[2] isa QuoteNode &&
        f.args[2].value in (:activate, :instantiate, :resolve, :add, :develop, :status)
end

"Split a cell's parsed expr into (preamble_exprs, body_exprs).
`:toplevel` wrappers (e.g. from a trailing `;` in the cell) flatten like
`:block`s — their contents are ordinary statements."
function _split_preamble(ex, bond_names::Set{Symbol}=Set{Symbol}())
    pre, body = Expr[], Any[]
    exprs = (ex isa Expr && ex.head in (:block, :toplevel)) ? ex.args : [ex]
    for sub in exprs
        sub === nothing && continue
        sub isa LineNumberNode && continue
        if sub isa Expr && sub.head in (:block, :toplevel)
            spre, sbody = _split_preamble(sub, bond_names)
            append!(pre, spre)
            append!(body, sbody)
        elseif _is_pkg_setup_expr(sub)
            continue
        elseif _is_preamble_expr(sub)
            push!(pre, sub)
        elseif _is_funcdef_expr(sub) && _funcdef_hoistable(sub, bond_names)
            # named def that does NOT close over a bond → hoist to top level
            push!(pre, sub)
        else
            push!(body, _strip_toplevel_type_annot(sub))
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
Replace `\$(expr)` / `\$var` interpolations in the RAW source of an md\"…\" cell
with a sentinel, returning (sentineled_code, slot_exprs). `should(expr)` decides
PER interpolation whether to sentinelize it (→ a compiled `string(slot)` hole) or
leave it verbatim in the source (→ baked natively into the rendered skeleton). The
default sentinelizes everything; bond-aware callers pass a reactivity predicate so
bond-INDEPENDENT interpolations (constants, static nested markdown) bake correctly
in-context instead of being mis-rendered through `string()`.
"""
function _sentinelize_interpolations(code::String, should::Function=(_ -> true);
                                     slots::Vector=Expr[])
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
                if should(ex)
                    if _is_markdownish(ex)
                        # reactive NESTED markdown (e.g. `keep_working(md"…$(f(n))…")`):
                        # keep the wrapper VERBATIM so markdown renders it as a proper
                        # block (a sentinel here would land inside a `<p>` and the
                        # spliced admonition `<div>` wouldn't match native), and
                        # recurse into its inner md so only the inner scalars become
                        # holes. `slots` is shared so sentinel numbering stays global
                        # and in document order.
                        print(out, "\$(", _nested_md_resentinelize(inner, should, slots), ")")
                    else
                        push!(slots, Expr(:block, ex))
                        print(out, _SLOT, length(slots), "QQ")
                    end
                else
                    print(out, code[i:k])   # "$(…)" verbatim → bakes natively
                end
                i = nextind(code, k)
                continue
            elseif code[j] == '_' || isletter(code[j])
                k = j
                while k <= n && (code[k] == '_' || isletter(code[k]) || isdigit(code[k]) || code[k] == '!')
                    k = nextind(code, k)
                end
                name = code[j:prevind(code, k)]
                if should(Symbol(name))
                    push!(slots, Expr(:block, Symbol(name)))
                    print(out, _SLOT, length(slots), "QQ")
                else
                    print(out, code[i:prevind(code, k)])   # "$name" verbatim
                end
                i = k
                continue
            end
        end
        print(out, c)
        i = nextind(code, i)
    end
    (String(take!(out)), slots)
end

"Rewrite the SOURCE of a markdown-valued interpolation (e.g. `keep_working(md\"…\")`)
so its FIRST nested md\"…\" / md\\\"\\\"\\\"…\\\"\\\"\\\" literal has its own
interpolations bond-aware-sentinelized in place. Inner slots are appended to the
shared `slots` (global, document-order numbering). The wrapper call is left intact
so the rendered skeleton keeps the admonition as a proper block element."
function _nested_md_resentinelize(src::AbstractString, should::Function, slots::Vector)
    s = String(src)
    for (re, qo, qc) in ((r"md\"\"\"(.*?)\"\"\""s, "md\"\"\"", "\"\"\""),
                         (r"md\"((?:\\.|[^\"\\])*)\""s, "md\"", "\""))
        m = match(re, s)
        m === nothing && continue
        inner2, _ = _sentinelize_interpolations(String(m.captures[1]), should; slots=slots)
        a = m.offset - 1
        b = m.offset + ncodeunits(m.match)   # first byte past the match
        return s[1:a] * qo * inner2 * qc * (b > ncodeunits(s) ? "" : s[b:end])
    end
    s
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
    _split_sentinels(html, n_slots)
end

"Split rendered `html` on the `n_slots` ordered sentinels into `n_slots+1`
static segments; `nothing` if any sentinel didn't survive rendering verbatim."
function _split_sentinels(html::AbstractString, n_slots::Int)
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
# Generalized HTML skeleton — interactive-feedback cells (Tier-3)
#
# The flat md"…" path above renders ONE markdown macrocall. Interactive feedback
# cells are richer: `if <bond-cond> correct(md"…\$x…") else keep_working(md"…") end`
# (the PlutoTeachingTools correct/almost/keep_working/hint admonition pattern). The
# markdown STRUCTURE switches on bond arithmetic and, within a branch, is fixed —
# only scalars interpolate. So we never COMPILE markdown: render each branch's
# skeleton ONCE in the live workspace (full Markdown stdlib, native), bake the HTML
# around sentinels, and compile only the branch conditions + `string(scalar)`.
# Bond-INDEPENDENT interpolations (incl. constant nested admonitions) stay baked in
# the skeleton; bond-DEPENDENT markdown-valued slots recurse. The differential
# oracle is the backstop for any rendering the splice doesn't reproduce.
# ─────────────────────────────────────────────────────────────────────────────

"Names that vary with the group's bonds: the bonds themselves plus everything any
bond-dependent (downstream) cell defines. An interpolation touching one of these
is recomputed; everything else is constant and bakes into the skeleton."
function _reactive_names(topology, bond_names::Vector{Symbol}, dep_cells)::Set{Symbol}
    names = Set{Symbol}(bond_names)
    for c in dep_cells
        for d in topology.nodes[c].definitions
            push!(names, d)
        end
    end
    names
end

"Unwrap `_sentinelize_interpolations`' `:block`-wrapped slot to its inner expr."
_slot_inner(slot) = (slot isa Expr && slot.head === :block && length(slot.args) == 1) ?
                    slot.args[1] : slot

"Reactive if `ex` references a reactive name directly OR through a `\$…`
interpolation inside an md\"…\" literal (those live as TEXT in the macrocall's
string arg, invisible to a plain AST walk — so peer into them)."
function _expr_is_reactive(ex, reactive::Set{Symbol})
    _refs_any(ex, reactive) && return true
    if _is_md_cell(ex)
        idx = findlast(a -> a isa AbstractString, (ex::Expr).args)
        idx === nothing && return false
        _, sl = _sentinelize_interpolations(String(ex.args[idx]))
        return any(s -> _expr_is_reactive(_slot_inner(s), reactive), sl)
    end
    if ex isa Expr
        return any(a -> _expr_is_reactive(a, reactive), ex.args)
    end
    false
end

"Does this slot value render as nested MARKDOWN (md\"…\" or a wrapper call whose
arg is md\"…\", e.g. `correct(md\"…\")`) — needing HTML rendering, not `string()`?"
function _is_markdownish(ex)
    ex = _slot_inner(ex)
    _is_md_cell(ex) && return true
    if ex isa Expr && ex.head === :call && length(ex.args) >= 2
        return any(a -> _is_md_cell(_slot_inner(a)), ex.args[2:end])
    end
    false
end

"Bond-aware-sentinelize every md\"…\" literal inside `ex` (in document order),
returning (rewritten_ast, slots). Reactive interpolations become sentineled slots;
bond-independent ones stay verbatim and bake when the leaf is rendered."
function _sentinelize_md_ast(ex, reactive::Set{Symbol})
    slots = Expr[]
    walk(e) = begin
        if _is_md_cell(e)
            args = copy((e::Expr).args)
            idx = findlast(a -> a isa AbstractString, args)
            if idx !== nothing
                s2, sl = _sentinelize_interpolations(String(args[idx]),
                                                     inner -> _expr_is_reactive(inner, reactive))
                args[idx] = s2
                append!(slots, sl)
            end
            Expr(e.head, args...)
        elseif e isa Expr
            Expr(e.head, map(walk, e.args)...)
        else
            e
        end
    end
    (walk(ex), slots)
end

"Render one leaf (md\"…\" or wrapper(md\"…\")) to a body-string expr via the
render-once-splice skeleton. `nothing` if it has no reactive slot (caller bakes it
whole) or a sentinel didn't survive rendering verbatim."
function _leaf_html_expr(session::ServerSession, notebook::Notebook, leaf, reactive::Set{Symbol})
    sent_ast, slots = _sentinelize_md_ast(leaf, reactive)
    isempty(slots) && return nothing
    render_expr = :(repr(MIME"text/html"(), $sent_ast))
    html = try
        Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook), render_expr)
    catch
        return nothing
    end
    html isa String || return nothing
    segs = _split_sentinels(html, length(slots))
    segs === nothing && return nothing
    parts = Any[segs[1]]
    for (k, slot) in enumerate(slots)
        push!(parts, _slot_str_expr(session, notebook, slot, reactive))
        push!(parts, segs[k + 1])
    end
    foldl((a, b) -> :($a * $b), parts)
end

"A reactive slot → its body-string expr. After bond-aware sentinelization every
remaining slot is a SCALAR leaf (reactive nested markdown keeps its wrapper verbatim
and is recursed in-place during sentinelization, so it never reaches here), so this
is just `string(scalar)`."
_slot_str_expr(session::ServerSession, notebook::Notebook, slot, reactive::Set{Symbol}) =
    :(string($(_slot_inner(slot))))

"Turn a text/html cell body expr into a body-string expr: `if/elseif/else` becomes a
conditional over per-branch skeletons (conditions stay, compiled to wasm); leaves go
through `_leaf_html_expr`. `nothing` if any branch can't be skeletonized."
function _html_skeleton_expr(session::ServerSession, notebook::Notebook, ex, reactive::Set{Symbol})
    if ex isa Expr && ex.head in (:if, :elseif)
        thenx = _html_skeleton_expr(session, notebook, ex.args[2], reactive)
        thenx === nothing && return nothing
        elsex = length(ex.args) >= 3 ?
                _html_skeleton_expr(session, notebook, ex.args[3], reactive) : ""
        elsex === nothing && return nothing
        return Expr(:if, ex.args[1], thenx, elsex)
    elseif ex isa Expr && ex.head === :block
        reals = filter(a -> !(a isa LineNumberNode), ex.args)
        length(reals) == 1 && return _html_skeleton_expr(session, notebook, reals[1], reactive)
        return nothing   # multi-statement branch: not a pure render leaf
    else
        return _leaf_html_expr(session, notebook, ex, reactive)
    end
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
    bakes::Vector=Any[nothing for _ in bond_names],
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

    # Gather upstream code (topo order), splitting out preamble exprs.
    # `bonds` are recompute-fn parameters: a definition that closes over one
    # stays in the body (where the bond is in scope), everything else hoists.
    bonds = Set(bond_names)
    # cells downstream of THIS group's bonds are bond-DEPENDENT; everything else
    # in the upstream closure is bond-independent and eligible for export-time
    # value-baking (partial evaluation).
    dep_set = Set(_dependent_cells(topology, bond_names))
    preamble = Expr[]
    stmts = Any[]
    for up in _upstream_closure(topology, cell)
        upex = _parse_cell(up)
        upex === nothing && return fail("upstream cell $(up.cell_id) failed to parse")
        pre, body = _split_preamble(upex, bonds)
        append!(preamble, pre)
        # bond-independent + all-bakeable → bake the values, drop the producer
        baked = up in dep_set ? nothing : _try_bake_cell(session, notebook, up, topology)
        append!(stmts, baked === nothing ? body : baked)
    end

    # C-P12: `using` cells are not reliably in the upstream closure —
    # where_assigned can't see the soft-scope names a plain `using Pkg`
    # provides (e.g. Collatz's hailstone_sequence), so cells whose only
    # non-bond upstream is a using-cell got an EMPTY preamble and the
    # sandbox lacked the packages. Package loading is idempotent: hoist
    # every using/import expr in the notebook; extract_groups dedups.
    for nc in notebook.cells
        ncex = _parse_cell(nc)
        ncex === nothing && continue
        pre_all, _ = _split_preamble(ncex)
        for pe in pre_all
            (pe isa Expr && pe.head in (:using, :import)) && push!(preamble, pe)
        end
    end

    # The target cell itself → value capture + body strategy
    pre_t, body_t = _split_preamble(ex, bonds)
    append!(preamble, pre_t)
    val = gensym(:cellval)

    body_kind = :string
    # Generalized HTML skeleton: handles flat md"…", wrapper(md"…"), and
    # `if/elseif/else` feedback cells uniformly — renders markdown structure once
    # in the workspace, compiling only branch conditions + `string(scalar)` slots.
    # The left-folded binary `*` chains it builds compile fine (n-ary string `*`
    # with ≥4 operands traps in WasmTarget — WASM_FINDINGS.md).
    reactive = _reactive_names(topology, bond_names, dep_set)
    # Also attempt the skeleton for cells that ERRORED at the initial bond value
    # (stacktrace mime). A no-initial-value bond (e.g. a raw `html"<input
    # type=range>"`) leaves the workspace bond `missing`, so a feedback cell like
    # `if pieces(n) == … md"…" else md"…" end` throws `if missing` and renders as
    # a stacktrace at the initial state — but its markdown STRUCTURE skeletonizes
    # fine (each branch leaf renders with the bond interpolations sentinelized; the
    # bond is never evaluated). Without this the cell falls to _plain_body →
    # `string(::MD)` → Markdown.plain dynamic dispatch, which traps (unreachable)
    # in wasm. If the skeleton can't render, we fall through to the mime handling.
    skeleton = (length(body_t) == 1 &&
                mime in ("text/html", "application/vnd.pluto.stacktrace+object")) ?
               _html_skeleton_expr(session, notebook, body_t[1], reactive) : nothing
    body_string_expr = if skeleton !== nothing
        skeleton
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
    elseif mime == "application/vnd.pluto.stacktrace+object"
        # the cell ERRORED in the headless initial run (e.g. missing bond) —
        # optimistically render text/plain; initial verify is skipped for
        # synthetic groups and the oracle judges real values
        _capture_value!(stmts, body_t, val) || return fail("empty cell body")
        :($(_plain_body)($val))
    elseif mime == "image/png"
        # C-P1: matrix-of-color cells — the probe in compile.jl replaces the
        # honest _png_body fallback with a pixel-pushing render wrapper
        _capture_value!(stmts, body_t, val) || return fail("empty cell body")
        :($(_png_body)($val))
    elseif mime == "application/vnd.pluto.tree+object"
        _capture_value!(stmts, body_t, val) || return fail("empty cell body")
        # raw value out; compile-time discovers the concrete type and attaches
        # the bridge read descriptor (leaf/shape gates live in compile)
        body_kind = :tree
        val
    else
        return fail("unsupported output mime $(mime) in v0 (text/plain & md-text/html only)")
    end

    # Baked bonds take the raw client KEY as their parameter (named distinctly)
    # and rebind the bond name from a spliced key⇒value selection at the top of
    # the body; non-baked bonds are typed parameters as usual.
    args = Expr[]
    bake_inject = Any[]
    for (n, t, bake) in zip(bond_names, arg_types, bakes)
        if bake === nothing
            push!(args, Expr(:(::), n, t))
        else
            keyarg = Symbol("__", n, "_key")
            push!(args, Expr(:(::), keyarg, t))
            push!(bake_inject, Expr(:(=), n, _bake_select_expr(keyarg, bake)))
        end
    end
    fn_expr = Expr(:function, Expr(:tuple, args...),
                   Expr(:block, bake_inject..., stmts..., :(return $body_string_expr)))

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
# (plain `html"<input …>"` elements, and combine()-style multi-input widgets).
# Parse the widget's RENDERED html the way Pluto's own frontend reads it:
# range/number → min:step:max numeric domain, checkbox → Bool. Gives these
# bonds a verifiable domain — the oracle samples it like any finite widget.
#
# The html comes from the bond-defining cell's output when it has one — but a
# `x = @bind y widget;` cell SUPPRESSES output (text/plain, no html). The
# reliable source is the workspace's own bond registry: render the registered
# element exactly like Pluto does (_bond_element_html).
# ─────────────────────────────────────────────────────────────────────────────

"Render a bond's registered element to html inside the workspace (the element
itself usually can't cross the Malt boundary; its html always can)."
function _bond_element_html(session, notebook, bond_name::Symbol)
    h = try
        Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook),
            # PlutoRunner's own iocontext: without it, PlutoUI widgets (combine
            # et al.) render their "update Pluto" fallback instead of the inputs
            :(let el = get(Main.PlutoRunner.registered_bond_elements, $(QuoteNode(bond_name)), nothing)
                  el === nothing ? nothing :
                  repr(MIME"text/html"(), el; context=Main.PlutoRunner.default_iocontext)
              end))
    catch
        nothing
    end
    h isa String ? h : nothing
end

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
    _introspect_widget_html(body)
end

"Parse ONE <select>…</select> block: options' values are the domain (strings)."
function _introspect_select(selhtml::AbstractString)
    opts = [String(o.captures[1]) for o in eachmatch(r"<option\b[^>]*value\s*=\s*[\"']?([^\"'\s>]+)"i, selhtml)]
    isempty(opts) && return nothing
    sel = match(r"<option\b[^>]*selected[^>]*value\s*=\s*[\"']?([^\"'\s>]+)"i, selhtml)
    (initial=sel === nothing ? opts[1] : String(sel.captures[1]), domain=opts)
end

function _introspect_widget_html(body::String)
    # gather every widget in DOM order: <select> blocks + <input> tags
    sels = collect(eachmatch(r"<select\b.*?</select>"is, body))
    inputs = [m for m in eachmatch(r"<input\b[^>]*>"i, body)
              if !any(s.offset <= m.offset < s.offset + ncodeunits(s.match) for s in sels)]
    widgets = sort!(vcat(Any[sels...], Any[inputs...]); by=m -> m.offset)
    isempty(widgets) && return nothing
    parsed = Any[w in sels ? _introspect_select(w.match) : _introspect_input_tag(w.match) for w in widgets]
    any(isnothing, parsed) && return nothing
    length(parsed) == 1 && return parsed[1]
    # combine()-style multi-input widget: the client sends a VECTOR of child
    # values in DOM order (transform_value shapes it server-side). Domain is a
    # finite probe set: the initial combo + vary-one-child-at-a-time.
    initials = identity.(Any[p.initial for p in parsed])
    cap_per_child = max(2, fld(400, length(parsed)))
    combos = Any[initials]
    for (j, p) in enumerate(parsed)
        vals = collect(p.domain)
        length(vals) > cap_per_child && (vals = vals[round.(Int, range(1, length(vals); length=cap_per_child))])
        for val in vals
            isequal(val, initials[j]) && continue
            combo = copy(initials)
            combo[j] = val
            push!(combos, identity.(combo))
        end
    end
    (initial=initials, domain=combos)
end

"Parse ONE <input …> tag into (initial, domain) — same rules as Pluto's Bond.js."
function _introspect_input_tag(tag::AbstractString)
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
    elseif typ in ("text", "search", "password", "email", "url")
        # free text: Bond.js sends .value (String). The domain is a PROBE SET —
        # native re-runs with these strings are valid ground truth, and the
        # runtime accepts arbitrary strings identically.
        v0 = something(attr("value"), "")
        return (initial=v0, domain=Any[v0, "abc", "hello world", "123"])
    elseif typ == "color"
        v0 = something(attr("value"), "#000000")
        return (initial=v0, domain=Any[v0, "#ff0000", "#1a2b3c", "#ffffff"])
    elseif typ == "date"
        # Bond.js sends valueAsDate → msgpack Date ext → Julia DateTime
        v0 = let a = attr("value")
            a === nothing ? Dates.DateTime(2026, 1, 1) :
                something(tryparse(Dates.DateTime, a * "T00:00:00"), Dates.DateTime(2026, 1, 1))
        end
        return (initial=v0,
                domain=Any[v0, Dates.DateTime(2024, 6, 15), Dates.DateTime(2030, 12, 31)])
    end
    nothing   # button/file etc: not introspectable in v1
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
        transforms = Any[]
        bakes = Any[]
        for n in bond_names
            fetch_failed = false
            v_synthetic = false   # v holds a RAW client value (not the workspace's transformed one)
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
                    # last resort: read the widget's own rendered html — from the
                    # cell output, else rendered fresh from the workspace's bond
                    # registry (output-suppressed `x = @bind …;` cells have none)
                    wi = _widget_introspect(original_state, topology, n)
                    h = nothing
                    if wi === nothing
                        h = _bond_element_html(session, notebook, n)
                        h === nothing || (wi = _introspect_widget_html(h))
                    end
                    if wi !== nothing
                        v = wi.initial
                        bond_domain = wi.domain
                        synthetic_initials = true
                        v_synthetic = true
                    elseif h !== nothing && occursin("button", lowercase(h))
                        # counter/button widget: custom JS with a `<button>` that
                        # sends a click COUNT (Int, starts 0) — no `<input>` to
                        # introspect. Synthesize a small Int domain; the oracle
                        # verifies it and the compiled body works for any Int the
                        # widget sends at runtime.
                        v = Int64(0)
                        bond_domain = Any[Int64(0), Int64(1), Int64(2)]
                        synthetic_initials = true
                        v_synthetic = true
                    else
                        push!(reasons, "bond $(n) is $(fetch_failed ? "unfetchable" : "missing") and has no usable possible_values ($(domain isa Symbol ? domain : "empty")) or introspectable widget html")
                    end
                else
                    v = first(domain)
                    synthetic_initials = true
                    v_synthetic = true
                end
            end
            # big-int slider values: narrow when exactly representable — the
            # client sends plain ints anyway; the oracle verifies semantics
            if v isa BigInt && typemin(Int64) <= v <= typemax(Int64)
                v = Int64(v)
            end
            # finite-domain transform_value table (Select sends option KEYS;
            # the notebook sees transformed VALUES — tabulate the mapping)
            bond_transform = nothing
            raw_domain = bond_domain
            if raw_domain === nothing
                pv = try
                    Pluto.possible_bond_values(session, notebook, n)
                catch
                    nothing
                end
                (pv isa Symbol || pv === nothing) || (raw_domain = collect(Any, pv))
            end
            if raw_domain !== nothing && length(raw_domain) <= 500
                transformed = try
                    Pluto.WorkspaceManager.eval_fetch_in_workspace((session, notebook),
                        :(map(r -> Main.PlutoRunner.transform_bond_value($(QuoteNode(n)), r), $(raw_domain))))
                catch
                    nothing
                end
                if transformed !== nothing && length(transformed) == length(raw_domain) &&
                   any(!isequal(t, r) for (t, r) in zip(transformed, raw_domain))
                    bond_transform = collect(zip(raw_domain, transformed))
                end
                bond_domain = raw_domain
            end
            # a synthetic initial is a RAW client value; the cell fn (and the
            # bridge arg descriptor) work on TRANSFORMED values — remap it
            if bond_transform !== nothing && v_synthetic
                hit = findfirst(p -> isequal(p[1], v), bond_transform)
                hit === nothing || (v = bond_transform[hit][2])
            end
            # BAKE: transformed value not bridge-marshallable, but a finite
            # transform with marshallable keys exists → take the raw KEY as the
            # arg and bake the key⇒value lookup into the fn body. The shim/oracle
            # must then send the raw key (transform=nothing) — wasm does the map.
            bake = nothing
            if !WasmTarget.Bridge.args_supported(typeof(v)) &&
               bond_transform !== nothing &&
               all(p -> _bakeable(p[2]), bond_transform) &&
               all(p -> WasmTarget.Bridge.args_supported(typeof(p[1])), bond_transform)
                hit = findfirst(p -> isequal(p[2], v), bond_transform)
                if hit !== nothing
                    bake = bond_transform
                    v = bond_transform[hit][1]   # initial becomes the raw key
                    bond_transform = nothing     # wasm bakes; no client transform
                end
            end
            push!(transforms, bond_transform)
            push!(bakes, bake)
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
                plan, pre = _plan_cell(session, notebook, topology, cell, bond_names, arg_types, original_state, bakes)
                push!(plans, plan)
                append!(preamble, pre)
            end
            unique!(string, preamble)
        end

        ExtractedGroup(;
            bond_names, arg_types, initial_values,
            preamble, cell_plans=plans,
            ok=isempty(reasons), reasons,
            synthetic_initials, domains, transforms,
        )
    end
end
