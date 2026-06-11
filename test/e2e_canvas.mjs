// Browser E2E for canvas (WasmMakie figure) cells — serves an exported dir,
// opens the figure notebook, moves the range bond, asserts the figure cell
// repaints as a shim-rendered <img> whose pixels CHANGE between bond values,
// with every staterequest answered in-tab. No Julia process anywhere.
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
page.on("console", (msg) => {
    const text = msg.text()
    if (text.includes("🏝️")) island_logs.push(text)
})
let leaked_staterequests = 0
page.on("request", (req) => {
    if (req.url().includes("staterequest")) leaked_staterequests++
})

await page.goto(`http://localhost:${port}/${encodeURIComponent(PAGE)}`, { waitUntil: "domcontentloaded" })

const slider = page.locator("pluto-cell input[type=range]")
await slider.waitFor({ state: "attached", timeout: 60_000 })
await page.waitForTimeout(2000)

const img_sel = `pluto-cell[id="${FIG_CELL}"] pluto-output img.wasmmakie-island`
const move = async (v) => {
    await slider.evaluate((el, val) => {
        el.value = val
        el.dispatchEvent(new Event("input", { bubbles: true }))
    }, String(v))
}

// Move the bond → the figure cell must repaint as the shim's rendered <img>
await move(5)
await page.waitForSelector(img_sel, { timeout: 30_000 })
const src5 = await page.locator(img_sel).getAttribute("src")
if (!src5 || !src5.startsWith("data:image/png")) fail("figure img has no data URL src")

// md cell updated by the same staterequest
const md_text = await page.locator(`pluto-cell[id="${MD_CELL}"] pluto-output`).innerText()
if (!md_text.includes("5")) fail("md cell did not update: " + JSON.stringify(md_text))

// Different bond value → different pixels (the wasm render actually depends on n)
await move(1)
await page.waitForFunction(
    ([sel, prev]) => document.querySelector(sel)?.getAttribute("src") !== prev,
    [img_sel, src5],
    { timeout: 30_000 },
)
const src1 = await page.locator(img_sel).getAttribute("src")
if (src1 === src5) fail("figure img did not change between n=5 and n=1")

if (leaked_staterequests > 0) fail(`${leaked_staterequests} staterequest(s) leaked to the network`)
if (!island_logs.some((l) => l.includes("staterequest served by wasm island"))) fail("no island staterequest console log seen")

console.log("island console activity:")
island_logs.forEach((l) => console.log("   " + l))
console.log("✅ E-004 PASS: slider → wasm figure render → canvas img repaints, zero Julia")

await browser.close()
server.close()
process.exit(0)
