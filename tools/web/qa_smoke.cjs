// QA smoke test of the web build (docs/qa_2026_11_08_ui.md): serve build/web, open it in headless Chromium (software
// WebGL), click through the first-run device page and the main menu, start a skirmish, play a little, and keep every
// console line, page error and failed request; screenshots go to OUT.
//   python3 -m http.server 8765 -d build/web &   (or any static server)
//   node tools/web/qa_smoke.cjs [url] [outdir] [phone]
// The coordinates are those of a 1280x720 view (the game's base size), or 915x412 with "phone" (scaled by the game).
// Prints "WEB-QA ..." lines; exit code 1 when the page crashed, an error was logged or the match did not start.
const { chromium } = require('playwright');
const fs = require('fs');

(async () => {

const url = process.argv[2] || 'http://127.0.0.1:8765/index.html';
const out = process.argv[3] || '/tmp/web_qa';
const phone = process.argv[4] === 'phone';
fs.mkdirSync(out, { recursive: true });
const W = phone ? 915 : 1280, H = phone ? 412 : 720;
const log = [];
let errors = 0;
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const ctx = await browser.newContext({ viewport: { width: W, height: H }, hasTouch: phone, isMobile: phone, deviceScaleFactor: 1 });
const page = await ctx.newPage();
page.on('console', (m) => {
	const t = m.text();
	log.push(`[${m.type()}] ${t}`);
	if (/SCRIPT ERROR|USER SCRIPT ERROR|Parse Error|^ERROR:/.test(t) && !/ReadPixels|GPU stall/.test(t)) errors++;
});
page.on('pageerror', (e) => { log.push(`[pageerror] ${e.message}`); errors++; });
const reqs = { music: 0, failed: 0 };
page.on('requestfinished', (r) => { if (r.url().includes('/music/')) reqs.music++; });
page.on('requestfailed', (r) => { reqs.failed++; log.push(`[failed] ${r.url()} ${r.failure()?.errorText}`); });
const shot = async (name) => { await page.screenshot({ path: `${out}/${phone ? 'phone' : 'pc'}_${name}.png` }); };
// a tap at the game's own coordinates (1280x720 base, stretched to the view keeping the height)
const k = H / 720;
const ox = (W - 1280 * k) / 2 > 0 ? 0 : 0;
const tap = async (x, y) => {
	if (phone) await page.touchscreen.tap(x * k + ox, y * k);
	else await page.mouse.click(x * k + ox, y * k);
};
const t0 = Date.now();
await page.goto(url, { waitUntil: 'load' });
// wait for the engine to draw the first page
let started = false;
for (let i = 0; i < 120; i++) {
	await page.waitForTimeout(1000);
	if (log.some((l) => l.includes('Godot Engine'))) { started = true; break; }
}
await page.waitForTimeout(6000);
console.log(`WEB-QA engine up: ${started} after ${((Date.now() - t0) / 1000).toFixed(1)} s`);
await shot('1_first_page');
let body = await page.evaluate(() => document.body.innerText || '');
console.log(`WEB-QA crash page shown: ${/CLOSED UNEXPECTEDLY/i.test(body)}`);
// the game's own coordinates (logical 1280x720 on a computer, 1600x720 on the phone: tools/qa_ui_audit.gd pictures)
const P = phone ? { device: [970, 362], skirmish: [370, 110], start: [905, 670], menu: [1560, 22] }
	: { device: [505, 362], skirmish: [286, 110], start: [746, 672], menu: [1240, 25] };
await tap(...P.device);
await page.waitForTimeout(3000);
await shot('2_menu');
await tap(...P.skirmish);
await page.waitForTimeout(2500);
await shot('3_lobby');
const t1 = Date.now();
await tap(...P.start);
let inMatch = false;
for (let i = 0; i < 90; i++) {
	await page.waitForTimeout(1000);
	if (log.some((l) => l.includes('[session]'))) { inMatch = true; break; }
}
console.log(`WEB-QA match started: ${inMatch} after ${((Date.now() - t1) / 1000).toFixed(1)} s`);
await page.waitForTimeout(20000);
await shot('4_match');
await tap(...P.menu);
await page.waitForTimeout(4000);
await shot('5_match_menu');
await tap(...P.menu);
await page.waitForTimeout(30000);
await shot('6_match_later');
// leave the tab the way a player does (a reload): no crash page, CONTINUE offered
await page.reload({ waitUntil: 'load' });
await page.waitForTimeout(15000);
body = await page.evaluate(() => document.body.innerText || '');
console.log(`WEB-QA after a reload, crash page shown: ${/CLOSED UNEXPECTEDLY/i.test(body)}`);
await shot('7_after_reload');
if (!inMatch) errors++;
fs.writeFileSync(`${out}/${phone ? 'phone' : 'pc'}_console.txt`, log.join('\n'));
await browser.close();
console.log(`WEB-QA errors: ${errors}, music downloads: ${reqs.music}, failed requests: ${reqs.failed}`);
process.exit(errors ? 1 : 0);
})();
