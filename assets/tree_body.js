// pluto_tree_body — replicate PlutoRunner's tree_data format for vector
// values, from a bridge-walked tagged tree. Shared verbatim between the
// browser shim and the export-time verify/oracle Node scripts, so the body
// that ships is byte-for-byte the body that was verified against native.
//
// Format (PlutoRunner tree viewer.jl): { prefix, prefix_short, objectid,
// type: "Array", elements: [[i, [leaf_body, mime]], ..., "more"?, ...] }
// with limit 30 at depth 0 (all if length ≤ 36, else first 20 + "more" +
// last 10), halved-ish per depth: limit(depth) = 30 ÷ (1 + 2·depth).
const _TREE_DV = new DataView(new ArrayBuffer(8))
const _julia_float_str = (bitsStr) => {
    _TREE_DV.setBigUint64(0, BigInt.asUintN(64, BigInt(bitsStr)))
    const v = _TREE_DV.getFloat64(0)
    if (Number.isNaN(v)) return "NaN"
    if (v === Infinity) return "Inf"
    if (v === -Infinity) return "-Inf"
    let s = String(v)
    if (s.includes("e")) {
        s = s.replace("e+", "e")
        if (!s.split("e")[0].includes(".")) s = s.replace("e", ".0e")
        return s
    }
    if (!s.includes(".")) s += ".0"
    return s
}
const _tree_leaf = (d, t) => {
    switch (d.k) {
        case "int": return d.w === 1 ? (t.x === "1" || t.x === "true" ? "true" : "false") : t.x
        case "bits": return _julia_float_str(t.x)
        case "char": return "'" + String.fromCodePoint(Number(t.x)) + "'"
        case "str": return JSON.stringify(new TextDecoder().decode(Uint8Array.from(t.s)))
        default: throw new Error("tree leaf unsupported: " + d.k)
    }
}
const _tree_limit = (depth) => Math.floor(30 / (1 + 2 * depth))
const pluto_tree_body = (d, t, depth = 0) => {
    if (d.k === "fields") {
        // Tuple / NamedTuple: no prefix, no truncation (PlutoRunner tree_data)
        const fchild = (fd, ft) =>
            fd.k === "vec" || fd.k === "fields"
                ? [pluto_tree_body(fd, ft, depth + 1), "application/vnd.pluto.tree+object"]
                : [_tree_leaf(fd, ft), "text/plain"]
        const elements = d.fs.map((fd, i) => [
            d.tt === "NamedTuple" ? d.names[i] : i + 1,
            fchild(fd.d, t.f[i]),
        ])
        return {
            objectid: Math.floor(Math.random() * 2 ** 48).toString(16),
            type: d.tt ?? "Tuple",
            elements: elements,
        }
    }
    if (d.k !== "vec") throw new Error("tree body root must be vec")
    const child = (ct) =>
        d.el.k === "vec" || d.el.k === "fields"
            ? [pluto_tree_body(d.el, ct, depth + 1), "application/vnd.pluto.tree+object"]
            : [_tree_leaf(d.el, ct), "text/plain"]
    const n = t.a.length
    const limit = Math.max(_tree_limit(depth), 0)
    let elements
    if (n <= Math.floor((limit * 6) / 5)) {
        elements = t.a.map((ct, i) => [i + 1, child(ct)])
    } else {
        const fromEnd = limit > 20 ? 10 : limit > 1 ? 1 : 0
        elements = []
        for (let i = 0; i < limit - fromEnd; i++) elements.push([i + 1, child(t.a[i])])
        elements.push("more")
        for (let i = n - fromEnd; i < n; i++) elements.push([i + 1, child(t.a[i])])
    }
    return {
        prefix: d.prefix ?? "Any",
        prefix_short: d.prefix_short ?? "",
        objectid: Math.floor(Math.random() * 2 ** 48).toString(16),
        type: "Array",
        elements: elements,
    }
}
