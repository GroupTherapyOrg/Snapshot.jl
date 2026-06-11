// PlutoIslands shim — the wasm-island slider "server", running in this tab.
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
                m.groups.forEach((g) => (g._instance = null))
                return m
            })
        return manifest_promise
    }

    const load_group = (group) => {
        group._instance ??= (async () => {
            const wasm_resp = await orig_fetch(new URL(group.wasm, assets_base))
            const mod = await WebAssembly.compileStreaming(wasm_resp)
            const imports = {}
            for (const imp of WebAssembly.Module.imports(mod)) {
                ;(imports[imp.module] ||= {})[imp.name] = imp.module === "Math" ? Math[imp.name] : () => 0
            }
            const ex = (await WebAssembly.instantiate(mod, imports)).exports
            const read_str = (ref) => {
                const len = Number(ex._str_len(ref))
                const bytes = new Uint8Array(len)
                for (let i = 1; i <= len; i++) bytes[i - 1] = Number(ex._str_byte(ref, BigInt(i)))
                return new TextDecoder().decode(bytes)
            }
            console.log(`🏝️ island loaded: ${group.wasm} [${group.bonds.map((b) => b.name).join(", ")}]`)
            return { ex, read_str }
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
        const { ex, read_str } = await load_group(group)
        // args in manifest order; untouched bonds default to initial values.
        // Each value is rebuilt INSIDE wasm via the bridge constructor closure.
        const args = group.bonds.map((b) => build(ex, b.desc, value_tree(b.desc, bonds[b.name]?.value ?? b.initial)))
        console.log("🏝️ staterequest served by wasm island:", bonds)
        // Patch shape mirrors a real PSS staterequest response exactly
        // (run_bonds_get_patches → Firebasey.diff): body + output.last_run_timestamp
        // (which CellOutput uses to invalidate) + persist_js_state + logs + runtime.
        const patches = []
        for (const cell of group.cells) {
            const body = cell.kind === "tree"
                ? pluto_tree_body(cell.desc, walk_ex(ex, cell.desc, ex[cell.fn](...args)))
                : read_str(ex[cell.fn](...args))
            patches.push({ op: "replace", path: ["cell_results", cell.id, "logs"], value: [] })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "output", "body"], value: body })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "output", "persist_js_state"], value: true })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "output", "last_run_timestamp"], value: Date.now() / 1000 })
            patches.push({ op: "replace", path: ["cell_results", cell.id, "runtime"], value: 1000 })
        }
        return msgpack_response(mp.encode({ patches }))
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

    const warning_node = (reasons) => {
        const wrap = document.createElement("div")
        wrap.className = "markdown " + WARN_CLASS
        const adm = document.createElement("div")
        adm.className = "admonition warning"
        const title = document.createElement("p")
        title.className = "admonition-title"
        title.textContent = "⚡ Not interactive in this export"
        const body = document.createElement("p")
        body.textContent =
            "This cell depends on a @bind input, but it could not be compiled " +
            "to WebAssembly — it will not update when you move the control."
        adm.append(title, body)
        if (reasons && reasons.length > 0) {
            const det = document.createElement("details")
            const sum = document.createElement("summary")
            sum.textContent = "why?"
            sum.style.cursor = "pointer"
            const pre = document.createElement("pre")
            pre.style.cssText = "font-size:.72em;white-space:pre-wrap;overflow-x:auto;opacity:.85"
            pre.textContent = reasons.join("\n")
            det.append(sum, pre)
            adm.append(det)
        }
        wrap.append(adm)
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
                const host = document.querySelector(`pluto-cell[id="${cell.id}"] pluto-output > div`)
                if (!host || host.querySelector(`.${WARN_CLASS}`)) continue
                host.prepend(warning_node(cell.reasons))
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
