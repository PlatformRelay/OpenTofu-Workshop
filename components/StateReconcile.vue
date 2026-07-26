<script setup lang="ts">
import { computed } from 'vue'

/**
 * StateReconcile — click-stepped diagram of the desired / state / actual
 * reconciliation model (S04) reused when reading a plan diff (S09):
 *
 *   desired  →  state  →  actual  →  refresh  →  reconcile
 *
 * Bind `step` to `$clicks` on a slide to reveal stages one click at a time:
 *
 *   <StateReconcile :step="$clicks" />
 *
 * step 0 → nothing lit · step 1 → desired · step 2 → +state · step 3 → +actual ·
 * step 4 → +refresh · step 5 → +reconcile (all lit). Out-of-range values clamp
 * into [0, 5] — negative or overshoot never throws and never blanks the slide.
 */
const props = withDefaults(
  defineProps<{
    /** Active stage count (0–5). Bind to `$clicks`. Clamped into range. */
    step?: number
  }>(),
  { step: 5 },
)

interface Stage {
  key: string
  label: string
  sub: string
  tone: 'desired' | 'state' | 'actual' | 'refresh' | 'reconcile'
}

const stages: Stage[] = [
  { key: 'desired', label: 'desired', sub: 'config', tone: 'desired' },
  { key: 'state', label: 'state', sub: 'record', tone: 'state' },
  { key: 'actual', label: 'actual', sub: 'real world', tone: 'actual' },
  { key: 'refresh', label: 'refresh', sub: 'detect drift', tone: 'refresh' },
  { key: 'reconcile', label: 'reconcile', sub: 'plan', tone: 'reconcile' },
]

/** Clamp any incoming step (NaN, negative, overshoot) into [0, stages.length]. */
const activeCount = computed(() => {
  const raw = Number(props.step)
  if (!Number.isFinite(raw)) return stages.length
  return Math.max(0, Math.min(stages.length, Math.trunc(raw)))
})

const isLit = (index: number) => index < activeCount.value
</script>

<!-- desired → state → actual → refresh → reconcile, revealed stage-by-stage as `step` grows. -->
<template>
  <div class="sr">
    <template v-for="(stage, i) in stages" :key="stage.key">
      <span
        v-if="i > 0"
        class="sr-arrow"
        :class="{ 'sr-arrow--lit': isLit(i) }"
        aria-hidden="true"
      >→</span>
      <div
        class="sr-stage"
        :class="[`sr-stage--${stage.tone}`, { 'sr-stage--lit': isLit(i) }]"
      >
        <span class="sr-stage-label">{{ stage.label }}</span>
        <span class="sr-stage-sub">{{ stage.sub }}</span>
      </div>
    </template>
  </div>
</template>

<style scoped>
.sr {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 0;
  min-width: 0;
}

.sr-stage {
  --sr-color: var(--kw-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
  min-width: 6.5rem;
  padding: 0.7rem 0.9rem;
  background: var(--kw-panel);
  border: 1px solid var(--kw-border);
  border-bottom: 3px solid var(--sr-color);
  border-radius: var(--kw-radius-sm);
  opacity: 0.4;
  filter: grayscale(0.6);
  transition: opacity 0.25s ease, filter 0.25s ease, box-shadow 0.25s ease;
}

.sr-stage--lit {
  opacity: 1;
  filter: none;
  box-shadow: 0 0 0 1px color-mix(in srgb, var(--sr-color) 40%, transparent);
}

.sr-stage--desired {
  --sr-color: var(--kw-accent);
}

.sr-stage--state {
  --sr-color: var(--kw-tofu-yellow);
}

.sr-stage--actual {
  --sr-color: var(--kw-warn);
}

.sr-stage--refresh {
  --sr-color: var(--kw-accent-bright);
}

.sr-stage--reconcile {
  --sr-color: var(--kw-ok);
}

.sr-stage-label {
  font-weight: 650;
  font-size: 0.9rem;
  color: var(--kw-text);
}

.sr-stage-sub {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.62rem;
  letter-spacing: 0.06em;
  color: var(--kw-text-faint);
}

.sr-arrow {
  font-size: 1.1rem;
  color: var(--kw-text-faint);
  opacity: 0.35;
  transition: opacity 0.25s ease, color 0.25s ease;
}

.sr-arrow--lit {
  opacity: 1;
  color: var(--kw-accent-bright);
}
</style>
