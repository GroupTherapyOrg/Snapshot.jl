// Browser E2E for canvas (WasmMakie figure) cells — serves an exported dir,
// opens the figure notebook, moves the range bond, asserts the figure cell
// repaints a persistent visible canvas whose pixels CHANGE between bond values.
// Rapid input is latest-wins, the canvas node is never replaced, and no request
// reaches a Julia server. No Julia process anywhere.
//
// Run:  node test/e2e_canvas.mjs <exported-dir> figure.html

import http from "node:http"
import fs from "node:fs"
import path from "node:path"
import { createRequire } from "node:module"
import { fileURLToPath } from "node:url"

const HERE = path.dirname(fileURLToPath(import.meta.url))
const OUT = process.argv[2]
const PAGE = process.argv[3] ?? "figure.html"
const FIG_CELL = "bb000003-0000-4000-8000-000000000003"
const MD_CELL = "bb000004-0000-4000-8000-000000000004"

const candidates = [
    process.env.PLAYWRIGHT_NODE_MODULES,
    path.join(HERE, "..", "node_modules/"),
    path.join(HERE, "..", "..", "Therapy.jl", "node_modules/"), path.join(HERE, "..", "..", "..", "Therapy.jl", "node_modules/"),
].filter(Boolean)
let chromium = null
for (const c of candidates) {
    try {
        chromium = createRequire(c.endsWith("/") ? c : c + "/")("playwright").chromium
        break
    } catch {}
}
if (!chromium) {
    console.error("playwright not found — skipping browser E2E")
    process.exit(2)
}

const MIME = {
    ".html": "text/html",
    ".js": "text/javascript",
    ".json": "application/json",
    ".wasm": "application/wasm",
    ".plutostate": "application/octet-stream",
    ".jl": "text/julia",
}

const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost")
    let file = path.join(OUT, decodeURIComponent(url.pathname))
    if (url.pathname === "/") file = path.join(OUT, PAGE)
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
        res.writeHead(404)
        res.end("not found: " + url.pathname)
        return
    }
    res.writeHead(200, { "Content-Type": MIME[path.extname(file)] ?? "application/octet-stream" })
    fs.createReadStream(file).pipe(res)
})

const fail = (msg) => {
    console.error("❌ " + msg)
    process.exit(1)
}

await new Promise((resolve) => server.listen(0, resolve))
const port = server.address().port
console.log(`serving ${OUT} on :${port}`)

const browser = await chromium.launch()
const page = await browser.newPage()

const island_logs = []
const browser_errors = []
page.on("console", (msg) => {
    const text = msg.text()
    if (text.includes("🏝️")) island_logs.push(text)
    if (msg.type() === "error" || msg.type() === "warning") browser_errors.push(`${msg.type()}: ${text}`)
})
page.on("pageerror", (err) => browser_errors.push("pageerror: " + err.message))
let leaked_staterequests = 0
page.on("request", (req) => {
    if (req.url().includes("staterequest")) leaked_staterequests++
})

await page.goto(`http://localhost:${port}/${encodeURIComponent(PAGE)}`, { waitUntil: "domcontentloaded" })

const slider = page.locator("input[type=range]")
await slider.waitFor({ state: "attached", timeout: 60_000 })
await page.waitForTimeout(2000)

const canvas_sel = `#out-${FIG_CELL} canvas.wasmmakie-island`
const move = async (v) => {
    await slider.evaluate((el, val) => {
        el.value = val
        el.dispatchEvent(new Event("input", { bubbles: true }))
    }, String(v))
}

const canvas_state = async () => page.locator(canvas_sel).evaluate((cv) => {
    const data = cv.getContext("2d").getImageData(0, 0, cv.width, cv.height).data
    // A cheap deterministic pixel fingerprint; sampling keeps the E2E fast.
    let hash = 2166136261
    for (let i = 0; i < data.length; i += 97)
        hash = Math.imul(hash ^ data[i], 16777619) >>> 0
    return {
        hash,
        frame: Number(cv.dataset.wasmmakieFrame || 0),
        presentations: Number(cv.dataset.wasmmakiePresentation || 0),
    }
})

// Move the bond → the figure cell must paint into a stable visible canvas.
await move(5)
try {
    await page.waitForSelector(canvas_sel, { timeout: 30_000 })
} catch (e) {
    console.error("browser diagnostics:\n" + browser_errors.concat(island_logs).join("\n"))
    console.error("figure output: " + await page.locator(`#out-${FIG_CELL}`).innerHTML().catch(() => "<missing>"))
    throw e
}
await page.waitForFunction((sel) => document.querySelector(sel)?.dataset.wasmmakieDone === "1", canvas_sel)
await page.locator(canvas_sel).evaluate((cv) => {
    window.__wasmmakieCanvas = cv
    window.__wasmmakieRemoved = 0
    new MutationObserver(() => {
        if (!window.__wasmmakieCanvas?.isConnected) window.__wasmmakieRemoved++
    }).observe(document.documentElement, { childList: true, subtree: true })
})
const state5 = await canvas_state()

// md cell updated by the same staterequest
const md_text = await page.locator(`#out-${MD_CELL}`).innerText()
if (!md_text.includes("5")) fail("md cell did not update: " + JSON.stringify(md_text))

// Burst inputs without awaiting frames. Only the newest complete snapshot may
// present; obsolete back buffers must never replace or detach the front canvas.
await slider.evaluate((el, values) => {
    for (const v of values) {
        el.value = String(v)
        el.dispatchEvent(new Event("input", { bubbles: true }))
    }
}, [1, 2, 3, 4, 2, 1])
await page.waitForFunction(
    ([sel, prev]) => {
        const cv = document.querySelector(sel)
        return cv === window.__wasmmakieCanvas && Number(cv?.dataset.wasmmakieFrame || 0) > prev
    },
    [canvas_sel, state5.frame],
    { timeout: 30_000 },
)
const state1 = await canvas_state()
if (state1.hash === state5.hash) fail("figure canvas pixels did not change between n=5 and n=1")
if (state1.presentations !== state5.presentations + 1)
    fail(`rapid burst presented ${state1.presentations - state5.presentations} front frames instead of one`)
const lifecycle = await page.evaluate(() => ({
    same: window.__wasmmakieCanvas?.isConnected,
    removed: window.__wasmmakieRemoved,
    images: document.querySelectorAll("img.wasmmakie-island").length,
}))
if (!lifecycle.same || lifecycle.removed !== 0) fail("visible canvas was replaced during interaction")
if (lifecycle.images !== 0) fail("lean runtime regressed to serialized canvas images")

const final_md = await page.locator(`#out-${MD_CELL}`).innerText()
if (!final_md.includes("1")) fail("rapid input did not settle on latest markdown state: " + JSON.stringify(final_md))

if (leaked_staterequests > 0) fail(`${leaked_staterequests} staterequest(s) leaked to the network`)
if (!island_logs.some((l) => l.includes("islands manifest"))) fail("no island manifest console log seen")

console.log("island console activity:")
island_logs.forEach((l) => console.log("   " + l))
console.log("✅ E-004 PASS: slider burst → persistent canvas → latest frame, zero Julia")

await browser.close()
server.close()
process.exit(0)
