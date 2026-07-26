<script setup lang="ts">
import { computed } from 'vue'

/**
 * MockProviderFlow — click-stepped diagram of converting an apply-shaped test
 * into a mocked plan contract (S17):
 *
 *   apply run  →  mock_provider  →  plan run  →  mock_resource  →  override_resource
 *
 * Bind `step` to `$clicks` on a slide to reveal stages one click at a time:
 *
 *   <MockProviderFlow :step="$clicks" />
 *
 * step 0 → nothing lit · step 1 → apply appetite · step 2 → +mock_provider ·
 * step 3 → +plan-only · step 4 → +mock_resource defaults · step 5 → +run-level
 * override (all lit). Out-of-range values clamp into [0, 5] — negative or
 * overshoot never throws and never blanks the slide.
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
  tone: 'apply' | 'mock' | 'plan' | 'defaults' | 'override'
}

const stages: Stage[] = [
  { key: 'apply', label: 'apply run', sub: 'real provider', tone: 'apply' },
  { key: 'mock', label: 'mock_provider', sub: 'swap', tone: 'mock' },
  { key: 'plan', label: 'plan run', sub: 'command = plan', tone: 'plan' },
  { key: 'defaults', label: 'mock_resource', sub: 'defaults', tone: 'defaults' },
  { key: 'override', label: 'override_resource', sub: 'run-level', tone: 'override' },
]

/** Clamp any incoming step (NaN, negative, overshoot) into [0, stages.length]. */
const activeCount = computed(() => {
  const raw = Number(props.step)
  if (!Number.isFinite(raw)) return stages.length
  return Math.max(0, Math.min(stages.length, Math.trunc(raw)))
})

const isLit = (index: number) => index < activeCount.value
</script>

<!-- apply → mock_provider → plan → defaults → override, revealed stage-by-stage as `step` grows. -->
<template>
  <div class="mpf">
    <template v-for="(stage, i) in stages" :key="stage.key">
      <span
        v-if="i > 0"
        class="mpf-arrow"
        :class="{ 'mpf-arrow--lit': isLit(i) }"
        aria-hidden="true"
      >→</span>
      <div
        class="mpf-stage"
        :class="[`mpf-stage--${stage.tone}`, { 'mpf-stage--lit': isLit(i) }]"
      >
        <span class="mpf-stage-label">{{ stage.label }}</span>
        <span class="mpf-stage-sub">{{ stage.sub }}</span>
      </div>
    </template>
  </div>
</template>

<style scoped>
.mpf {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 0;
  min-width: 0;
}

.mpf-stage {
  --mpf-color: var(--kw-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
  min-width: 6.5rem;
  padding: 0.7rem 0.9rem;
  background: var(--kw-panel);
  border: 1px solid var(--kw-border);
  border-bottom: 3px solid var(--mpf-color);
  border-radius: var(--kw-radius-sm);
  opacity: 0.4;
  filter: grayscale(0.6);
  transition: opacity 0.25s ease, filter 0.25s ease, box-shadow 0.25s ease;
}

.mpf-stage--lit {
  opacity: 1;
  filter: none;
  box-shadow: 0 0 0 1px color-mix(in srgb, var(--mpf-color) 40%, transparent);
}

.mpf-stage--apply {
  --mpf-color: var(--kw-danger);
}

.mpf-stage--mock {
  --mpf-color: var(--kw-ok);
}

.mpf-stage--plan {
  --mpf-color: var(--kw-warn);
}

.mpf-stage--defaults {
  --mpf-color: var(--kw-accent);
}

.mpf-stage--override {
  --mpf-color: var(--kw-tofu-yellow);
}

.mpf-stage-label {
  font-weight: 650;
  font-size: 0.9rem;
  color: var(--kw-text);
}

.mpf-stage-sub {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.62rem;
  letter-spacing: 0.06em;
  color: var(--kw-text-faint);
}

.mpf-arrow {
  font-size: 1.1rem;
  color: var(--kw-text-faint);
  opacity: 0.35;
  transition: opacity 0.25s ease, color 0.25s ease;
}

.mpf-arrow--lit {
  opacity: 1;
  color: var(--kw-accent-bright);
}
</style>
