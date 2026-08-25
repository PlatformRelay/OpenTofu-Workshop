<script setup lang="ts">
const props = defineProps<{
  heading?: string
  caption?: string
}>()
</script>

<template>
  <div class="slidev-layout kw-topology">
    <header class="kw-topo-header">
      <h1 v-if="props.heading">{{ props.heading }}</h1>
      <slot name="title" />
    </header>

    <div class="kw-topo-canvas">
      <slot />
    </div>

    <footer v-if="props.caption" class="kw-topo-caption">{{ props.caption }}</footer>
  </div>
</template>

<style scoped>
.kw-topology {
  display: flex;
  flex-direction: column;
}

.kw-topo-header h1 {
  font-size: 1.5rem;
  margin-bottom: 0.6rem;
}

/*
  Dotted-grid canvas so architecture boxes read as a diagram, not a list.

  The canvas stacks: kicker, H1, the diagram and any trailing caption all land in
  the DEFAULT slot, so as a flex ROW they became side-by-side siblings and a
  trailing `<p>` printed on top of the last card (S19/S25 at their final click).
  Column + `stretch` is what these slides assume: the grid needs the full width
  (`center` would shrink-wrap it to max-content), and `justify-content: center`
  keeps short content optically centred while overflowing symmetrically rather
  than only downward — so verify height, not just width, after changing this.
*/
.kw-topo-canvas {
  flex: 1;
  min-height: 0;
  flex-direction: column;
  align-items: stretch;
  border: 1px solid var(--kw-border);
  border-radius: var(--kw-radius);
  background-color: var(--kw-bg-soft);
  background-image: radial-gradient(
    color-mix(in srgb, var(--kw-border) 70%, transparent) 1px,
    transparent 1px
  );
  background-size: 22px 22px;
  padding: 1.2rem;
  display: flex;
  justify-content: center;
}

.kw-topo-caption {
  margin-top: 0.6rem;
  font-size: 0.8rem;
  color: var(--kw-text-dim);
  text-align: center;
}
</style>
