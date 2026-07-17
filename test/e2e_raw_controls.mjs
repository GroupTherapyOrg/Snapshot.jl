import fs from "node:fs"
import http from "node:http"
import path from "node:path"
import { pathToFileURL } from "node:url"

const OUT = process.argv[2]
const candidates = [
  "/Users/daleblack/Documents/dev/GroupTherapyOrg/snapshot/worker/node_modules/playwright/index.mjs",
  "playwright",
]
let chromium
for (const candidate of candidates) {
  try {
    ;({ chromium } = await import(candidate.startsWith("/") ? pathToFileURL(candidate) : candidate))
    break
  } catch {}
}
if (!chromium) process.exit(2)

const server = http.createServer((req, res) => {
  const file = path.join(OUT, req.url === "/" ? "raw_controls.html" : req.url)
  if (!fs.existsSync(file)) return res.writeHead(404).end("not found")
  res.writeHead(200, { "Content-Type": file.endsWith(".html") ? "text/html" : "application/octet-stream" })
  fs.createReadStream(file).pipe(res)
})
await new Promise((resolve) => server.listen(0, resolve))
const browser = await chromium.launch()
const page = await browser.newPage()
page.on("console", (message) => console.log(`browser:${message.type()}: ${message.text()}`))
page.on("pageerror", (error) => console.error(`browser:pageerror: ${error.message}`))
await page.goto(`http://localhost:${server.address().port}/`, { waitUntil: "networkidle" })

const raw = page.locator('pluto-output[data-mime="text/html"] > button').first()
const computed = await raw.evaluate((el) => {
  const s = getComputedStyle(el)
  return { display: s.display, background: s.backgroundColor, color: s.color, border: s.borderTopWidth, padding: s.paddingInlineStart, cursor: s.cursor }
})
if (computed.display === "inline" || computed.background === "rgba(0, 0, 0, 0)" || computed.color === "rgba(0, 0, 0, 0)" || computed.border === "0px" || computed.padding === "0px" || computed.cursor !== "pointer") {
  throw new Error(`raw button has no affordance: ${JSON.stringify(computed)}`)
}
const picker = page.locator(".snap-theme-picker select")
await picker.selectOption("fun-dark")
await page.waitForFunction(() => document.documentElement.dataset.theme === "fun-dark")
const darkBackground = await raw.evaluate((el) => getComputedStyle(el).backgroundColor)
if (darkBackground === computed.background) throw new Error("raw button did not follow the theme token change")
await picker.selectOption("cupcake")
await page.waitForFunction(() => document.documentElement.dataset.theme === "cupcake")
const stockTheme = await raw.evaluate((el) => { const s = getComputedStyle(el); return { background: s.backgroundColor, color: s.color, border: s.borderTopWidth } })
if (stockTheme.background === "rgba(0, 0, 0, 0)" || stockTheme.color === "rgba(0, 0, 0, 0)" || stockTheme.border === "0px" || stockTheme.background === darkBackground) {
  throw new Error(`raw button did not resolve a stock DaisyUI theme: ${JSON.stringify(stockTheme)}`)
}
for (const selector of ['input[type="text"]', "select", "textarea"]) {
  const control = page.locator(`pluto-output[data-mime="text/html"] > ${selector}`).first()
  const style = await control.evaluate((el) => { const s = getComputedStyle(el); return { border: s.borderTopWidth, padding: s.paddingInlineStart } })
  if (style.border === "0px" || style.padding === "0px") throw new Error(`raw ${selector} was not themed: ${JSON.stringify(style)}`)
}
for (const selector of ['input[type="checkbox"]', 'input[type="radio"]']) {
  const accent = await page.locator(`pluto-output[data-mime="text/html"] > ${selector}`).evaluate((el) => getComputedStyle(el).accentColor)
  if (!accent || accent === "auto") throw new Error(`raw ${selector} did not inherit the theme accent: ${accent}`)
}
const disabled = page.locator('pluto-output[data-mime="text/html"] > button:disabled')
if (Number(await disabled.evaluate((el) => getComputedStyle(el).opacity)) >= 1) throw new Error("disabled raw button lacks disabled affordance")
await raw.focus()
const focus = await raw.evaluate((el) => { const s = getComputedStyle(el); return { width: s.outlineWidth, style: s.outlineStyle } })
if (focus.width === "0px" || focus.style === "none") throw new Error(`raw button lacks a visible keyboard focus outline: ${JSON.stringify(focus)}`)
const selectors = [".custom-button", ".custom-widget button", "button[style]", "button[data-snapshot-unstyled]"]
for (const selector of selectors) {
  const padding = await page.locator(selector).evaluate((el) => getComputedStyle(el).paddingInlineStart)
  if (padding === computed.padding) throw new Error(`scoped fallback leaked into ${selector}`)
}
await page.waitForFunction(() => document.querySelectorAll("code.pl-jl span").length > 0)
const htmlCode = page.locator("code.pl-jl").nth(1)
const expectedSource = `Base.HTML("""\n<button>Click me!</button>\n<button disabled>Disabled</button>\n<input type="text" value="Raw text input">`
if (!(await htmlCode.textContent()).startsWith(expectedSource)) throw new Error("mixed highlighting changed the Julia source text")
const nestedConst = htmlCode.locator("span", { hasText: "const" }).first()
if ((await nestedConst.getAttribute("class")) !== "tok-keyword") {
  console.error(await page.locator("code.pl-jl").first().innerHTML())
  throw new Error(`nested JavaScript keyword was not highlighted: ${await nestedConst.getAttribute("class")}`)
}
const interpolation = htmlCode.locator("span", { hasText: "interpolation_value" }).first()
if ((await interpolation.getAttribute("class"))?.includes("tok-string")) throw new Error("Julia interpolation was swallowed by the HTML overlay")
if ((await page.evaluate(() => window.__rawOutputRuns)) !== 1) throw new Error("source highlighting executed the embedded script a second time")
const plainCode = page.locator("code.pl-jl").nth(2)
const plainConstClass = await plainCode.locator("span", { hasText: "const plainJuliaString" }).getAttribute("class")
if (!plainConstClass?.includes("tok-string")) {
  throw new Error(`plain Julia triple string was incorrectly treated as HTML/JS: ${plainConstClass}`)
}
await browser.close()
server.close()
console.log("✅ raw controls are themed safely; Base.HTML source receives nested HTML/JS highlighting")
