// Regression for the user-visible failure mode: an HTML range input can move
// even when its Wasm island never loaded. This test therefore fingerprints the
// rendered canvases before and after moving the Julia-set bond and requires the
// pixels themselves to change.
//
//   node test/e2e_fractals.mjs <export-dir> fractals.html [--file]
//   SNAPSHOT_BROWSER=firefox node test/e2e_fractals.mjs ...

import http from "node:http"
import fs from "node:fs"
import path from "node:path"
import crypto from "node:crypto"
import { createRequire } from "node:module"
import { fileURLToPath, pathToFileURL } from "node:url"

const HERE = path.dirname(fileURLToPath(import.meta.url))
const OUT = process.argv[2]
const PAGE = process.argv[3] ?? "fractals.html"
const FILE_PROTOCOL = process.argv.includes("--file")
const SIMULATE_UNSUPPORTED = process.argv.includes("--simulate-unsupported-wasm")
const WRONG_WASM_MIME = process.argv.includes("--wrong-wasm-mime")
const BROWSER_NAME = process.env.SNAPSHOT_BROWSER ?? "chromium"

const candidates = [
    process.env.PLAYWRIGHT_NODE_MODULES,
    path.join(HERE, "..", "node_modules/"),
    path.join(HERE, "..", "..", "Therapy.jl", "node_modules/"),
].filter(Boolean)
let browserType = null
for (const candidate of candidates) {
    try {
        browserType = createRequire(candidate.endsWith("/") ? candidate : candidate + "/")("playwright")[BROWSER_NAME]
        if (browserType) break
    } catch {}
}
if (!browserType) {
    console.error(`playwright ${BROWSER_NAME} not found — skip`)
    process.exit(2)
}

const MIME = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json", ".wasm": "application/wasm" }
const server = FILE_PROTOCOL ? null : http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost")
    const file = path.join(OUT, decodeURIComponent(url.pathname))
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
        res.writeHead(404); res.end("not found"); return
    }
    const mime = WRONG_WASM_MIME && path.extname(file) === ".wasm"
        ? "application/octet-stream"
        : MIME[path.extname(file)] ?? "application/octet-stream"
    res.writeHead(200, { "Content-Type": mime })
    fs.createReadStream(file).pipe(res)
})
if (server) await new Promise((resolve) => server.listen(0, resolve))

const browser = await browserType.launch()
const page = await browser.newPage()
if (SIMULATE_UNSUPPORTED) await page.addInitScript(() => {
    const unsupported = () => Promise.reject(new WebAssembly.CompileError("simulated unsupported js-string builtins"))
    WebAssembly.compile = unsupported
    WebAssembly.compileStreaming = unsupported
})
const diagnostics = []
const fatalDiagnostics = []
page.on("console", (m) => {
    const message = `${m.type()}: ${m.text()}`
    if (m.type() === "error" || m.type() === "warning" || m.text().includes("🏝️")) diagnostics.push(message)
})
page.on("pageerror", (e) => {
    const message = `pageerror: ${e.message}`
    diagnostics.push(message)
    fatalDiagnostics.push(message)
})
page.on("requestfailed", (request) => {
    const message = `requestfailed: ${request.url()} (${request.failure()?.errorText ?? "unknown error"})`
    diagnostics.push(message)
    fatalDiagnostics.push(message)
})

const url = FILE_PROTOCOL
    ? pathToFileURL(path.resolve(OUT, PAGE)).href
    : `http://localhost:${server.address().port}/${PAGE.split("/").map(encodeURIComponent).join("/")}`
await page.goto(url, { waitUntil: "domcontentloaded" })
await page.waitForSelector('bond[def="julia_cx"] input[type="range"], input[type="range"]', { timeout: 60_000 })
if (SIMULATE_UNSUPPORTED) {
    await page.waitForSelector(".pss-island-fallback-warning", { timeout: 60_000 })
    const warning = (await page.locator(".pss-island-fallback-warning").allTextContents()).join(" ")
    if (!warning.includes("Chrome or Edge 130+") || !warning.includes("Firefox 134+"))
        throw new Error(`unsupported-browser diagnostic is not actionable: ${warning}`)
    console.log(`UNSUPPORTED WASM DIAGNOSTIC PASS: ${BROWSER_NAME}`)
    await browser.close()
    server?.close()
    process.exit(0)
}
await page.waitForFunction(() => document.querySelectorAll("canvas.wasmmakie-island").length >= 2, null, { timeout: 60_000 })
await page.waitForTimeout(1000)

// The first WasmMakie canvas is the Julia-set plot controlled by julia_cx.
// Hash its complete screenshot so a redraw in a different plot cannot pass.
const targetCanvas = page.locator("canvas.wasmmakie-island").first()
const canvasHash = async () => crypto.createHash("sha256").update(await targetCanvas.screenshot()).digest("hex")
const before = await canvasHash()
await page.waitForTimeout(500)
const stable = await canvasHash()
if (stable !== before)
    throw new Error(`target fractal canvas was not stable before interaction\nbefore=${before}\nstable=${stable}`)

const slider = page.locator('bond[def="julia_cx"] input[type="range"]').first()
if (await slider.count() === 0) throw new Error("fractals export has no julia_cx slider")
const sliderBefore = await slider.inputValue()
const sliderAfter = await slider.evaluate((el) => {
    const min = Number(el.min || -2), max = Number(el.max || 2), current = Number(el.value)
    el.value = String(Math.abs(current - min) > Math.abs(current - max) ? min : max)
    el.dispatchEvent(new Event("input", { bubbles: true }))
    el.dispatchEvent(new Event("change", { bubbles: true }))
    return el.value
})
if (sliderAfter === sliderBefore)
    throw new Error(`julia_cx slider value did not change (${sliderBefore})`)

let after = before
for (let waited = 0; waited < 60_000; waited += 250) {
    await page.waitForTimeout(250)
    after = await canvasHash()
    if (after !== before) break
}
if (after === before) {
    const warnings = await page.locator(".pss-island-fallback-warning").allTextContents()
    throw new Error(`slider moved but no fractal canvas pixels changed\nbefore=${before}\nafter=${after}\nwarnings=${warnings.join(" | ")}\n${diagnostics.join("\n")}`)
}
if (fatalDiagnostics.length > 0)
    throw new Error(`fractal changed, but the page emitted fatal browser diagnostics\n${fatalDiagnostics.join("\n")}`)
console.log(`FRACTALS PASS: ${BROWSER_NAME} ${FILE_PROTOCOL ? "file" : (WRONG_WASM_MIME ? "http wrong-MIME fallback" : "http")} ${before} → ${after}`)
await browser.close()
server?.close()
