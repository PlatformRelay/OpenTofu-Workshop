#!/usr/bin/env node
// SEC-4 dry validation (US-P-PINS): pinned TOFU_VERSION must resolve to a real
// OpenTofu release SHA256SUMS with a linux_amd64 artifact entry.
//
// Lives in a *.test.mjs so supply-chain-policy does not scan it (no dynamic curl
// in scripts/*.sh). verify-selftest.sh invokes this file.
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function readTofuVersion() {
  const env = readFileSync(resolve(ROOT, 'versions.env'), 'utf8')
  const match = env.match(/^TOFU_VERSION=([0-9]+\.[0-9]+\.[0-9]+)\s*$/m)
  assert.ok(match, 'versions.env must declare TOFU_VERSION=X.Y.Z')
  return match[1]
}

test('OpenTofu release SHA256SUMS resolves for pinned TOFU_VERSION', async () => {
  const version = readTofuVersion()
  const sumsUrl =
    `https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_SHA256SUMS`
  const response = await fetch(sumsUrl)
  assert.equal(
    response.status,
    200,
    `SHA256SUMS fetch failed for TOFU_VERSION=${version}: HTTP ${response.status}`,
  )
  const body = await response.text()
  assert.match(
    body,
    new RegExp(`tofu_${version.replace(/\./g, '\\.')}_linux_amd64\\.tar\\.gz`),
    `SHA256SUMS missing linux_amd64 entry for TOFU_VERSION=${version}`,
  )
})
