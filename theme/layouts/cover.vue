<script setup lang="ts">
const props = defineProps<{
  /** Small mono line under the title block, e.g. "3 days · 50% hands-on". */
  meta?: string
  /** Optional workshop logo shown above the title, e.g. "/branding/logo-512.png". */
  logo?: string
}>()

const base = import.meta.env.BASE_URL

/** Resolve a public-dir absolute path ("/x.png") against the deck's base. */
function resolveAsset(url: string) {
  return url.startsWith('/') ? base + url.slice(1) : url
}
</script>

<template>
  <div class="slidev-layout kw-cover kw-grid-bg">
    <img
      class="kw-cover-mark"
      :src="`${base}icons/opentofu-icon-white.svg`"
      alt=""
      aria-hidden="true"
    />

    <div class="kw-cover-inner">
      <img
        v-if="props.logo"
        class="kw-cover-logo"
        :src="resolveAsset(props.logo)"
        alt=""
        aria-hidden="true"
      />
      <slot />
    </div>

    <div v-if="props.meta" class="kw-cover-meta">{{ props.meta }}</div>
  </div>
</template>

<style scoped>
.kw-cover {
  display: flex;
  flex-direction: column;
  justify-content: center;
  overflow: hidden;
}

/* Oversized wheel watermark — identity without decoration. */
.kw-cover-mark {
  position: absolute;
  right: -12%;
  top: 50%;
  transform: translateY(-50%);
  height: 130%;
  opacity: 0.05;
  pointer-events: none;
}

.kw-cover-inner {
  position: relative;
  max-width: 70%;
}

/* Workshop logo mark above the title — dark tile, so soften with rounding. */
.kw-cover-logo {
  height: 5rem;
  width: 5rem;
  border-radius: 0.75rem;
  margin-bottom: 1.2rem;
  border: 1px solid rgb(255 255 255 / 0.08);
}

.kw-cover-inner :deep(h1) {
  font-size: 3rem;
  line-height: 1.1;
  margin-bottom: 0.6rem;
}

.kw-cover-inner :deep(h1)::before {
  content: '';
  display: block;
  width: 3.5rem;
  height: 4px;
  border-radius: 2px;
  background: var(--kw-accent);
  margin-bottom: 1.1rem;
}

.kw-cover-inner :deep(p) {
  color: var(--kw-text-dim);
  font-size: 1.15rem;
  line-height: 1.5;
}

.kw-cover-meta {
  position: absolute;
  left: 3.5rem;
  bottom: 2.6rem;
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.72rem;
  letter-spacing: 0.12em;
  color: var(--kw-text-faint);
}
</style>
