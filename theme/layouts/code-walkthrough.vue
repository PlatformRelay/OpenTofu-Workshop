<script setup lang="ts">
import { useSlots } from 'vue'
import LabCallout from '../components/LabCallout.vue'

const props = defineProps<{
  /** Slide heading shown in the header bar. */
  heading?: string
  /** Optional lab reference, e.g. "labs/day-1/05-pod.md". */
  lab?: string
}>()

const slots = useSlots()
</script>

<!--
  Full-width code by default. When a slide fills the `::notes::` slot with
  <CodeNote> items the layout splits into code + annotation rail, so the notes
  get vertical room instead of stealing height from an already tall code block.
-->
<template>
  <div class="slidev-layout kw-code-walkthrough">
    <header class="kw-cw-header">
      <h1 v-if="props.heading">{{ props.heading }}</h1>
      <slot name="title" />
    </header>

    <div class="kw-cw-body" :class="{ 'kw-cw-body--railed': slots.notes }">
      <div class="kw-cw-code">
        <slot />
      </div>
      <aside v-if="slots.notes" class="kw-cw-rail">
        <slot name="notes" />
      </aside>
    </div>

    <LabCallout v-if="props.lab" :lab="props.lab" class="kw-cw-lab" />
  </div>
</template>

<style scoped>
.kw-code-walkthrough {
  display: flex;
  flex-direction: column;
}

.kw-cw-header h1 {
  font-size: 1.5rem;
  margin-bottom: 0.6rem;
}

.kw-cw-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-height: 0;
}

.kw-cw-code {
  min-width: 0;
  min-height: 0;
  max-height: 100%;
  overflow: auto;
}

/* Code is the star of this layout: give it room. */
.kw-cw-body :deep(.slidev-code-wrapper) {
  max-height: 100%;
}

.kw-cw-body :deep(pre.slidev-code) {
  font-size: 0.95em;
  line-height: 1.5;
}

/*
  With a ::notes:: rail the code shares the row instead of the column, so the
  split is deliberately code-heavy and the type steps down to match. The widest
  line these slides carry is 86 columns (S18's captured `infracost` table) and
  it must not be clipped — an invisible right-hand column is the same defect
  this layout's notes slot exists to fix. `scripts/slide-slots.test.mjs` gates
  that budget at 90 columns.

  Code size MUST be set through --slidev-code-font-size: Slidev's own
  `.slidev-code { font-size: var(--slidev-code-font-size) !important }`
  (@slidev/client/styles/code.css:40) beats any `font-size` a layout declares.
*/
.kw-cw-body--railed {
  display: grid;
  grid-template-columns: 2.2fr 1fr;
  gap: 1rem;
  align-items: stretch;
  overflow: hidden;
  --slidev-code-font-size: 10.4px;
  --slidev-code-line-height: 1.45;
}

.kw-cw-body--railed .kw-cw-rail :deep(.kw-code-note) {
  padding: 0.5rem 0.7rem;
}

.kw-cw-body--railed .kw-cw-rail :deep(.kw-code-note-body) {
  font-size: 0.74rem;
  line-height: 1.4;
}

.kw-cw-rail {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 0.55rem;
  min-height: 0;
  min-width: 0;
  overflow: auto;
}

.kw-cw-lab {
  position: absolute;
  right: 1.6rem;
  bottom: 1.2rem;
}
</style>
