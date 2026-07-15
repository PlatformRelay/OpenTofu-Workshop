<script setup lang="ts">
import { computed } from 'vue'

/**
 * DependencyGraph — click-stepped resource/module DAG, revealed in dependency
 * order. This is the S02 (references between blocks) and S07 (module
 * composition) visual: OpenTofu builds a dependency graph and walks it in
 * topological order, so a node can only light once everything it depends on
 * has lit.
 *
 * The DAG (a fan-out + fan-in, so it reads as a graph, not a chain):
 *
 *              ┌─► module.svc_a ─┐
 *   random_pet ┤                 ├─► local_file (manifest)
 *              └─► module.svc_b ─┘
 *
 * One `service` module is consumed twice, both instances seeded by a shared
 * `random_pet`, and both feed a single `local_file` — reference fan-out (S02)
 * and module reuse (S07) in one small, correct graph.
 *
 * Bind `step` to `$clicks` to reveal one item per click, in dependency order —
 * a source node, then its edge, then the dependent node:
 *
 *   <DependencyGraph :step="$clicks" />
 *
 * The reveal list (`revealOrder`) is a flat, topologically-ordered sequence of
 * node/edge items; the DAG shape lives in each item's fixed SVG position, not
 * in the indexing. Every node and edge is always in the DOM — stepping toggles
 * only a `--lit` opacity/filter class, never layout, so overflow at any
 * intermediate step is structurally impossible.
 *
 * step 0 → nothing lit · each click lights the next item · step 8 → all lit.
 * Out-of-range `step` (NaN, negative, overshoot, omitted) clamps into
 * [0, revealOrder.length] and never throws or blanks the slide.
 */
const props = withDefaults(
  defineProps<{
    /** Revealed item count (0–8, dependency-order). Bind to `$clicks`. Clamped. */
    step?: number
  }>(),
  { step: 8 },
)

type Tone = 'source' | 'module' | 'sink'

interface Node {
  kind: 'node'
  key: string
  label: string
  sub: string
  tone: Tone
  x: number
  y: number
}

interface Edge {
  kind: 'edge'
  key: string
  x1: number
  y1: number
  x2: number
  y2: number
}

type RevealItem = Node | Edge

/** Fixed SVG geometry — a 320×180 viewBox that never resizes with `step`. */
const nodes: Record<string, Node> = {
  pet: { kind: 'node', key: 'pet', label: 'random_pet', sub: 'resource', tone: 'source', x: 30, y: 90 },
  svcA: { kind: 'node', key: 'svcA', label: 'module.svc_a', sub: 'service', tone: 'module', x: 160, y: 40 },
  svcB: { kind: 'node', key: 'svcB', label: 'module.svc_b', sub: 'service', tone: 'module', x: 160, y: 140 },
  file: { kind: 'node', key: 'file', label: 'local_file', sub: 'manifest', tone: 'sink', x: 290, y: 90 },
}

/** Node half-extents, so edges dock at the box border, not the centre. */
const NODE_HW = 34
const NODE_HH = 15

/** Build an edge that stops at each node's border for a clean arrowhead. */
function edge(key: string, from: Node, to: Node): Edge {
  const dx = to.x - from.x
  const dy = to.y - from.y
  const len = Math.hypot(dx, dy) || 1
  const ux = dx / len
  const uy = dy / len
  return {
    kind: 'edge',
    key,
    x1: from.x + ux * NODE_HW,
    y1: from.y + uy * NODE_HH,
    x2: to.x - ux * (NODE_HW + 6),
    y2: to.y - uy * (NODE_HH + 6),
  }
}

/**
 * Flat, topologically-ordered reveal sequence: source node, its edge, the
 * dependent node — interleaved so the build follows dependency order.
 */
const revealOrder: RevealItem[] = [
  nodes.pet,
  edge('pet-svcA', nodes.pet, nodes.svcA),
  nodes.svcA,
  edge('pet-svcB', nodes.pet, nodes.svcB),
  nodes.svcB,
  edge('svcA-file', nodes.svcA, nodes.file),
  edge('svcB-file', nodes.svcB, nodes.file),
  nodes.file,
]

