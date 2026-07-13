<script setup lang="ts">
import { computed } from 'vue'

/**
 * StateEncryptionFlow — click-stepped diagram of OpenTofu client-side state
 * encryption:
 *
 *   plaintext state  →  PBKDF2 key provider  →  AES-GCM method  →  ciphertext
 *
 * Bind `step` to `$clicks` on a slide to reveal stages one click at a time:
 *
 *   <StateEncryptionFlow :step="$clicks" />
 *
 * step 0 → nothing lit · step 1 → plaintext · step 2 → +key provider ·
 * step 3 → +method · step 4 → +ciphertext (all lit). Out-of-range values clamp
 * into [0, 4] — negative or overshoot never throws and never blanks the slide.
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
  tone: 'plaintext' | 'key' | 'method' | 'cipher'
}

const stages: Stage[] = [
  { key: 'plaintext', label: 'plaintext state', sub: '.tfstate', tone: 'plaintext' },
  { key: 'key', label: 'key provider', sub: 'pbkdf2', tone: 'key' },
  { key: 'method', label: 'method', sub: 'aes_gcm', tone: 'method' },
  { key: 'cipher', label: 'ciphertext', sub: 'signed envelope', tone: 'cipher' },
]

/** Clamp any incoming step (NaN, negative, overshoot) into [0, stages.length]. */
const activeCount = computed(() => {
  const raw = Number(props.step)
  if (!Number.isFinite(raw)) return stages.length
  return Math.max(0, Math.min(stages.length, Math.trunc(raw)))
})

const isLit = (index: number) => index < activeCount.value
</script>

<!-- plaintext → key provider → method → ciphertext, revealed stage-by-stage as `step` grows. -->
<template>
  <div class="sef">
    <template v-for="(stage, i) in stages" :key="stage.key">
      <span
        v-if="i > 0"
        class="sef-arrow"
        :class="{ 'sef-arrow--lit': isLit(i) }"
        aria-hidden="true"
      >→</span>
      <div
        class="sef-stage"
        :class="[`sef-stage--${stage.tone}`, { 'sef-stage--lit': isLit(i) }]"
      >
        <span class="sef-stage-label">{{ stage.label }}</span>
        <span class="sef-stage-sub">{{ stage.sub }}</span>
      </div>
    </template>
  </div>
</template>

<style scoped>
.sef {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 0;
  min-width: 0;
}

.sef-stage {
  --sef-color: var(--kw-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
  min-width: 7rem;
  padding: 0.7rem 0.9rem;
  background: var(--kw-panel);
  border: 1px solid var(--kw-border);
  border-bottom: 3px solid var(--sef-color);
  border-radius: var(--kw-radius-sm);
  opacity: 0.4;
  filter: grayscale(0.6);
  transition: opacity 0.25s ease, filter 0.25s ease, box-shadow 0.25s ease;
}

.sef-stage--lit {
  opacity: 1;
  filter: none;
  box-shadow: 0 0 0 1px color-mix(in srgb, var(--sef-color) 40%, transparent);
}

.sef-stage--plaintext {
  --sef-color: var(--kw-danger);
}

.sef-stage--key {
  --sef-color: var(--kw-accent);
}

.sef-stage--method {
  --sef-color: var(--kw-warn);
}

.sef-stage--cipher {
  --sef-color: var(--kw-ok);
}

.sef-stage-label {
  font-weight: 650;
  font-size: 0.9rem;
  color: var(--kw-text);
}

.sef-stage-sub {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.62rem;
  letter-spacing: 0.06em;
  color: var(--kw-text-faint);
}

.sef-arrow {
  font-size: 1.1rem;
  color: var(--kw-text-faint);
  opacity: 0.35;
  transition: opacity 0.25s ease, color 0.25s ease;
}

.sef-arrow--lit {
  opacity: 1;
  color: var(--kw-accent-bright);
}
</style>
