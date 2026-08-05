import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import {
  MIN_FRAMES,
  MAX_FRAMES,
  MAX_GIF_MIB,
  countExpectedSlides,
  countRenderedSlides,
  validateFrameCount,
  validateGifHeader,
  validateGifSizeMiB,
  validateRenderedSlideCount,
} from "./make-showcase-gif.mjs";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

test("slides-showcase.md declares at least one src import", () => {
  const md = readFileSync(join(repoRoot, "slides-showcase.md"), "utf8");
  assert.ok(countExpectedSlides(md) >= 1);
});

test("validateFrameCount enforces 8–60 bounds", () => {
  assert.doesNotThrow(() => validateFrameCount(MIN_FRAMES));
  assert.doesNotThrow(() => validateFrameCount(MAX_FRAMES));
  assert.throws(() => validateFrameCount(MIN_FRAMES - 1), /frame count/i);
  assert.throws(() => validateFrameCount(MAX_FRAMES + 1), /frame count/i);
});

test("validateGifHeader accepts GIF87a and GIF89a only", () => {
  assert.doesNotThrow(() => validateGifHeader("GIF89a"));
  assert.doesNotThrow(() => validateGifHeader("GIF87a"));
  assert.throws(() => validateGifHeader("PNG\r\n"), /not a GIF/i);
});

test("validateGifSizeMiB rejects outputs over 15 MiB", () => {
  assert.doesNotThrow(() => validateGifSizeMiB(MAX_GIF_MIB));
  assert.doesNotThrow(() => validateGifSizeMiB(1));
  assert.throws(() => validateGifSizeMiB(MAX_GIF_MIB + 0.01), /exceeds 15 MiB/i);
});

test("countRenderedSlides deduplicates slide indices across click frames", () => {
  const frames = ["001-0.png", "001-1.png", "002-0.png", "003-0.png", "003-1.png"];
  assert.equal(countRenderedSlides(frames), 3);
});

test("validateRenderedSlideCount requires renderedSlides === expectedSlides", () => {
  assert.doesNotThrow(() => validateRenderedSlideCount(6, 6));
  assert.throws(
    () => validateRenderedSlideCount(5, 6),
    /Rendered 5 slide\(s\) but slides-showcase.md declares 6 imports/,
  );
  assert.throws(
    () => validateRenderedSlideCount(7, 6),
    /a showcase page range no longer resolves/,
  );
});

test("slides-showcase.md src count matches a realistic frame export", () => {
  const md = readFileSync(join(repoRoot, "slides-showcase.md"), "utf8");
  const expected = countExpectedSlides(md);
  // Six showcase imports → six distinct slide indices in a healthy export.
  const frames = [];
  for (let slide = 1; slide <= expected; slide += 1) {
    const prefix = String(slide).padStart(3, "0");
    frames.push(`${prefix}-0.png`, `${prefix}-1.png`);
  }
  assert.doesNotThrow(() => validateRenderedSlideCount(countRenderedSlides(frames), expected));
  frames.pop(); // drop one click frame from the last slide — still six slides
  assert.doesNotThrow(() => validateRenderedSlideCount(countRenderedSlides(frames), expected));
  frames.splice(frames.findIndex((f) => f.startsWith("003-")), 2); // lose slide 3 entirely
  assert.throws(
    () => validateRenderedSlideCount(countRenderedSlides(frames), expected),
    /Rendered 5 slide\(s\) but slides-showcase.md declares 6 imports/,
  );
});
