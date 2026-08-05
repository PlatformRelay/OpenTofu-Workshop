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
  validateFrameCount,
  validateGifHeader,
  validateGifSizeMiB,
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
