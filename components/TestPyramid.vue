<script setup lang="ts">
import { computed } from 'vue'

/**
 * TestPyramid — the testing pyramid for OpenTofu, built bottom-up as `step` grows.
 *
 * Four layers, widest (cheapest) at the base:
 *
 *   e2e            ← narrow tip, slow & few
 *   integration
 *   unit
 *   static         ← wide base, fast & many
 *
 * Bind `step` to `$clicks` to reveal one layer per click, base first:
 *
 *   <TestPyramid :step="$clicks" />
 *
 * Each layer accepts an optional list of tool labels; when a layer's list is
 * empty (the default) the bare band renders with no chips. Reused by S12 and
 * S18, which pass their own tool sets.
 *
 * step 0 → nothing · step 1 → static · step 2 → +unit · step 3 → +integration ·
 * step 4 → +e2e (full pyramid). Out-of-range `step` clamps into [0, 4].
 */
const props = withDefaults(
  defineProps<{
    /** Revealed layer count (0–4, base-first). Bind to `$clicks`. Clamped. */
    step?: number
    /** Tool labels for the static layer (e.g. `tofu fmt`, `tflint`). */
    staticTools?: string[]
    /** Tool labels for the unit layer (e.g. `tofu test` mock). */
    unitTools?: string[]
    /** Tool labels for the integration layer (e.g. LocalStack). */
    integrationTools?: string[]
    /** Tool labels for the end-to-end layer (e.g. real cloud). */
    e2eTools?: string[]
  }>(),
  {
    step: 4,
    staticTools: () => [],
    unitTools: () => [],
    integrationTools: () => [],
    e2eTools: () => [],
  },
)

interface Layer {
  key: string
  label: string
  tone: 'static' | 'unit' | 'integration' | 'e2e'
  width: number
  tools: string[]
}

/** Bottom-up: base is index 0 (widest). Rendered top-down (tip first). */
const layers = computed<Layer[]>(() => [
  { key: 'static', label: 'static', tone: 'static', width: 100, tools: props.staticTools },
  { key: 'unit', label: 'unit', tone: 'unit', width: 78, tools: props.unitTools },
  { key: 'integration', label: 'integration', tone: 'integration', width: 56, tools: props.integrationTools },
  { key: 'e2e', label: 'e2e', tone: 'e2e', width: 34, tools: props.e2eTools },
])

const total = 4

/** Clamp any incoming step (NaN, negative, overshoot) into [0, total]. */
const activeCount = computed(() => {
  const raw = Number(props.step)
  if (!Number.isFinite(raw)) return total
  return Math.max(0, Math.min(total, Math.trunc(raw)))
})

/** Layer at base index `i` is lit once step has reached it. */
const isLit = (baseIndex: number) => baseIndex < activeCount.value

/** Rendered tip-first (e2e at top), so reverse the base-first list. */
const rows = computed(() =>
  layers.value
    .map((layer, baseIndex) => ({ ...layer, baseIndex }))
    .slice()
    .reverse(),
)
</script>

<!-- Testing pyramid: static base → e2e tip, built bottom-up as `step` grows. -->
<template>
  <div class="tp">
    <div
      v-for="row in rows"
      :key="row.key"
      class="tp-row"
      :class="[`tp-row--${row.tone}`, { 'tp-row--lit': isLit(row.baseIndex) }]"
      :style="{ width: `${row.width}%` }"
    >
      <span class="tp-label">{{ row.label }}</span>
      <span v-if="row.tools.length" class="tp-tools">
        <span v-for="tool in row.tools" :key="tool" class="tp-tool">{{ tool }}</span>
      </span>
    </div>
  </div>
</template>

<style scoped>
.tp {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.4rem;
  padding: 0.5rem 0;
  min-width: 0;
}

.tp-row {
  --tp-color: var(--kw-border);
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  min-width: 8rem;
  padding: 0.5rem 0.9rem;
  background: color-mix(in srgb, var(--tp-color) 14%, var(--kw-panel));
  border: 1px solid color-mix(in srgb, var(--tp-color) 40%, var(--kw-border));
  border-radius: var(--kw-radius-sm);
  opacity: 0.35;
  filter: grayscale(0.6);
  transition: opacity 0.25s ease, filter 0.25s ease;
}

.tp-row--lit {
  opacity: 1;
  filter: none;
}

.tp-row--static {
  --tp-color: var(--kw-accent);
}

.tp-row--unit {
  --tp-color: var(--kw-ok);
}

.tp-row--integration {
  --tp-color: var(--kw-warn);
}

.tp-row--e2e {
  --tp-color: var(--kw-danger);
}

.tp-label {
  font-weight: 650;
  font-size: 0.82rem;
  color: var(--kw-text);
}

.tp-tools {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 0.3rem;
}

.tp-tool {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.6rem;
  letter-spacing: 0.04em;
  color: var(--kw-text-dim);
  background: var(--kw-panel);
  border: 1px solid var(--kw-border);
  border-radius: 999px;
  padding: 0.1rem 0.5rem;
  white-space: nowrap;
}
</style>
