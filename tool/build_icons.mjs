// Renders the app mark into every launcher-icon and splash asset Android and
// iOS ask for.
//
// The mark itself is not ours: `../ghost-key/public/icon.svg` is the one place
// it is drawn for the whole suite, so this reads it from there rather than
// keeping a second copy that can drift. Everything below is derived from that
// file — the badge, the badge squared off for iOS, and the key lifted out of
// it — which is why the geometry appears here only as the box it sits in.
//
// Run it by hand after the mark changes: `node tool/build_icons.mjs`, then look
// at the PNGs. It borrows Playwright from the sibling repo, which has it for
// the same job (`ghost-key/scripts/build-icons.mjs`) — a browser is the only
// SVG renderer we can count on being installed, and this repo has no node
// dependencies of its own to hang one on.

import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const desk = path.join(root, "..", "ghost-key");
const require = createRequire(path.join(desk, "package.json"));
const { chromium } = require("@playwright/test");

const svg = await readFile(path.join(desk, "public", "icon.svg"), "utf8");

/** The badge whole, rounded corners and all, transparent outside them. */
const BADGE = svg;

/** The same badge squared off — iOS rounds and masks app icons itself. */
const BADGE_SQUARE = svg.replace(/(<rect width="96" height="96")\s+rx="26"/, "$1");

/** The key alone, taken out of the badge so its shape keeps one home. */
const group = svg.match(/<g\s([^>]*)>([\s\S]*?)<\/g>/);
const KEY_ATTRS = group[1].replace(/\s*transform="[^"]*"/, "");
const KEY_BODY = group[2];

/** Where the key's ink actually falls in its own 24-unit box, strokes included. */
const KEY = { cx: 11.75, cy: 11.9, height: 20.4 };

/** The key on transparent, `height` tall, centred in a square `canvas`. */
function keyOn(canvas, height) {
  const scale = height / KEY.height;
  const x = canvas / 2 - KEY.cx * scale;
  const y = canvas / 2 - KEY.cy * scale;
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${canvas} ${canvas}">` +
    `<g ${KEY_ATTRS} transform="translate(${x} ${y}) scale(${scale})">${KEY_BODY}</g></svg>`
  );
}

const DENSITY = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
const res = path.join(root, "android", "app", "src", "main", "res");
const xcassets = path.join(root, "ios", "Runner", "Assets.xcassets");

const targets = [];
const perDensity = (svg, dp, dir, name) => {
  for (const [bucket, scale] of Object.entries(DENSITY)) {
    targets.push({ svg, px: Math.round(dp * scale), out: path.join(res, `${dir}-${bucket}`, name) });
  }
};

// The launcher icon anywhere the badge is drawn whole — pre-Oreo, and every
// launcher that still asks for the legacy bitmap.
perDensity(BADGE, 48, "mipmap", "ic_launcher.png");

// The adaptive foreground: a 108dp canvas the mask crops to 72dp, so the key
// runs a little larger here than it does inside the badge.
perDensity(keyOn(108, 41), 108, "mipmap", "ic_launcher_foreground.png");

// The splash mark. Android 12 draws it on a 288dp canvas and guarantees only
// the middle 192dp; pre-12 uses the same bitmap centred on the void.
perDensity(keyOn(288, 150), 288, "drawable", "splash_logo.png");

// iOS wants every slot in AppIcon.appiconset filled, and opaque.
const SLOTS = {
  "20x20@1x": 20, "20x20@2x": 40, "20x20@3x": 60,
  "29x29@1x": 29, "29x29@2x": 58, "29x29@3x": 87,
  "40x40@1x": 40, "40x40@2x": 80, "40x40@3x": 120,
  "60x60@2x": 120, "60x60@3x": 180,
  "76x76@1x": 76, "76x76@2x": 152, "83.5x83.5@2x": 167,
  "1024x1024@1x": 1024,
};
for (const [slot, px] of Object.entries(SLOTS)) {
  targets.push({
    svg: BADGE_SQUARE,
    px,
    opaque: true,
    out: path.join(xcassets, "AppIcon.appiconset", `Icon-App-${slot}.png`),
  });
}

// The iOS launch image, which LaunchScreen.storyboard centres on the void.
for (const [suffix, scale] of [["", 1], ["@2x", 2], ["@3x", 3]]) {
  targets.push({
    svg: keyOn(96, 56),
    px: 96 * scale,
    out: path.join(xcassets, "LaunchImage.imageset", `LaunchImage${suffix}.png`),
  });
}

const browser = await chromium.launch();
const page = await browser.newPage();
try {
  for (const target of targets) {
    await page.setViewportSize({ width: target.px, height: target.px });
    await page.setContent(
      `<style>html,body{margin:0;background:transparent}svg{display:block;width:${target.px}px;height:${target.px}px}</style>${target.svg}`,
    );
    await mkdir(path.dirname(target.out), { recursive: true });
    await writeFile(target.out, await page.screenshot({ omitBackground: !target.opaque }));
  }
} finally {
  await browser.close();
}

console.log(`${targets.length} icon and splash assets written from ${path.relative(root, path.join(desk, "public", "icon.svg"))}`);
