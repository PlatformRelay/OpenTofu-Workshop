import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import test from 'node:test'

const root = path.resolve(import.meta.dirname, '..')

async function workspaceYaml() {
  return readFile(path.join(root, 'pnpm-workspace.yaml'), 'utf8')
}

test('js-yaml override is bounded to the intended 5.x major', async () => {
  const workspace = await workspaceYaml()

  assert.match(workspace, /"js-yaml@>=5\.0\.0 <6\.0\.0": 5\.2\.3/)
  assert.doesNotMatch(workspace, /"js-yaml@>=5\.0\.0":/)
})

test('js-yaml 3.x and 4.x overrides are bounded to their own patched floors', async () => {
  const workspace = await workspaceYaml()

  assert.match(workspace, /"js-yaml@>=3\.0\.0 <4\.0\.0": 3\.15\.1/)
  assert.match(workspace, /"js-yaml@>=4\.0\.0 <5\.0\.0": 4\.3\.1/)
  assert.doesNotMatch(workspace, /"js-yaml@>=3\.0\.0":/)
  assert.doesNotMatch(workspace, /"js-yaml@>=4\.0\.0":/)
  assert.doesNotMatch(workspace, /(^|\s)js-yaml:/m)
})

test('nanoid override is bounded to the intended 3.x major at its patched floor', async () => {
  const workspace = await workspaceYaml()

  // GHSA-2v37-7h3g-55p8 moved the 3.x floor to 3.3.18; the audit gate blocks on
  // the high advisory, so the pin and its release-age exclusion must agree.
  assert.match(workspace, /"nanoid@>=3\.0\.0 <4\.0\.0": 3\.3\.18/)
  assert.doesNotMatch(workspace, /"nanoid@>=3\.0\.0":/)
  assert.doesNotMatch(workspace, /(^|\s)nanoid:/m)
})

test('the minimumReleaseAge exclusion tracks the pinned nanoid version', async () => {
  const workspace = await workspaceYaml()

  assert.match(workspace, /^ {2}- 'nanoid@3\.3\.18'$/m)
  assert.doesNotMatch(workspace, /nanoid@3\.3\.17/)
})

test('postcss, mermaid, and DOMPurify pin the patched lines', async () => {
  const workspace = await workspaceYaml()

  assert.match(workspace, /^ {2}postcss: 8\.5\.25$/m)
  assert.match(workspace, /^ {2}mermaid: 11\.16\.1$/m)
  assert.match(workspace, /^ {2}dompurify: 3\.4\.13$/m)
})

test('brace-expansion, fast-uri, and ip-address pin patched floors without unbounded majors', async () => {
  const workspace = await workspaceYaml()

  assert.match(workspace, /"brace-expansion@>=2\.0\.0 <3\.0\.0": 2\.1\.4/)
  assert.match(workspace, /"brace-expansion@>=5\.0\.0 <6\.0\.0": 5\.0\.9/)
  assert.match(workspace, /"fast-uri@>=3\.0\.0 <4\.0\.0": 3\.1\.5/)
  assert.match(workspace, /^ {2}ip-address: 10\.3\.1$/m)
  assert.doesNotMatch(workspace, /(^|\s)brace-expansion:/m)
  assert.doesNotMatch(workspace, /(^|\s)fast-uri:/m)
})