const total = revealOrder.length

/** Clamp any incoming step (NaN, negative, overshoot) into [0, total]. */
const activeCount = computed(() => {
  const raw = Number(props.step)
  if (!Number.isFinite(raw)) return total
  return Math.max(0, Math.min(total, Math.trunc(raw)))
})

/** Item at reveal index `i` is lit once step has reached it. */
const isLit = (revealIndex: number) => revealIndex < activeCount.value

/** Reveal index of each item, so we can gate its `--lit` class by position. */
const litFor = (key: string) =>
  isLit(revealOrder.findIndex((item) => item.key === key))

const edges = computed(() => revealOrder.filter((i): i is Edge => i.kind === 'edge'))
const nodeItems = computed(() => revealOrder.filter((i): i is Node => i.kind === 'node'))
</script>

<!-- random_pet → module.svc_a/svc_b → local_file, revealed in dependency order. -->
<template>
  <div class="dg">
    <svg class="dg-svg" viewBox="0 0 320 180" role="img"
      aria-label="Resource dependency graph: random_pet feeds two service module instances that both feed a local_file manifest.">
      <defs>
        <marker id="dg-arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6"
          markerHeight="6" orient="auto-start-reverse">
          <path d="M 0 0 L 10 5 L 0 10 z" fill="currentColor" />
        </marker>
      </defs>

      <!-- Edges first, so nodes paint on top. All edges always present. -->
      <line
        v-for="e in edges"
        :key="e.key"
        class="dg-edge"
        :class="{ 'dg-edge--lit': litFor(e.key) }"
        :x1="e.x1"
        :y1="e.y1"
        :x2="e.x2"
        :y2="e.y2"
        marker-end="url(#dg-arrow)"
      />

      <!-- Nodes. All nodes always present; only the `--lit` class toggles. -->
      <g
        v-for="n in nodeItems"
        :key="n.key"
        class="dg-node"
        :class="[`dg-node--${n.tone}`, { 'dg-node--lit': litFor(n.key) }]"
        :transform="`translate(${n.x}, ${n.y})`"
      >
        <rect class="dg-box" x="-34" y="-15" width="68" height="30" rx="4" />
        <text class="dg-label" text-anchor="middle" y="-2">{{ n.label }}</text>
        <text class="dg-sub" text-anchor="middle" y="9">{{ n.sub }}</text>
      </g>
    </svg>
  </div>
</template>

<style scoped>
.dg {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 0.5rem 0;
  min-width: 0;
}

.dg-svg {
  width: 100%;
  max-width: 40rem;
  max-height: 15rem;
  height: auto;
}

.dg-edge {
  color: var(--kw-text-faint);
  stroke: currentColor;
  stroke-width: 1.6;
  opacity: 0.3;
  transition: opacity 0.25s ease, color 0.25s ease;
}

.dg-edge--lit {
  color: var(--kw-accent-bright);
  opacity: 1;
}

.dg-node {
  --dg-color: var(--kw-border);
  opacity: 0.4;
  filter: grayscale(0.6);
  transition: opacity 0.25s ease, filter 0.25s ease;
}

.dg-node--lit {
  opacity: 1;
  filter: none;
}

.dg-node--source {
  --dg-color: var(--kw-accent);
}

.dg-node--module {
  --dg-color: var(--kw-warn);
}

.dg-node--sink {
  --dg-color: var(--kw-tofu-yellow);
}

.dg-box {
  fill: var(--kw-panel);
  stroke: var(--dg-color);
  stroke-width: 1.5;
}

.dg-node--lit .dg-box {
  filter: drop-shadow(0 0 2px color-mix(in srgb, var(--dg-color) 45%, transparent));
}

.dg-label {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 7px;
  font-weight: 650;
  fill: var(--kw-text);
}

.dg-sub {
  font-family: var(--slidev-code-font-family, monospace);
  font-size: 5px;
  letter-spacing: 0.06em;
  fill: var(--kw-text-faint);
}
</style>
