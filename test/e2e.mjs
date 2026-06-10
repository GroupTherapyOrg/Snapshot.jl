// Browser E2E — serves an exported dir statically, opens the notebook,
// moves the slider, asserts dependent cells repaint with every staterequest
// answered by the in-tab wasm island. No Julia process anywhere.
//
// Run:  node test/islands_e2e.mjs <exported-dir>

import http from "node:http"
import fs from "node:fs"
import path from "node:path"
import { createRequire } from "node:module"
import { fileURLToPath } from "node:url"

const HERE = path.dirname(fileURLToPath(import.meta.url))
const OUT = process.argv[2]
const PAGE = process.argv[3] ?? "notebook.html"

// playwright resolution: $PLAYWRIGHT_NODE_MODULES, repo-local node_modules,
// or a sibling Therapy.jl checkout. Exit 2 (= skip) when unavailable.
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
    console.error("playwright not found (tried: " + candidates.join(", ") + ") — skipping browser E2E")
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
    if (url.pathname === "/") file = path.join(OUT, "notebook.html")
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
// Any *real* network request to staterequest/* would mean the shim failed.
let leaked_staterequests = 0
page.on("request", (req) => {
    if (req.url().includes("staterequest")) leaked_staterequests++
})

await page.goto(`http://localhost:${port}/${encodeURIComponent(PAGE)}`, { waitUntil: "domcontentloaded" })

// Editor hydrated: the CoolSlider bond input exists
const slider = page.locator("pluto-cell input[type=range]")
await slider.waitFor({ state: "attached", timeout: 60_000 })

// Initial render from statefile: y = 1^2 = 1
const md_cell = page.locator('pluto-cell[id="aa000005-0000-4000-8000-000000000005"] pluto-output')
const y_cell = page.locator('pluto-cell[id="aa000004-0000-4000-8000-000000000004"] pluto-output')
if (!(await md_cell.innerText()).includes("is 1")) fail("initial md cell wrong: " + (await md_cell.innerText()))

// Wait for the slider-server client to connect (bond_connections resolved)
await page.waitForFunction(() => true, null, { timeout: 1000 }).catch(() => {})
await page.waitForTimeout(2000)

// Move the slider to 7 → y must become 49
await slider.evaluate((el) => {
    el.value = "7"
    el.dispatchEvent(new Event("input", { bubbles: true }))
})

await page.waitForFunction(
    () => document.querySelector('pluto-cell[id="aa000005-0000-4000-8000-000000000005"] pluto-output')?.innerText?.includes("is 49"),
    null,
    { timeout: 20_000 },
)
const y_text = (await y_cell.innerText()).trim()
if (!y_text.includes("49")) fail(`y cell did not update: ${JSON.stringify(y_text)}`)

// Move again to 100 → 10000 (proves repeated interaction, not a fluke)
await slider.evaluate((el) => {
    el.value = "100"
    el.dispatchEvent(new Event("input", { bubbles: true }))
})
await page.waitForFunction(
    () => document.querySelector('pluto-cell[id="aa000005-0000-4000-8000-000000000005"] pluto-output')?.innerText?.includes("is 10000"),
    null,
    { timeout: 20_000 },
)

if (leaked_staterequests > 0) fail(`${leaked_staterequests} staterequest(s) leaked to the network — shim not intercepting`)
if (!island_logs.some((l) => l.includes("staterequest served by wasm island"))) fail("no island staterequest console log seen")

console.log("island console activity:")
island_logs.forEach((l) => console.log("   " + l))
console.log("✅ M0 PASS: slider → wasm island → cell updates, zero Julia, zero staterequest network traffic")

await browser.close()
server.close()
process.exit(0)
