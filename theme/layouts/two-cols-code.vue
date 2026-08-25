<script setup lang="ts">
import { useSlots } from 'vue'
import LabCallout from '../components/LabCallout.vue'

const props = defineProps<{
  heading?: string
  /** Optional lab reference chip. */
  lab?: string
}>()

const slots = useSlots()
</script>

<!--
  Same two shapes as `comparison`: with an explicit `::left::` the default slot
  holds the kicker + H1 and belongs in the header; without one the default slot
  is the left column itself.
-->
<template>
  <div class="slidev-layout kw-two-cols-code">
    <header class="kw-tcc-header" :class="{ 'kw-tcc-header--intro': slots.left }">
      <h1 v-if="props.heading">{{ props.heading }}</h1>
      <slot name="title" />
      <slot v-if="slots.left" />
    </header>

    <div class="kw-tcc-cols">
      <div class="kw-tcc-left">
        <slot v-if="slots.left" name="left" />
        <slot v-else />
      </div>
      <div class="kw-tcc-right">
        <slot name="right" />
      </div>
    </div>

    <LabCallout v-if="props.lab" :lab="props.lab" class="kw-tcc-lab" />
  </div>
</template>

<style scoped>
.kw-two-cols-code {
  display: flex;
  flex-direction: column;
}

.kw-tcc-header h1 {
  font-size: 1.5rem;
  margin-bottom: 0.6rem;
}

/* Hoisted intro: same budget problem and the same fix as `comparison` — see the
   long note in comparison.vue. Slot children carry the slide's scope id, not
   this component's, so the rule above cannot reach them; `:deep()` can. */
.kw-tcc-header--intro {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  column-gap: 0.75rem;
  margin-bottom: 0.55rem;
}

.kw-tcc-header--intro :deep(p) {
  margin: 0;
}

.kw-tcc-header--intro :deep(h1) {
  font-size: 1.6rem;
  line-height: 1.25;
  margin: 0;
}

.kw-tcc-cols {
  flex: 1;
  display: grid;
  grid-template-columns: 1.1fr 1fr;
  gap: 1.4rem;
  min-height: 0;
  align-items: center;
}

.kw-tcc-left :deep(pre.slidev-code) {
  font-size: 0.85em;
  line-height: 1.45;
}

.kw-tcc-right {
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-height: 0;
}

.kw-tcc-lab {
  position: absolute;
  right: 1.6rem;
  bottom: 1.2rem;
}
</style>
