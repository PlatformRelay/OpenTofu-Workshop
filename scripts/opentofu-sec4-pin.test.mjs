#!/usr/bin/env node
// SEC-4 offline pin (US-P-PINS): versions.env TOFU_VERSION must match the
// committed expected artifact / SUMS basenames, and the Dockerfile must still
// carry the live SHA256SUMS verify path (story AC). No network I/O here.
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'
import test from 'node:test'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const FIXTURE = resolve(ROOT, 'scripts/fixtures/opentofu-sec4-expected.env')
const DOCKERFILE = resolve(ROOT, 'setup/terratest/Dockerfile')

function readTofuVersion() {
  const env = readFileSync(resolve(ROOT, 'versions.env'), 'utf8')
  const match = env.match(/^TOFU_VERSION=([0-9]+\.[0-9]+\.[0-9]+)\s*$/m)
  assert.ok(match, 'versions.env must declare TOFU_VERSION=X.Y.Z')
  return match[1]
}

function readFixture() {
  const text = readFileSync(FIXTURE, 'utf8')
  const artifact = text.match(/^ARTIFACT=(\S+)\s*$/m)?.[1]
  const sums = text.match(/^SUMS=(\S+)\s*$/m)?.[1]
  assert.ok(artifact, `${FIXTURE} must declare ARTIFACT=…`)
  assert.ok(sums, `${FIXTURE} must declare SUMS=…`)
  return { artifact, sums }
}

test('versions.env TOFU_VERSION matches committed SEC-4 artifact / SUMS names', () => {
  const version = readTofuVersion()
  const { artifact, sums } = readFixture()

  assert.equal(
    artifact,
    `tofu_${version}_linux_amd64.tar.gz`,
    'bump scripts/fixtures/opentofu-sec4-expected.env when changing TOFU_VERSION',
  )
  assert.equal(
    sums,
    `tofu_${version}_SHA256SUMS`,
    'bump scripts/fixtures/opentofu-sec4-expected.env when changing TOFU_VERSION',
  )
})

test('Dockerfile keeps live SEC-4 SHA256SUMS download and checksum verify', () => {
  const dockerfile = readFileSync(DOCKERFILE, 'utf8')
  assert.match(dockerfile, /tofu_\$\{TOFU_VERSION\}_SHA256SUMS/)
  assert.match(dockerfile, /sha256sum/)
  assert.match(dockerfile, /curl\s+-fsSL/)
})
