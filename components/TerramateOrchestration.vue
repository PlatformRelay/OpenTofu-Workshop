<script setup lang="ts">
import { computed } from 'vue'

/**
 * TerramateOrchestration — click-stepped diagram of the Day-3 Terramate pipeline:
 *
 *   discover  →  generate  →  order  →  filter
 *
 * Bind `step` to `$clicks` to reveal phases one click at a time:
 *
 *   <TerramateOrchestration :step="$clicks" />
 *
 * Emphasise one phase on section slides (S21–S24) while keeping click-step support:
 *
 *   <TerramateOrchestration phase="discover" :step="$clicks" />
 *   <TerramateOrchestration :highlight="2" :step="$clicks" />  // order (0-based)
 *
 * step 0 → nothing lit · step 4 → all lit. Out-of-range values clamp into [0, 4].
 * `phase` / `highlight` add a focus ring on one stage; they do not suppress others.
 */
const props = withDefaults(
  defineProps<{
    /** Active phase count (0–4). Bind to `$clicks`. Clamped into range. */
    step?: number
    /** Named phase to emphasise (discover | generate | order | filter). */
    phase?: 'discover' | 'generate' | 'order' | 'filter'
    /** 0-based index of the emphasised phase (0 = discover … 3 = filter). */
    highlight?: number
  }>(),
  { step: 4 },
)

type Tone = 'discover' | 'generate' | 'order' | 'filter'

interface Stage {
  key: Tone
  label: string
  sub: string
  tone: Tone
}

const stages: Stage[] = [
  { key: 'discover', label: 'discover', sub: 'stack {}', tone: 'discover' },
  { key: 'generate', label: 'generate', sub: 'globals', tone: 'generate' },
  { key: 'order', label: 'order', sub: 'after/before', tone: 'order' },
  { key: 'filter', label: 'filter', sub: '--changed', tone: 'filter' },
]

/** Clamp any incoming step (NaN, negative, overshoot) into [0, stages.length]. */
const activeCount = computed(() => {
  const raw = Number(props.step)
  if (!Number.isFinite(raw)) return stages.length
  return Math.max(0, Math.min(stages.length, Math.trunc(raw)))
})

const focusIndex = computed(() => {
  if (props.phase) {
    const idx = stages.findIndex((s) => s.key === props.phase)
    return idx >= 0 ? idx : -1
  }
  if (props.highlight !== undefined) {
    const raw = Number(props.highlight)
    if (!Number.isFinite(raw)) return -1
    return Math.max(0, Math.min(stages.length - 1, Math.trunc(raw)))
  }
  return -1
})

const isLit = (index: number) => index < activeCount.value
const isFocused = (index: number) => index === focusIndex.value
</script>

<!-- discover → generate → order → filter, revealed stage-by-stage as `step` grows. -->
<template>
  <div class="tmo">
    <template v-for="(stage, i) in stages" :key="stage.key">
      <span
        v-if="i > 0"
        class="tmo-arrow"
        :class="{ 'tmo-arrow--lit': isLit(i) }"
        aria-hidden="true"
      >→</span>
      <div
        class="tmo-stage"
        :class="[
          `tmo-stage--${stage.tone}`,
          {
            'tmo-stage--lit': isLit(i),
            'tmo-stage--focus': isFocused(i),
          },
        ]"
      >
        <span class="tmo-stage-label">{{ stage.label }}</span>
        <span class="tmo-stage-sub">{{ stage.sub }}</span>
      </div>
    </template>
  </div>
</template>

<style scoped>
.tmo {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 0;
  min-width: 0;
}

.tmo-stage {
  --tmo-color: var(--kw-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
  min-width: 6.5rem;
  padding: 0.7rem 0.9rem;
  background: var(--kw-panel);
  border: 1px solid var(--kw-border);
  border-bottom: 3px solid var(--tmo-color);
  border-radius: var(--kw-radius-sm);
  opacity: 0.4;
  filter: grayscale(0.6);
  transition: opacity 0.25s ease, filter 0.25s ease, box-shadow 0.25s ease;
}

.tmo-stage--lit {
  opacity: 1;
  filter: none;
  box-shadow: 0 0 0 1px color-mix(in srgb, var(--tmo-color) 40%, transparent);
}

.tmo-stage--focus {
  --tmo-color: var(--kw-accent);
  opacity: 1;
  filter: none;
  box-shadow: 0 0 0 2px color-mix(in srgb, var(--kw-accent) 55%, transparent);
}

.tmo-stage--focus.tmo-stage--lit {
  box-shadow:
    0 0 0 1px color-mix(in srgb, var(--tmo-color) 40%, transparent),
    0 0 0 2px color-mix(in srgb, var(--kw-accent) 55%, transparent);
}

.tmo-stage--discover {
  --tmo-color: var(--kw-accent);
}

.tmo-stage--generate {
  --tmo-color: var(--kw-warn);
}

.tmo-stage--order {
  --tmo-color: var(--kw-ok);
}

.tmo-stage--filter {
  --tmo-color: var(--kw-tofu-yellow);
}

.tmo-stage-label {
  font-weight: 650;
  font-size: 0.9rem;
  color: var(--kw-text);
}

.tmo-stage-sub {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.62rem;
  letter-spacing: 0.06em;
  color: var(--kw-text-faint);
}

.tmo-arrow {
  font-size: 1.1rem;
  color: var(--kw-text-faint);
  opacity: 0.35;
  transition: opacity 0.25s ease, color 0.25s ease;
}

.tmo-arrow--lit {
  opacity: 1;
  color: var(--kw-accent-bright);
}
</style>
