<script setup lang="ts">
import { computed } from 'vue'

/**
 * PlanApplyFlow — click-stepped diagram of the OpenTofu core workflow:
 *
 *   config (.tf)  →  plan (diff)  →  apply  →  state
 *
 * Bind `step` to `$clicks` on a slide to reveal stages one click at a time:
 *
 *   <PlanApplyFlow :step="$clicks" />
 *
 * step 0 → nothing lit · step 1 → config · step 2 → +plan · step 3 → +apply ·
 * step 4 → +state (all lit). Out-of-range values clamp into [0, 4] — negative
 * or overshoot never throws and never blanks the slide.
 */
const props = withDefaults(
  defineProps<{
    /** Active stage count (0–4). Bind to `$clicks`. Clamped into range. */
    step?: number
  }>(),
  { step: 4 },
)

interface Stage {
  key: string
  label: string
  sub: string
  tone: 'config' | 'plan' | 'apply' | 'state'
}

const stages: Stage[] = [
  { key: 'config', label: 'config', sub: '.tf', tone: 'config' },
  { key: 'plan', label: 'plan', sub: 'diff', tone: 'plan' },
  { key: 'apply', label: 'apply', sub: 'converge', tone: 'apply' },
  { key: 'state', label: 'state', sub: 'record', tone: 'state' },
]

/** Clamp any incoming step (NaN, negative, overshoot) into [0, stages.length]. */
const activeCount = computed(() => {
  const raw = Number(props.step)
  if (!Number.isFinite(raw)) return stages.length
  return Math.max(0, Math.min(stages.length, Math.trunc(raw)))
})

const isLit = (index: number) => index < activeCount.value
</script>

<!-- Config → plan → apply → state, revealed stage-by-stage as `step` grows. -->
<template>
  <div class="paf">
    <template v-for="(stage, i) in stages" :key="stage.key">
      <span
        v-if="i > 0"
        class="paf-arrow"
        :class="{ 'paf-arrow--lit': isLit(i) }"
        aria-hidden="true"
      >→</span>
      <div
        class="paf-stage"
        :class="[`paf-stage--${stage.tone}`, { 'paf-stage--lit': isLit(i) }]"
      >
        <span class="paf-stage-label">{{ stage.label }}</span>
        <span class="paf-stage-sub">{{ stage.sub }}</span>
      </div>
    </template>
  </div>
</template>

<style scoped>
.paf {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 0;
  min-width: 0;
}

.paf-stage {
  --paf-color: var(--kw-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
  min-width: 6.5rem;
  padding: 0.7rem 0.9rem;
  background: var(--kw-panel);
  border: 1px solid var(--kw-border);
  border-bottom: 3px solid var(--paf-color);
  border-radius: var(--kw-radius-sm);
  opacity: 0.4;
  filter: grayscale(0.6);
  transition: opacity 0.25s ease, filter 0.25s ease, box-shadow 0.25s ease;
}

.paf-stage--lit {
  opacity: 1;
  filter: none;
  box-shadow: 0 0 0 1px color-mix(in srgb, var(--paf-color) 40%, transparent);
}

.paf-stage--config {
  --paf-color: var(--kw-accent);
}

.paf-stage--plan {
  --paf-color: var(--kw-warn);
}

.paf-stage--apply {
  --paf-color: var(--kw-ok);
}

.paf-stage--state {
  --paf-color: var(--kw-tofu-yellow);
}

.paf-stage-label {
  font-weight: 650;
  font-size: 0.9rem;
  color: var(--kw-text);
}

.paf-stage-sub {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.62rem;
  letter-spacing: 0.06em;
  color: var(--kw-text-faint);
}

.paf-arrow {
  font-size: 1.1rem;
  color: var(--kw-text-faint);
  opacity: 0.35;
  transition: opacity 0.25s ease, color 0.25s ease;
}

.paf-arrow--lit {
  opacity: 1;
  color: var(--kw-accent-bright);
}
</style>
