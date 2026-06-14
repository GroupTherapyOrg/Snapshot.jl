# imagecells.jl — C-P1: image/png cells (AbstractMatrix-of-color values) ship as
# canvas-rendered islands through a PlutoIslands-OWNED import surface, mirroring
# the WasmMakie E-004 contract shapes (import_specs rows + js glue) so
# compile.jl's wiring generalizes. PlutoIslands stays WasmMakie-free; the
# imports reuse wasm module name "canvas2d" (with PlutoIslands-distinct op
# names) so the shim's and oracle's existing canvas plumbing applies untouched.

# Value-returning import stubs: `Base.inferencebarrier(0)::Int64` keeps
# inference from const-folding the stub's return into compiled callers (the
# F-007 gotcha); `donotdelete` keeps the call alive.
@noinline function _ipx_begin(w::Int64, h::Int64)::Int64
    Base.donotdelete(w, h)
    Base.inferencebarrier(0)::Int64
end
@noinline function _ipx_push(r::Int64, g::Int64, b::Int64, a::Int64)::Int64
    Base.donotdelete(r, g, b, a)
    Base.inferencebarrier(0)::Int64
end
@noinline function _ipx_blit(x::Float64, y::Float64, w::Float64, h::Float64)::Int64
    Base.donotdelete(x, y, w, h)
    Base.inferencebarrier(0)::Int64
end

"Import spec rows in WasmMakie.import_specs' shape (consumed by compile.jl)."
const IMG_IMPORT_SPECS = [
    (func=_ipx_begin, mod="canvas2d", name="ipx_begin",
     params=[:I64, :I64], ret=:I64,
     arg_types=(Int64, Int64), return_type=Int64),
    (func=_ipx_push, mod="canvas2d", name="ipx_push",
     params=[:I64, :I64, :I64, :I64], ret=:I64,
     arg_types=(Int64, Int64, Int64, Int64), return_type=Int64),
    (func=_ipx_blit, mod="canvas2d", name="ipx_blit",
     params=[:F64, :F64, :F64, :F64], ret=:I64,
     arg_types=(Float64, Float64, Float64, Float64), return_type=Int64),
]

# Same contract as WasmMakie's js_glue(): a script defining
# `canvas2d_imports = (ctx) => ({ name: fn, … })`. Pixel semantics follow
# WasmMakie ops.jl's img buffer + putImageData/OffscreenCanvas blit.
const IMG_GLUE_JS = """
const canvas2d_imports = (ctx) => {
  let S = { img: null, imgW: 0, imgH: 0, n: 0 };
  return {
    ipx_begin: (w, h) => {
      S.imgW = Number(w); S.imgH = Number(h);
      S.img = new Uint8ClampedArray(S.imgW * S.imgH * 4);
      S.n = 0;
      return 0n;
    },
    ipx_push: (r, g, b, a) => {
      S.img[S.n++] = Number(r); S.img[S.n++] = Number(g);
      S.img[S.n++] = Number(b); S.img[S.n++] = Number(a);
      return 0n;
    },
    ipx_blit: (x, y, w, h) => {
      const oc = new OffscreenCanvas(S.imgW, S.imgH);
      oc.getContext('2d').putImageData(new ImageData(S.img, S.imgW, S.imgH), 0, 0);
      ctx.drawImage(oc, Number(x), Number(y), Number(w), Number(h));
      return 0n;
    },
  };
};
"""

"Mirror of _html_body's honest fallback for image/png cells: typed to
probe-fail rather than silently mis-render. _image_probe_fn replaces it."
_png_body(v) = error("image/png rendering of $(typeof(v)) unsupported")

"Per-eltype (r,g,b,a expression builders) for the pixel loop — decided at
PROBE time host-side from the runtime matrix's eltype; emitted exprs use only
field access + Float64/round, all wasm-compilable."
function _color_accessors(ET::DataType)
    fns = fieldnames(ET)
    f255(ex) = :(Int64(clamp(round(Float64($ex) * 255.0), 0.0, 255.0)))
    if :r in fns && :g in fns && :b in fns
        a = :alpha in fns ? f255(:(c.alpha)) : (:(Int64(255)))
        return (f255(:(c.r)), f255(:(c.g)), f255(:(c.b)), a)
    elseif :val in fns   # Gray / GrayA
        g = f255(:(c.val))
        a = :alpha in fns ? f255(:(c.alpha)) : (:(Int64(255)))
        return (g, g, g, a)
    end
    nothing
end

"""
Probe an image/png cell: if the raw value fn returns an AbstractMatrix whose
eltype duck-types as a color, build a render fn that pushes pixels through the
island_img import surface. Returns `(; render_fn, w, h)` or `nothing`.
"""
function _image_probe_fn(sandbox::Module, p::CellPlan, initial_values, arg_tuple)
    fe = p.fn_expr
    (fe isa Expr && fe.head === :function && length(fe.args) == 2) || return nothing
    body = fe.args[2]
    (body isa Expr && body.head === :block && !isempty(body.args)) || return nothing
    ret = body.args[end]
    (ret isa Expr && ret.head === :return && length(ret.args) == 1) || return nothing
    call = ret.args[1]
    (call isa Expr && call.head === :call && length(call.args) == 2 &&
        call.args[1] === _png_body) || return nothing
    val_sym = call.args[2]

    raw_expr = Expr(:function, fe.args[1],
                    Expr(:block, body.args[1:end-1]..., :(return $val_sym)))
    vf = try
        Core.eval(sandbox, raw_expr)
    catch
        return nothing
    end
    m0 = try
        Base.invokelatest(vf, initial_values...)
    catch
        nothing
    end
    m0 isa AbstractMatrix || return nothing
    ET = eltype(m0)
    ET isa DataType || return nothing
    acc = _color_accessors(ET)
    acc === nothing && return nothing
    rex, gex, bex, aex = acc
    h, w = Int64.(size(m0))

    rexpr = Expr(:function, fe.args[1],
        Expr(:block, body.args[1:end-1]...,
            quote
                local _m = $val_sym
                local _h = Int64(size(_m, 1))
                local _w = Int64(size(_m, 2))
                $(_ipx_begin)(_w, _h)
                for _j in 1:size(_m, 1)
                    for _i in 1:size(_m, 2)
                        local c = _m[_j, _i]
                        $(_ipx_push)($rex, $gex, $bex, $aex)
                    end
                end
                $(_ipx_blit)(0.0, 0.0, Float64(_w), Float64(_h))
                return Int64(0)
            end))
    rf = try
        Core.eval(sandbox, rexpr)
    catch
        return nothing
    end
    (; render_fn=rf, w, h)
end
