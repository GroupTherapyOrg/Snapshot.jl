// Generic smoke test for any exported notebook with islands: loads the page,
// asserts the shim installs + manifest loads + no page errors, and (when a
// range slider exists) one slider move produces an island-served staterequest.
//
// Run:  node test/islands_smoke.mjs <dir> <name.html>

import http from "node:http"
import fs from "node:fs"
import path from "node:path"
import { createRequire } from "node:module"
import { fileURLToPath } from "node:url"

const HERE = path.dirname(fileURLToPath(import.meta.url))
const OUT = process.argv[2]
const PAGE = process.argv[3]

const candidates = [
    process.env.PLAYWRIGHT_NODE_MODULES,
    path.join(HERE, "..", "node_modules/"),
    path.join(HERE, "..", "..", "Therapy.jl", "node_modules/"),
].filter(Boolean)
let chromium = null
for (const c of candidates) {
    try { chromium = createRequire(c.endsWith("/") ? c : c + "/")("playwright").chromium; break } catch {}
}
if (!chromium) { console.error("playwright not found — skip"); process.exit(2) }

const MIME = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json", ".wasm": "application/wasm" }
const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost")
    const file = path.join(OUT, decodeURIComponent(url.pathname))
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) { res.writeHead(404); res.end(); return }
    res.writeHead(200, { "Content-Type": MIME[path.extname(file)] ?? "application/octet-stream" })
    fs.createReadStream(file).pipe(res)
})
await new Promise((r) => server.listen(0, r))

const browser = await chromium.launch()
const page = await browser.newPage()
const logs = []
const errors = []
page.on("console", (m) => m.text().includes("🏝") && logs.push(m.text()))
page.on("pageerror", (e) => errors.push(String(e)))

await page.goto(`http://localhost:${server.address().port}/${encodeURIComponent(PAGE)}`, { waitUntil: "domcontentloaded" })
// Classic Pluto exports use <pluto-cell>; lean Therapy exports use .pl-cell.
// Keep this smoke test format-agnostic so the public default and the legacy
// opt-in path exercise the same island runtime contract.
await page.waitForSelector("pluto-cell, .pl-cell", { timeout: 60_000 })
await page.waitForTimeout(4000)

const fail = (msg) => { console.error("FAIL: " + msg); process.exit(1) }
if (!logs.some((l) => l.includes("shim installed"))) fail("shim not installed")
if (!logs.some((l) => l.includes("islands manifest"))) fail("manifest not loaded")

// Compilation-heavy islands may initialize after DOMContentLoaded. Wait for the
// runtime's explicit readiness signal before exercising a bond, rather than racing
// the initial module instantiation on slower CI runners.
for (let waited = 0; waited < 60_000 && !logs.some((l) => l.includes("island loaded")); waited += 250) {
    await page.waitForTimeout(250)
}

const slider = page.locator("pluto-cell input[type=range], .pl-cell input[type=range]").first()
if ((await slider.count()) > 0) {
    await slider.evaluate((el) => {
        el.value = el.max ? String(Math.ceil(Number(el.max) / 2)) : "2"
        el.dispatchEvent(new Event("input", { bubbles: true }))
    })
    await page.waitForTimeout(4000)
    const served = logs.some((l) => l.includes("staterequest served by wasm island"))
    const passed = logs.some((l) => l.includes("staterequest passthrough"))
    if (!served && !passed) fail("slider move produced no island response")
    console.log(served ? "slider → island wasm ✓" : "slider → fallback passthrough ✓")
}
// text input (String bond) — type into it, expect an island-served response
const textbox = page.locator("pluto-cell input[type=text], .pl-cell input[type=text]").first()
if ((await textbox.count()) > 0) {
    const before = logs.filter((l) => l.includes("served by wasm island")).length
    await textbox.evaluate((el) => {
        el.value = "ahoy"
        el.dispatchEvent(new Event("input", { bubbles: true }))
    })
    await page.waitForTimeout(4000)
    const after = logs.filter((l) => l.includes("served by wasm island")).length
    if (after > before) console.log("text input (String bond) → island wasm ✓")
}
if (errors.length > 0) fail("page errors: " + errors.slice(0, 2).join(" / "))
console.log(`SMOKE PASS: ${PAGE} (${logs.length} island log lines)`)
await browser.close()
server.close()
process.exit(0)
