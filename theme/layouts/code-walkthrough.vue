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

/* With a ::notes:: rail the code shares the row instead of the column. */
.kw-cw-body--railed {
  display: grid;
  grid-template-columns: 1.5fr 1fr;
  gap: 1.2rem;
  align-items: stretch;
  overflow: hidden;
}

.kw-cw-body--railed :deep(pre.slidev-code) {
  font-size: 0.78em;
  line-height: 1.42;
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
