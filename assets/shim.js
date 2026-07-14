// Snapshot shim — the wasm-island slider "server", running in this tab.
//
// Pluto's exported HTML has slider_server_url set, so its stock frontend
// (SliderServerClient.js) does:
//   GET <url>/bondconnections/<notebook_hash>          -> msgpack bond graph
//   GET <url>/staterequest/<notebook_hash>/<b64bonds>  -> msgpack {patches}
//   (or POST <url>/staterequest/<notebook_hash>/ with msgpack body)
// We intercept window.fetch BEFORE the editor boots and answer both locally:
// bond connections from the manifest, staterequests by calling the
// WasmTarget-compiled island of the matching bond group and shaping the same
// patches a real PlutoSliderServer would send. Zero Pluto frontend
// modification. No Julia. No network (beyond CDN assets).
//
// Manifest (islands.json, next to this script):
//   { groups: [{ wasm, bonds: [{name, type: int|float|bool, initial}],
//                cells: [{id, fn}] }] }
// Bond args are passed to each cell export in manifest order; bonds the
// client hasn't touched yet fall back to their initial values.

(() => {
    "use strict"

    // ─── minimal msgpack (subset: nil/bool/int/float/str/bin/array/map) ───
    const mp = {
        decode(u8) {
            let i = 0
            const td = new TextDecoder()
            const view = new DataView(u8.buffer, u8.byteOffset, u8.byteLength)
            const read = () => {
                const b = u8[i++]
                if (b < 0x80) return b // positive fixint
                if (b >= 0xe0) return b - 0x100 // negative fixint
                if (b >= 0xa0 && b <= 0xbf) return str(b - 0xa0)
                if (b >= 0x90 && b <= 0x9f) return arr(b - 0x90)
                if (b >= 0x80 && b <= 0x8f) return map(b - 0x80)
                switch (b) {
                    case 0xc0: return null
                    case 0xc2: return false
                    case 0xc3: return true
                    case 0xd4: return ext(1)
                    case 0xd5: return ext(2)
                    case 0xd6: return ext(4)
                    case 0xd7: return ext(8)
                    case 0xd8: return ext(16)
                    case 0xc7: return ext(u8[i++])
                    case 0xc4: return bin(u8[i++])
                    case 0xc5: return bin(u16())
                    case 0xc6: return bin(u32())
                    case 0xca: { const v = view.getFloat32(i); i += 4; return v }
                    case 0xcb: { const v = view.getFloat64(i); i += 8; return v }
                    case 0xcc: return u8[i++]
                    case 0xcd: return u16()
                    case 0xce: return u32()
                    case 0xcf: { const v = view.getBigUint64(i); i += 8; return v }
                    case 0xd0: { const v = view.getInt8(i); i += 1; return v }
                    case 0xd1: { const v = view.getInt16(i); i += 2; return v }
                    case 0xd2: { const v = view.getInt32(i); i += 4; return v }
                    case 0xd3: { const v = view.getBigInt64(i); i += 8; return v }
                    case 0xd9: return str(u8[i++])
                    case 0xda: return str(u16())
                    case 0xdb: return str(u32())
                    case 0xdc: return arr(u16())
                    case 0xdd: return arr(u32())
                    case 0xde: return map(u16())
                    case 0xdf: return map(u32())
                    default: throw new Error("msgpack: unsupported byte 0x" + b.toString(16))
                }
            }
            const u16 = () => { const v = view.getUint16(i); i += 2; return v }
            const u32 = () => { const v = view.getUint32(i); i += 4; return v }
            const str = (n) => { const s = td.decode(u8.subarray(i, i + n)); i += n; return s }
            const bin = (n) => { const v = u8.slice(i, i + n); i += n; return v }
            const ext = (n) => {
                const type = view.getInt8(i); i += 1
                if (type === 0x0d && n === 8) {   // Pluto Date ext: epoch ms i64
                    const ms = view.getBigInt64(i); i += 8
                    return { __pluto_date_ms: ms.toString() }
                }
                const v = u8.slice(i, i + n); i += n
                return { __ext: type, data: Array.from(v) }
            }
            const arr = (n) => { const a = new Array(n); for (let k = 0; k < n; k++) a[k] = read(); return a }
            const map = (n) => { const m = {}; for (let k = 0; k < n; k++) { const key = read(); m[key] = read() } return m }
            return read()
        },
        encode(value) {
            const chunks = []
            const te = new TextEncoder()
            const enc = (v) => {
                if (v === null || v === undefined) chunks.push(new Uint8Array([0xc0]))
                else if (typeof v === "boolean") chunks.push(new Uint8Array([v ? 0xc3 : 0xc2]))
                else if (typeof v === "number" && Number.isInteger(v)) encInt(v)
                else if (typeof v === "number") { const b = new Uint8Array(9); b[0] = 0xcb; new DataView(b.buffer).setFloat64(1, v); chunks.push(b) }
                else if (typeof v === "bigint") { const b = new Uint8Array(9); b[0] = 0xd3; new DataView(b.buffer).setBigInt64(1, v); chunks.push(b) }
                else if (typeof v === "string") encStr(v)
                else if (Array.isArray(v)) { encArrHdr(v.length); v.forEach(enc) }
                else if (v instanceof Uint8Array) { encBinHdr(v.length); chunks.push(v) }
                else { const keys = Object.keys(v); encMapHdr(keys.length); keys.forEach((k) => { encStr(k); enc(v[k]) }) }
            }
            const encInt = (v) => {
                if (v >= 0 && v < 0x80) chunks.push(new Uint8Array([v]))
                else if (v < 0 && v >= -32) chunks.push(new Uint8Array([0x100 + v]))
                else { const b = new Uint8Array(9); b[0] = 0xd3; new DataView(b.buffer).setBigInt64(1, BigInt(v)); chunks.push(b) }
            }
            const encStr = (s) => {
                const u = te.encode(s)
                if (u.length < 32) chunks.push(new Uint8Array([0xa0 | u.length]))
                else if (u.length < 0x100) chunks.push(new Uint8Array([0xd9, u.length]))
                else { const b = new Uint8Array(3); b[0] = 0xda; new DataView(b.buffer).setUint16(1, u.length); chunks.push(b) }
                chunks.push(u)
            }
            const encArrHdr = (n) => {
                if (n < 16) chunks.push(new Uint8Array([0x90 | n]))
                else { const b = new Uint8Array(3); b[0] = 0xdc; new DataView(b.buffer).setUint16(1, n); chunks.push(b) }
            }
            const encMapHdr = (n) => {
                if (n < 16) chunks.push(new Uint8Array([0x80 | n]))
                else { const b = new Uint8Array(3); b[0] = 0xde; new DataView(b.buffer).setUint16(1, n); chunks.push(b) }
            }
            const encBinHdr = (n) => {
                if (n < 0x100) chunks.push(new Uint8Array([0xc4, n]))
                else { const b = new Uint8Array(3); b[0] = 0xc5; new DataView(b.buffer).setUint16(1, n); chunks.push(b) }
            }
            enc(value)
            const total = chunks.reduce((s, c) => s + c.length, 0)
            const out = new Uint8Array(total)
            let off = 0
            for (const c of chunks) { out.set(c, off); off += c.length }
            return out
        },
    }

    const b64url_decode = (s) => {
        const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4)
        const bin = atob(b64)
        const u8 = new Uint8Array(bin.length)
        for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i)
        return u8
    }

    // ─── manifest + lazy per-group wasm loading ───
    const orig_fetch = window.fetch.bind(window)
    // this script lives inside <notebook>.islands/ — resolve siblings from it
    const assets_base = new URL(".", document.currentScript.src)

    let manifest_promise = null
    const load_manifest = () => {
        manifest_promise ??= orig_fetch(new URL("islands.json", assets_base))
            .then((r) => r.json())
            .then((m) => {
                console.log(`🏝️ islands manifest: ${m.groups.length} group(s)`, m)
                m.groups.forEach((g) => {
                    g._instance = null
                    g._render_tail = Promise.resolve()
                })
                return m
            })
        return manifest_promise
    }

    // Shared font atlas (font dedup): when the manifest carries `fonts_url`, the
    // ~1.9 MB Makie font atlas lives in ONE shared file (referenced by URL) instead
    // of being inlined into every notebook. Fetch + parse it once, cached, the same
    // way we fetch the wasm (relative to assets_base).
    let shared_fonts_promise = null
    const load_shared_fonts = (m) => {
        if (!m || !m.fonts_url) return Promise.resolve([])
        shared_fonts_promise ??= orig_fetch(new URL(m.fonts_url, assets_base))
            .then((r) => r.text()).then((t) => JSON.parse(t)).catch(() => [])
        return shared_fonts_promise
    }

    const load_group = (group) => {
        group._instance ??= (async () => {
            const wasm_resp = await orig_fetch(new URL(group.wasm, assets_base))
            // builtins: WasmTarget emits wasm:js-string imports for string
            // production (axis labels, string(::Complex/::Float64)).
            const mod = await WebAssembly.compileStreaming(wasm_resp, { builtins: ['js-string'] })
            // canvas provider (E-004): groups with figure cells carry their
            // own glue (canvas2d_imports/canvas2d_load_fonts from the
            // notebook's WasmMakie). Imports are fixed at instantiation, so
            // the glue gets a PROXY ctx that forwards to group._ctx — each
            // render points it at a fresh canvas.
            let canvas2d = null
            if (group.canvas_glue) {
                const ctx_proxy = new Proxy({}, {
                    get: (_, prop) => {
                        const c = group._ctx
                        const v = c ? c[prop] : undefined
                        return typeof v === "function" ? v.bind(c) : v
                    },
                    set: (_, prop, val) => { const c = group._ctx; if (c) c[prop] = val; return true },
                })
                const factory = new Function(group.canvas_glue + "\nreturn { canvas2d_imports, canvas2d_load_fonts, create_back_buffer: typeof canvas2d_create_back_buffer === 'function' ? canvas2d_create_back_buffer : null, present_frame: typeof canvas2d_present_frame === 'function' ? canvas2d_present_frame : null };")()
                group._canvas_api = factory
                canvas2d = factory.canvas2d_imports(ctx_proxy)
                try {
                    // fonts are inline (group.canvas_fonts) OR externalized to a
                    // shared file (manifest.fonts_url) — the dedup path.
                    const _fonts = group.canvas_fonts != null
                        ? JSON.parse(group.canvas_fonts)
                        : await load_shared_fonts(await load_manifest())
                    await factory.canvas2d_load_fonts(_fonts)
                } catch (e) { console.warn("🏝️ canvas font load failed:", e) }
            }
            const imports = {}
            for (const imp of WebAssembly.Module.imports(mod)) {
                if (imp.module === "wasm:js-string") continue   // provided by builtins
                ;(imports[imp.module] ||= {})[imp.name] =
                    imp.module === "Math" ? Math[imp.name]
                    : imp.module === "canvas2d" && canvas2d ? canvas2d[imp.name]
                    : () => 0
            }
            const ex = (await WebAssembly.instantiate(mod, imports)).exports
            const read_str = (ref) => {
                const len = Number(ex._str_len(ref))
                const bytes = new Uint8Array(len)
                for (let i = 1; i <= len; i++) bytes[i - 1] = Number(ex._str_byte(ref, BigInt(i)))
                return new TextDecoder().decode(bytes)
            }
            console.log(`🏝️ island loaded: ${group.wasm} [${group.bonds.map((b) => b.name).join(", ")}]`)
            return { ex, read_str, canvas_api: group._canvas_api ?? null }
        })()
        return group._instance
    }

    // ─── WasmTarget.Bridge marshalling: JS value → tagged tree → in-module ctors ───
    const _dv = new DataView(new ArrayBuffer(8))
    const f64bits_of = (v) => {
        _dv.setFloat64(0, Number(v))
        return String(BigInt.asIntN(64, _dv.getBigUint64(0)))
    }
    // runtime JS value (msgpack-decoded or manifest initial) → tagged exact tree
    const value_tree = (d, v) => {
        switch (d.k) {
            case "int": return { x: String(typeof v === "boolean" ? (v ? 1 : 0) : (typeof v === "number" ? Math.round(v) : v)) }
            case "bits": return { x: f64bits_of(v) }
            case "char": return { x: String(typeof v === "string" ? v.codePointAt(0) : Number(v)) }
            case "str": return { s: Array.from(new TextEncoder().encode(String(v))) }
            case "vec": return { a: (Array.isArray(v) ? v : []).map((x) => value_tree(d.el, x)) }
            case "fields": {
                if (v && v.__pluto_date_ms !== undefined) {
                    // msgpack Date ext → Julia DateTime: instant ms = epoch ms + UNIXEPOCH
                    const jl = BigInt(v.__pluto_date_ms) + 62135683200000n
                    const wrap = (dd) => dd.k === "int" ? { x: jl.toString() } : { f: [wrap(dd.fs[0].d)] }
                    return wrap(d)
                }
                const vals = Array.isArray(v)
                    ? v
                    : d.names
                    ? d.names.map((n) => v?.[n])
                    : Object.values(v ?? {})
                return { f: d.fs.map((fd, i) => value_tree(fd.d, vals[i])) }
            }
            default: throw new Error("bad desc kind " + d.k)
        }
    }
    //__TREE_BODY_JS__

    // bridge read-side walker (parameterized by exports)
    const walk_ex = (ex, d, v) => {
        switch (d.k) {
            case "int": return { x: String(v) }
            case "bits": return { x: String(ex[d.b](v)) }
            case "char": return { x: String(ex[d.b](v)) }
            case "str": {
                const n = Number(ex[d.len](v)); const a = []
                for (let i = 1; i <= n; i++) a.push(Number(ex[d.cu](v, BigInt(i))))
                return { s: a }
            }
            case "fields": return { f: d.fs.map((fd) => walk_ex(ex, fd.d, ex[fd.a](v))) }
            case "vec": {
                const n = Number(ex[d.len](v)); const a = []
                for (let i = 1; i <= n; i++) a.push(walk_ex(ex, d.el, ex[d.get](v, BigInt(i))))
                return { a: a }
            }
            default: throw new Error("bad desc kind " + d.k)
        }
    }

    // walk_ex tagged tree → a readable HTML STRING (for the lean __pi_renderAll path,
    // which sets innerHTML; the legacy Pluto path keeps the object tree via mime).
    const _esc_tree = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const _decode_str = (bytes) => {
        try { return new TextDecoder().decode(new Uint8Array(bytes)) }
        catch (e) { return String.fromCharCode.apply(null, bytes) }
    }
    // Emit Pluto's OWN tree DOM (pluto-tree / pluto-tree-items.<kind> / p-r / p-k /
    // p-v) so frontend/treeview.css (ported verbatim into pluto-output.css) styles
    // it 1-1. Containers render collapsed → `[v1, v2, …]` with the clickable caret;
    // scalars render as plain text (Pluto's text/plain). Brackets, commas and the
    // caret all come from treeview.css — we only supply the structure + values.
    const _tree_pluto = (kind, items) => {
        let rows = ""
        items.forEach((el, i) => {
            rows += "<p-r><p-k>" + (i + 1) + "</p-k><p-v>" + tree_to_html(el) + "</p-v></p-r>"
        })
        return '<pluto-tree class="collapsed ' + kind + '">' +
               "<pluto-tree-prefix></pluto-tree-prefix>" +
               '<pluto-tree-items class="' + kind + '">' + rows + "</pluto-tree-items></pluto-tree>"
    }
    const tree_to_html = (t) => {
        if (t == null) return ""
        if ("x" in t) return _esc_tree(t.x)                                   // scalar (number/char repr)
        if ("s" in t) return '"' + _esc_tree(_decode_str(t.s)) + '"'          // string — Julia repr is quoted
        if ("a" in t) return _tree_pluto("Array", t.a)                        // vector / array → Pluto tree
        if ("f" in t) return _tree_pluto("Tuple", t.f)                        // struct / tuple → Pluto tree
        return _esc_tree(String(t))
    }

    // tagged tree → Julia value INSIDE wasm (via compiled constructor exports)
    const build = (ex, d, t) => {
        switch (d.k) {
            case "int": return d.w === 64 ? BigInt(t.x) : Number(t.x)
            case "bits": {
                _dv.setBigUint64(0, BigInt.asUintN(64, BigInt(t.x)))
                return _dv.getFloat64(0)
            }
            case "char": return ex[d.mk](BigInt(t.x))
            case "str": {
                const b = ex[d.new](BigInt(t.s.length))
                for (let i = 0; i < t.s.length; i++) ex[d.set](b, BigInt(i + 1), t.s[i])
                return ex[d.mk](b)
            }
            case "fields": return ex[d.mk](...d.fs.map((fd, i) => build(ex, fd.d, t.f[i])))
            case "vec": {
                const v = ex[d.new](BigInt(t.a.length))
                for (let i = 0; i < t.a.length; i++) ex[d.set](v, BigInt(i + 1), build(ex, d.el, t.a[i]))
                return v
            }
            default: throw new Error("bad desc kind " + d.k)
        }
    }

    const msgpack_response = (u8) =>
        new Response(u8, { status: 200, headers: { "Content-Type": "application/msgpack" } })

    // ─── the local slider "server" (hybrid: non-island groups fall through) ───
    const handle_bondconnections = async (passthrough) => {
        const m = await load_manifest()
        // full graph (manifest.bond_graph covers fallback groups too)
        const graph = { ...(m.bond_graph ?? {}) }
        for (const g of m.groups) {
            const names = g.bonds.map((b) => b.name)
            for (const name of names) graph[name] = names
        }
        return msgpack_response(mp.encode(graph))
    }

    // ─── shared render core ───
    // Run a group's cells with bond values from `get_raw(name)` and return
    // [{id, kind, body}]. Used by BOTH the Pluto staterequest path and the lean
    // Therapy __pi_renderAll path → one marshalling implementation, no drift.
    const render_group_cells = (group, get_raw) => {
      // The wasm instance's canvas imports forward through group._ctx. Serialize
      // every invocation (lean page and legacy staterequest alike) so overlapping
      // input events can never redirect one render into another frame's context.
      const run = group._render_tail.catch(() => {}).then(async () => {
        const { ex, read_str, canvas_api } = await load_group(group)
        // args in manifest order; untouched bonds default to initial values.
        // transform tables map raw widget values (what the client sends) to what
        // the notebook actually sees (transform_value); rebuilt INSIDE wasm.
        const deep_eq = (a, b) => JSON.stringify(a) === JSON.stringify(b)
        const args = group.bonds.map((b) => {
            let v = get_raw(b.name)
            if (v !== undefined && b.transform) {
                const hit = b.transform.find((pair) => deep_eq(pair[0], v))
                if (hit) v = hit[1]
            }
            return build(ex, b.desc, value_tree(b.desc, v ?? b.initial))
        })
        // Render a complete frame into a detached back buffer. Presentation is a
        // separate operation: lean pages copy this buffer into a permanently
        // mounted canvas on the next animation frame. No PNG encode or DOM swap.
        const render_canvas = (cell) => {
            const w = Number(cell.desc?.w ?? 640), h = Number(cell.desc?.h ?? 480)
            const cv = canvas_api?.create_back_buffer
                ? canvas_api.create_back_buffer(w, h)
                : typeof OffscreenCanvas === "function"
                  ? new OffscreenCanvas(w, h)
                  : document.createElement("canvas")
            cv.width = w
            cv.height = h
            group._ctx = cv.getContext("2d")
            try { ex[cell.fn](...args) } finally { group._ctx = null }
            return { frame: cv, w, h, present_frame: canvas_api?.present_frame ?? null }
        }
        return group.cells.map((cell) => {
            if (cell.kind === "tree") {
                const walked = walk_ex(ex, cell.desc, ex[cell.fn](...args))
                // body = Pluto tree object (legacy staterequest path renders via mime);
                // html = a real HTML string (lean __pi_renderAll path sets innerHTML).
                return { id: cell.id, kind: cell.kind,
                         body: pluto_tree_body(cell.desc, walked),
                         html: tree_to_html(walked) }
            }
            if (cell.kind === "canvas")
                return { id: cell.id, kind: cell.kind, ...render_canvas(cell) }
            const s = read_str(ex[cell.fn](...args))
            return { id: cell.id, kind: cell.kind, body: s, html: s }
        })
      })
      group._render_tail = run.then(() => undefined, () => undefined)
      return run
    }

    // The classic Pluto staterequest protocol can only carry serialized HTML.
    // Keep that compatibility path isolated; the lean/static runtime below never
    // encodes frames and therefore never replaces its visible canvas.
    const legacy_canvas_html = (cell) => {
        const cv = document.createElement("canvas")
        cv.width = cell.w
        cv.height = cell.h
        cv.getContext("2d").drawImage(cell.frame, 0, 0)
        return `<img class="wasmmakie-island" width="${cell.w}" height="${cell.h}" src="${cv.toDataURL()}">`
    }

    const handle_staterequest = async (bonds_u8, passthrough) => {
        const m = await load_manifest()
        const bonds = mp.decode(bonds_u8)
        const sent = Object.keys(bonds)
        const group = m.groups.find((g) => g.bonds.some((b) => sent.includes(b.name)))
        if (!group) {
            // not an island group — let the precomputed staterequest files /
            // live slider server (if any) answer over the network
            console.log("🏝️ staterequest passthrough (fallback group):", sent)
            return passthrough()
        }
        console.log("🏝️ staterequest served by wasm island:", bonds)
        const cells = await render_group_cells(group, (name) => bonds[name]?.value)
        // Patch shape mirrors a real PSS staterequest response exactly
        // (run_bonds_get_patches → Firebasey.diff): body + output.last_run_timestamp
        // (which CellOutput uses to invalidate) + persist_js_state + logs + runtime.
        const patches = []
        for (const cell of cells) {
            const body = cell.kind === "canvas" ? legacy_canvas_html(cell) : cell.body
            patches.push({ op: "replace", path: ["cell_results", cell.id, "logs"], value: [] })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "output", "body"], value: body })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "output", "persist_js_state"], value: true })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "output", "last_run_timestamp"], value: Date.now() / 1000 })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "runtime"], value: 1000 })
        }
        return msgpack_response(mp.encode({ patches }))
    }

    // ─── lean Therapy runtime: drive islands directly from HTML inputs ───
    // ─── lean-page frame scheduler ───
    // One stable visible canvas per cell, detached back buffers, and one atomic
    // presentation phase per browser frame. Rapid slider events coalesce to the
    // newest complete bond snapshot; obsolete renders are discarded, never shown.
    let lean_seq = 0
    let lean_latest = {}
    let lean_running = false
    let lean_scheduled = false
    let lean_waiters = []
    const on_animation_frame = (f) => new Promise((resolve) =>
        requestAnimationFrame(() => { f(); resolve() }))

    const present_canvas = (cell, mount, seq) => {
        let front = mount.querySelector("canvas.wasmmakie-island, canvas")
        if (!front) {
            front = document.createElement("canvas")
            mount.replaceChildren(front)
        }
        front.classList.add("wasmmakie-island")
        if (front.width !== cell.w) front.width = cell.w
        if (front.height !== cell.h) front.height = cell.h
        if (cell.present_frame) {
            cell.present_frame(front, cell.frame, cell.w, cell.h, seq)
        } else {
            const ctx = front.getContext("2d")
            ctx.setTransform(1, 0, 0, 1, 0, 0)
            ctx.clearRect(0, 0, cell.w, cell.h)
            ctx.drawImage(cell.frame, 0, 0)
            front.dataset.wasmmakieDone = "1"
            front.dataset.wasmmakieFrame = String(seq)
            // Older exported notebooks may embed WasmMakie glue from before
            // canvas2d_present_frame existed. The compatibility presenter must
            // expose the same observable commit contract as the canonical
            // provider so coalescing remains measurable and testable.
            front.dataset.wasmmakiePresentation = String(
                Number(front.dataset.wasmmakiePresentation || 0) + 1)
        }
    }

    const show_runtime_failure = (group, e) => {
        console.warn("🏝️ island render failed:", e)
        for (const cell of group.cells ?? []) {
            const mount = document.getElementById("out-" + cell.id)
            if (mount && !mount.querySelector("." + WARN_CLASS))
                mount.prepend(warning_node({
                    id: null,
                    reasons: [],
                    diag: { kind: "runtime", construct: "the compiled island threw while rendering in your browser: " + ((e && e.message) || String(e)) },
                }, null))
        }
    }

    const schedule_lean_render = () => {
        if (lean_scheduled || lean_running) return
        lean_scheduled = true
        requestAnimationFrame(run_lean_render)
    }

    const run_lean_render = async () => {
        lean_scheduled = false
        if (lean_running) return
        lean_running = true
        const seq = lean_seq
        const values = lean_latest
        const rendered = []
        const failures = []
        let fatal = null
        try {
            const m = await load_manifest()
            for (const group of m.groups) {
                try {
                    rendered.push(...await render_group_cells(group, (name) => values[name]))
                } catch (e) {
                    failures.push([group, e])
                }
            }
            // A newer input arrived while wasm was drawing. Keep the old visible
            // frame intact and discard this obsolete back buffer wholesale.
            if (seq === lean_seq) {
                await on_animation_frame(() => {
                    for (const c of rendered) {
                        const mount = document.getElementById("out-" + c.id)
                        if (!mount) continue
                        if (c.kind === "canvas") present_canvas(c, mount, seq)
                        else mount.innerHTML = c.html ?? c.body
                    }
                    for (const [group, e] of failures) show_runtime_failure(group, e)
                })
                const done = lean_waiters.filter((w) => w.seq <= seq)
                lean_waiters = lean_waiters.filter((w) => w.seq > seq)
                done.forEach((w) => w.resolve())
            }
        } catch (e) {
            fatal = e
            console.warn("🏝️ island scheduler failed:", e)
        } finally {
            lean_running = false
            if (fatal && seq === lean_seq) {
                const done = lean_waiters.filter((w) => w.seq <= seq)
                lean_waiters = lean_waiters.filter((w) => w.seq > seq)
                done.forEach((w) => w.reject(fatal))
            } else if (seq !== lean_seq) schedule_lean_render()
        }
    }

    // The lean exported page calls this with a complete bond snapshot. The
    // returned promise resolves when that snapshot—or a newer superseding one—
    // has been presented, preserving the existing host contract.
    window.__pi_renderAll = (bondValues) => {
        lean_latest = bondValues
        const seq = ++lean_seq
        const promise = new Promise((resolve, reject) => lean_waiters.push({ seq, resolve, reject }))
        schedule_lean_render()
        return promise
    }

    window.fetch = (resource, options) => {
        // resource may be a string, URL, or Request
        const url = typeof resource === "string" ? resource : (resource.href ?? resource.url ?? "")
        const passthrough = () => orig_fetch(resource, options)
        const wrap = (p) => p.catch((e) => { console.error("🏝️ shim error, passing through:", e); return passthrough() })
        const m_get = url.match(/staterequest\/[^/]+\/([^/?]+)/)
        if (m_get) return wrap(handle_staterequest(b64url_decode(m_get[1]), passthrough))
        if (/staterequest\/[^/]+\/?(\?|$)/.test(url) && options?.method === "POST")
            return wrap(handle_staterequest(new Uint8Array(options.body), passthrough))
        if (/bondconnections\/[^/]+\/?$/.test(url)) return wrap(handle_bondconnections(passthrough))
        return passthrough()
    }

    // ─── fallback-warning chrome ───
    // Cells that are part of a @bind group but did NOT make it into a wasm
    // island get a Pluto-native admonition (the `!!! warning` styling that
    // Pluto's own CSS already ships), with the precise compile/oracle reasons
    // in an expander. Driven by report.json; gated by manifest.fallback_warnings
    // (hybrid setups with a live/precompute backend disable it — those cells
    // ARE interactive, just not via wasm).
    const WARN_CLASS = "pss-island-fallback-warning"

    // Token-themed card styles: DaisyUI --color-* variables (shipped by the export
    // head) with plain fallbacks so the classic Pluto export renders fine too.
    const CARD_CSS = `
    .${WARN_CLASS} .snap-card{border:1px solid color-mix(in srgb, var(--color-warning,#f59e0b) 45%, transparent);
      border-left:4px solid var(--color-warning,#f59e0b);border-radius:.5rem;
      background:color-mix(in srgb, var(--color-warning,#f59e0b) 7%, var(--color-base-100,#fff));
      color:var(--color-base-content,#1f2937);padding:.7rem .9rem;margin:.4rem 0;font-size:.86em;line-height:1.45}
    .${WARN_CLASS} .snap-card-title{font-weight:700;display:flex;align-items:center;gap:.45rem;margin:0 0 .35rem}
    .${WARN_CLASS} .snap-chip{display:inline-block;border-radius:.35rem;padding:.05rem .45rem;margin:0 .2rem .2rem 0;
      font-family:ui-monospace,monospace;font-size:.85em;
      background:color-mix(in srgb, var(--color-primary,#3b82f6) 12%, var(--color-base-100,#fff));
      border:1px solid color-mix(in srgb, var(--color-primary,#3b82f6) 30%, transparent)}
    .${WARN_CLASS} .snap-why{margin:.4rem 0;padding:.45rem .6rem;border-radius:.4rem;
      background:var(--color-base-200,#f4f4f5);font-family:ui-monospace,monospace;font-size:.92em;white-space:pre-wrap}
    .${WARN_CLASS} .snap-loc-link{cursor:pointer;text-decoration:underline dotted;color:var(--color-primary,#2563eb)}
    .${WARN_CLASS} .snap-row{display:flex;gap:.5rem;align-items:center;flex-wrap:wrap;margin-top:.45rem}
    .${WARN_CLASS} .snap-btn{cursor:pointer;border-radius:.4rem;padding:.25rem .7rem;font-size:.9em;font-weight:600;
      border:1px solid color-mix(in srgb, var(--color-base-content,#1f2937) 25%, transparent);
      background:var(--color-base-100,#fff);color:var(--color-base-content,#1f2937)}
    .${WARN_CLASS} .snap-btn:hover{background:var(--color-base-200,#f4f4f5)}
    .${WARN_CLASS} details{margin-top:.4rem}
    .${WARN_CLASS} summary{cursor:pointer;font-size:.9em;opacity:.8}
    .${WARN_CLASS} pre{font-size:.78em;white-space:pre-wrap;overflow-x:auto;opacity:.9;margin:.3rem 0 0}`
    let card_css_injected = false
    const ensure_card_css = () => {
        if (card_css_injected) return
        const st = document.createElement("style")
        st.textContent = CARD_CSS
        document.head.append(st)
        card_css_injected = true
    }

    // strip the sandbox-module gensym from diagnostic text ("Main.var\"##SnapshotCompile#287\".string" → "string")
    // (matches the legacy PlutoIslandCompile name too, so pre-rename exports still clean up)
    const clean_diag_text = (s) =>
        (s ?? "").replace(/(?:Main\.)?var"##(?:Snapshot|PlutoIsland)Compile#\d+"\./g, "")

    const KIND_PHRASE = {
        unsupported_method: "a call WasmTarget cannot lower",
        unsupported_intrinsic: "an unsupported intrinsic",
        unsupported_type: "an unsupported type",
        value_stub: "an operation that would compute a wrong value",
        ir_node: "an unsupported IR construct",
        validation: "an emitted-module validation failure",
        runtime: "a runtime error in the browser",
    }

    // scroll-to + flash the offending cell (lean export mount or classic Pluto DOM)
    const jump_to_cell = (id) => {
        const el = document.getElementById("out-" + id)
                || document.querySelector(`pluto-cell[id="${id}"]`)
        if (!el) return
        el.scrollIntoView({ behavior: "smooth", block: "center" })
        el.animate([{ outline: "3px solid var(--color-warning,#f59e0b)", outlineOffset: "4px" },
                    { outline: "3px solid transparent", outlineOffset: "4px" }],
                   { duration: 1800, easing: "ease-out" })
    }

    // the copy-pasteable AI/bug-report context block (Pluto "Ask AI" shape)
    const ai_context = (cell, group) => {
        const d = cell.diag ?? {}
        const bonds = (group.bonds ?? []).map((b, i) =>
            `@bind ${b}${group.arg_types?.[i] ? "::" + group.arg_types[i] : ""}`).join(" · ")
        const lines = [
            "<snapshot-wasm-failure-context>",
            "This is from a Pluto.jl notebook exported with Snapshot.jl. A cell that",
            "depends on @bind inputs failed to compile to WebAssembly via WasmTarget.jl,",
            "so it falls back to non-interactive in the export.",
            "",
            `Bound inputs: ${bonds || "(unknown)"}`,
            "",
        ]
        if (cell.code) lines.push("The affected cell's code:", "```julia", cell.code, "```", "")
        if (d.construct) {
            lines.push(`Compiler diagnostic: [${d.kind}] in \`${clean_diag_text(d.func) || "?"}\`` +
                       (d.loc ? ` at ${d.loc}` : "") + `: ${clean_diag_text(d.construct)}`, "")
        }
        if (cell.offending_code) {
            lines.push("The diagnostic points into a DIFFERENT cell; its code:",
                       "```julia", cell.offending_code, "```", "")
        }
        if (d.ledger && d.ledger.length > 1) {
            lines.push("Full compiler ledger:")
            for (const l of d.ledger) lines.push(`  [${l.kind}] in \`${l.func}\`${l.loc ? " at " + l.loc : ""}: ${l.construct}`)
            lines.push("")
        }
        if (!d.construct) lines.push("Raw failure reasons:", ...(cell.reasons ?? []), "")
        lines.push(
            "WasmTarget compiles a strict, type-stable subset of Julia to WasmGC.",
            "When suggesting fixes: keep each cell as its own code block, keep global",
            "variable names as they are, and prefer making the flagged code type-stable",
            "(concrete types for @bind inputs, typeasserts, avoiding Any containers).",
            "</snapshot-wasm-failure-context>")
        return lines.join("\n")
    }

    const warning_node = (cell, group) => {
        ensure_card_css()
        const wrap = document.createElement("div")
        wrap.className = "markdown " + WARN_CLASS
        const card = document.createElement("div")
        card.className = "snap-card"

        const title = document.createElement("p")
        title.className = "snap-card-title"
        title.textContent = "⚡ Not interactive in this export"
        card.append(title)

        // bound inputs as chips
        if (group?.bonds?.length) {
            const p = document.createElement("p")
            p.append("Bound inputs: ")
            group.bonds.forEach((b, i) => {
                const chip = document.createElement("span")
                chip.className = "snap-chip"
                chip.textContent = "@bind " + b + (group.arg_types?.[i] ? "::" + group.arg_types[i] : "")
                p.append(chip)
            })
            card.append(p)
        }

        const d = cell?.diag
        if (d && d.construct) {
            const why = document.createElement("div")
            why.className = "snap-why"
            const kind = KIND_PHRASE[d.kind] ?? d.kind
            why.append(`This cell hit ${kind}:\n${clean_diag_text(d.construct)}`)
            if (d.func) why.append(`\n— while compiling \`${d.func}\`` + (d.loc ? ` (${d.loc})` : ""))
            card.append(why)
            // deep link to the offending cell when the diagnostic names a DIFFERENT one
            if (d.cell && d.cell !== cell.id) {
                const p = document.createElement("p")
                const a = document.createElement("span")
                a.className = "snap-loc-link"
                a.textContent = "→ the failure originates in another cell — click to jump there"
                a.onclick = () => jump_to_cell(d.cell)
                p.append(a)
                card.append(p)
            }
        } else {
            const body = document.createElement("p")
            body.textContent =
                "This cell depends on a @bind input, but it could not be compiled " +
                "to WebAssembly — it will not update when you move the control."
            card.append(body)
        }

        // actions: copy AI context + details ledger
        const row = document.createElement("div")
        row.className = "snap-row"
        const copy = document.createElement("button")
        copy.className = "snap-btn"
        copy.textContent = "Copy AI context"
        copy.onclick = async () => {
            try {
                await navigator.clipboard.writeText(ai_context(cell ?? {}, group ?? {}))
                copy.textContent = "Copied ✓"
                setTimeout(() => (copy.textContent = "Copy AI context"), 1600)
            } catch { copy.textContent = "Copy failed" }
        }
        row.append(copy)
        card.append(row)

        const reasons = cell?.reasons ?? []
        const ledger = d?.ledger ?? []
        if (reasons.length > 0 || ledger.length > 0) {
            const det = document.createElement("details")
            const sum = document.createElement("summary")
            sum.textContent = "details"
            const pre = document.createElement("pre")
            pre.textContent = [
                ...ledger.map((l) => `[${l.kind}] in ${clean_diag_text(l.func)}${l.loc ? " at " + l.loc : ""}: ${clean_diag_text(l.construct)}`),
                ...(ledger.length && reasons.length ? [""] : []),
                ...reasons,
            ].join("\n")
            det.append(sum, pre)
            card.append(det)
        }

        wrap.append(card)
        return wrap
    }

    const decorate = async () => {
        const m = await load_manifest()
        if (!m.fallback_warnings) return
        const report = await load_report()
        if (!report) return
        for (const group of report) {
            for (const cell of group.cells ?? []) {
                if (cell.ok) continue
                // lean export mount (#out-<id>) first, classic Pluto DOM as fallback —
                // without this the compile-time fallback warning never showed in the
                // lean therapy export (the duo / combine()-widget cell looked plain).
                const host = document.getElementById("out-" + cell.id)
                          || document.querySelector(`pluto-cell[id="${cell.id}"] pluto-output > div`)
                if (!host || host.querySelector(`.${WARN_CLASS}`)) continue
                host.prepend(warning_node(cell, group))
            }
        }
    }

    let report_promise = null
    const load_report = () => {
        report_promise ??= orig_fetch(new URL("report.json", assets_base))
            .then((r) => (r.ok ? r.json() : null))
            .catch(() => null)
        return report_promise
    }

    // decorate once the editor has rendered cells, and keep decorations alive
    // across re-renders (idempotent — settles after one observer round-trip)
    let decorate_scheduled = null
    const schedule_decorate = () => {
        clearTimeout(decorate_scheduled)
        decorate_scheduled = setTimeout(() => decorate().catch(() => {}), 400)
    }
    new MutationObserver(schedule_decorate).observe(document.documentElement, { childList: true, subtree: true })
    schedule_decorate()

    console.log("🏝️ wasm islands shim installed (fetch interception active)")
})()
