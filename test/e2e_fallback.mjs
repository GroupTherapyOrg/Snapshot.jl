// Browser regression for honest fallback controls.
// Run: node test/e2e_fallback.mjs <exported-dir>

import http from "node:http"
import fs from "node:fs"
import path from "node:path"
import { createRequire } from "node:module"
import { fileURLToPath } from "node:url"

const HERE = path.dirname(fileURLToPath(import.meta.url))
const OUT = process.argv[2]
const candidates = [
    process.env.PLAYWRIGHT_NODE_MODULES,
    path.join(HERE, "..", "node_modules/"),
    path.join(HERE, "..", "..", "Therapy.jl", "node_modules/"),
    path.join(HERE, "..", "..", "..", "Therapy.jl", "node_modules/"),
].filter(Boolean)

let chromium = null
for (const candidate of candidates) {
    try {
        chromium = createRequire(candidate.endsWith("/") ? candidate : candidate + "/")("playwright").chromium
        break
    } catch {}
}
if (!chromium) process.exit(2)

const mime = {
    ".html": "text/html",
    ".js": "text/javascript",
    ".json": "application/json",
    ".wasm": "application/wasm",
}
const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost")
    const file = path.join(OUT, decodeURIComponent(url.pathname))
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
        res.writeHead(404)
        res.end("not found")
        return
    }
    res.writeHead(200, { "Content-Type": mime[path.extname(file)] ?? "application/octet-stream" })
    fs.createReadStream(file).pipe(res)
})

const assert = (condition, message) => {
    if (!condition) throw new Error(message)
}

await new Promise((resolve) => server.listen(0, resolve))
const origin = `http://localhost:${server.address().port}`
const browser = await chromium.launch()
const page = await browser.newPage()

await page.goto(`${origin}/import_required.html`, { waitUntil: "domcontentloaded" })
await page.locator("bond[def] input").waitFor({ state: "attached", timeout: 60_000 })
await page.locator(".pss-island-fallback-bond-status").waitFor({ state: "visible", timeout: 10_000 })
const accessibleStatus = page.getByRole("status", { name: "@bind x — static in this export" })
assert(await accessibleStatus.count() === 1,
       "fallback control has no named status replacement in the accessibility tree")

const fallback = await page.locator("bond[def]").evaluate((bond) => ({
    inert: bond.inert,
    disabled: bond.querySelector("input")?.disabled,
    ariaDisabled: bond.getAttribute("aria-disabled"),
    describedBy: bond.getAttribute("aria-describedby"),
}))
assert(fallback.inert === true, "fallback bond is not inert")
assert(fallback.disabled === true, "fallback native input is not disabled")
assert(fallback.ariaDisabled === "true", "fallback bond lacks aria-disabled")
assert(Boolean(fallback.describedBy), "fallback bond lacks aria-describedby")
assert(await page.locator(`#${fallback.describedBy}`).count() === 1,
       "fallback status node is missing or duplicated")

// Trigger the observer-driven decorator again and prove idempotence.
await page.evaluate(() => document.body.append(document.createElement("i")))
await page.waitForTimeout(800)
assert(await page.locator(".pss-island-fallback-bond-status").count() === 1,
       "fallback decoration is not idempotent")

await page.goto(`${origin}/import_partial.html`, { waitUntil: "domcontentloaded" })
await page.locator("bond[def] input").waitFor({ state: "attached", timeout: 60_000 })
await page.waitForTimeout(800)
const partial = await page.locator("bond[def]").evaluate((bond) => ({
    inert: bond.inert,
    disabled: bond.querySelector("input")?.disabled,
    markedFallback: bond.classList.contains("pss-island-fallback-bond"),
}))
assert(partial.inert === false, "partial-group bond was made inert")
assert(partial.disabled === false, "partial-group input was disabled")
assert(partial.markedFallback === false, "partial-group bond was marked as full fallback")
assert(await page.locator(".pss-island-fallback-bond-status").count() === 0,
       "partial group received a full-fallback status")

console.log("✅ fallback controls are inert, accessible, idempotent; partial controls remain live")
await browser.close()
server.close()
