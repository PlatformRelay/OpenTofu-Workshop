<script setup lang="ts">
/**
 * Static SVG icon loader for the deck.
 *
 * Two modes, both export-safe (<img> from public/, no build plugin — ADR 0001):
 *
 *   Brand / tool logo:  <IacIcon name="opentofu-icon-color" />
 *   HCL block glyph:    <IacIcon kind="resource" />
 *                       <IacIcon kind="module" variant="unlabeled" />
 *
 * HCL-block glyphs are a small custom set (hexagon/badge motif) vendored under
 * public/icons/blocks/{labeled,unlabeled}/, one SVG per HCL construct. `labeled`
 * carries the block keyword under the badge; `unlabeled` is the bare badge for
 * use inline in cards and diagrams. See public/icons/README.md for attribution.
 */

/** HCL / OpenTofu / Terramate construct slugs vendored under public/icons/blocks/. */
export type IacKind =
  // core HCL blocks
  | 'resource' | 'variable' | 'output' | 'module' | 'provider' | 'data' | 'locals'
  // state & backend
  | 'backend' | 'state' | 'encryption'
  // testing & policy
  | 'test' | 'mock' | 'check' | 'validation'
  // lifecycle / refactoring
  | 'import' | 'moved' | 'removed'
  // terramate
  | 'stack' | 'generate' | 'globals'

const props = withDefaults(
  defineProps<{
    /** Brand / tool logo file under public/icons/, without extension. Ignored when `kind` is set. */
    name?:
      | 'opentofu-icon-white'
      | 'opentofu-icon-color'
      | 'opentofu-horizontal-white-text'
      | 'terraform-icon-color'
      | 'terramate-icon-color'
      | 'localstack-icon-color'
    /** HCL block glyph. Takes precedence over `name`. */
    kind?: IacKind
    /** Block glyph style: with keyword-label text or bare badge. */
    variant?: 'labeled' | 'unlabeled'
    /** CSS height, e.g. "2rem". */
    size?: string
    /** Accessible label; falls back to the kind slug. */
    alt?: string
  }>(),
  { name: 'opentofu-icon-white', variant: 'labeled', size: '2rem' },
)

const base = import.meta.env.BASE_URL

const src = props.kind
  ? `${base}icons/blocks/${props.variant}/${props.kind}.svg`
  : `${base}icons/${props.name}.svg`
</script>

<template>
  <img
    :src="src"
    :style="{ height: props.size }"
    :alt="props.alt ?? props.kind ?? ''"
    class="kw-icon"
  />
</template>

<style scoped>
.kw-icon {
  display: inline-block;
  vertical-align: middle;
}
</style>
