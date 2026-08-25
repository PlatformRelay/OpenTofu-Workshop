<script setup lang="ts">
import { useSlots } from 'vue'

const props = defineProps<{
  heading?: string
  /** Panel titles, e.g. "Ingress" / "Gateway API". */
  leftHeading?: string
  rightHeading?: string
  /** Small chips next to the panel titles, e.g. "today" / "successor". */
  leftBadge?: string
  rightBadge?: string
}>()

const slots = useSlots()
</script>

<!--
  Two shapes are supported, and both must keep every column visible:

  1. `::left::` / `::right::` — the left column is the `left` slot, and whatever
     precedes `::left::` (kicker + H1) is the slide intro, so it belongs in the
     header rather than inside the left panel.
  2. default / `::right::` — no `left` slot, so the default slot *is* the left
     column, exactly as before.
-->
<template>
  <div class="slidev-layout kw-comparison">
    <header class="kw-cmp-header" :class="{ 'kw-cmp-header--intro': slots.left }">
      <h1 v-if="props.heading">{{ props.heading }}</h1>
      <slot name="title" />
      <slot v-if="slots.left" />
    </header>

    <div class="kw-cmp-cols">
      <section class="kw-cmp-panel">
        <header class="kw-cmp-panel-head">
          <h2>{{ props.leftHeading }}</h2>
          <span v-if="props.leftBadge" class="kw-cmp-badge">{{ props.leftBadge }}</span>
        </header>
        <div class="kw-cmp-panel-body">
          <slot v-if="slots.left" name="left" />
          <slot v-else />
        </div>
      </section>

      <section class="kw-cmp-panel">
        <header class="kw-cmp-panel-head">
          <h2>{{ props.rightHeading }}</h2>
          <span v-if="props.rightBadge" class="kw-cmp-badge">{{ props.rightBadge }}</span>
        </header>
        <div class="kw-cmp-panel-body">
          <slot name="right" />
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.kw-comparison {
  display: flex;
  flex-direction: column;
}

.kw-cmp-header h1 {
  font-size: 1.5rem;
  margin-bottom: 0.7rem;
}

/*
  Hoisted-intro header. Every pixel this header takes comes straight off
  `.kw-cmp-cols`, and the right panel is the one that pays: on `main` this header
  was empty for `::left::` slides, so the columns owned the whole canvas. Left
  unstyled it costs 115px of a 472px canvas (measured) and pushes S13's right
  panel 68px off the slide — an invisible right column, the mirror of the bug
  this layout's `left` slot was added to fix.

  Kicker and title therefore share ONE baseline row, and the slot content is
  styled through `:deep()`: slot children are compiled in the slide's scope, not
  this component's, so a plain `.kw-cmp-header h1` rule never reaches them (it
  only ever styled the `heading` prop's own `<h1>` above). Measured after: 34px
  on all twelve `::left::` slides, none of which spills the canvas.
*/
.kw-cmp-header--intro {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  column-gap: 0.75rem;
  margin-bottom: 0.4rem;
}

.kw-cmp-header--intro :deep(p) {
  margin: 0;
}

.kw-cmp-header--intro :deep(h1) {
  font-size: 1.6rem;
  line-height: 1.25;
  margin: 0;
}

.kw-cmp-cols {
  flex: 1;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.1rem;
  min-height: 0;
  align-items: stretch;
}

.kw-cmp-panel {
  background: var(--kw-panel);
  border: 1px solid var(--kw-border);
  border-radius: var(--kw-radius);
  padding: 0.75rem 1.1rem;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.kw-cmp-panel-head {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  border-bottom: 1px solid var(--kw-border-soft);
  padding-bottom: 0.4rem;
  margin-bottom: 0.55rem;
}

.kw-cmp-panel-head h2 {
  font-size: 1.02rem;
  margin: 0;
}

.kw-cmp-badge {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 0.62rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--kw-text-dim);
  border: 1px solid var(--kw-border);
  border-radius: 999px;
  padding: 0.12rem 0.55rem;
}

.kw-cmp-panel-body {
  flex: 1;
  min-height: 0;
  font-size: 0.88rem;
}

/*
  Panel bodies stack several markdown blocks and the default 1em paragraph
  rhythm costs ~16px a gap. Bounding the header alone left S13's right panel 35px
  past its own border, so the rhythm above (plus the trimmed panel padding) makes
  up the rest. Tightening a margin can only ever REDUCE a height and never widen
  a line, so it is safe for the panels that already fit — measured: every
  `::left::` slide, S13 included, now overflows its panel by 0px.

  Note this beats a slide's own `mt-*` utility on panel paragraphs; that is
  deliberate, the panels want one rhythm rather than per-slide spacing.
*/
.kw-cmp-panel-body > :deep(:first-child) {
  margin-top: 0;
}

.kw-cmp-panel-body :deep(p) {
  margin: 0.5em 0;
}

.kw-cmp-panel-body :deep(pre.slidev-code) {
  font-size: 0.78em;
  line-height: 1.45;
  background: var(--kw-bg-soft) !important;
}
</style>
