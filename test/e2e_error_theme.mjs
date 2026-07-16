// Browser regression for Pluto-faithful, theme-token-driven exported errors.
// Run: node test/e2e_error_theme.mjs <exported-dir>

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

const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost")
    const file = path.join(OUT, decodeURIComponent(url.pathname))
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
        res.writeHead(404)
        res.end("not found")
        return
    }
    res.writeHead(200, { "Content-Type": "text/html" })
    fs.createReadStream(file).pipe(res)
})
const assert = (condition, message) => {
    if (!condition) throw new Error(message)
}

await new Promise((resolve) => server.listen(0, resolve))
const origin = `http://localhost:${server.address().port}`
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1200, height: 800 } })
await page.goto(`${origin}/error_output.html`, { waitUntil: "domcontentloaded" })

for (const theme of ["fun-light", "fun-dark", "classic-light", "classic-dark"]) {
    const result = await page.locator("jlerror").evaluate((error, theme) => {
        document.documentElement.dataset.theme = theme
        const probe = document.createElement("i")
        probe.style.cssText = "position:absolute;background:var(--color-base-100)"
        document.body.append(probe)
        const expectedSurface = getComputedStyle(probe).backgroundColor
        probe.remove()
        const header = error.querySelector("header")
        return {
            expectedSurface,
            headerSurface: getComputedStyle(header).backgroundColor,
            overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
            scripts: error.querySelectorAll("script").length,
            hasPre: error.querySelector("pre") !== null,
            message: header.textContent,
        }
    }, theme)
    assert(result.headerSurface === result.expectedSurface,
        `${theme}: error message surface bypasses --color-base-100`)
    assert(result.overflow === 0, `${theme}: error creates horizontal overflow`)
    assert(result.scripts === 0, `${theme}: escaped exception text became executable markup`)
    assert(result.hasPre === false, `${theme}: legacy hybrid <pre> error markup remains`)
    assert(result.message.includes("<script>alert(1)</script>&"),
        `${theme}: exception text was lost or double-escaped`)
}

console.log("✅ exported errors preserve Pluto semantics across fun/classic light and dark themes")
await browser.close()
server.close()
