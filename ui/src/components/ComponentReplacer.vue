<template>
  <div v-if="visible" class="replacer-root" tabindex="-1" :inert="!visible">
    <slot />
  </div>
</template>

<script>
/**
 * ComponentReplacer
 * ─────────────────
 * When `visible` is true, covers all siblings inside the parent container
 * and shows slot content centred in their place.
 * No v-if/v-else needed at the usage site.
 *
 * REQUIREMENTS
 *   - Parent must have `position: relative` (or absolute / fixed).
 *
 * USAGE
 *   <div style="position: relative;">
 *
 *     <ComponentReplacer :visible="someCondition">
 *       <div>Some content to show when visible</div>
 *     </ComponentReplacer>
 *
 *     Add class="replacer-above" to any sibling that should stay visible
 *     and interactive above the overlay (e.g. a page title):
 *     <div class="settingsTitle replacer-above">Page Title</div>
 *
 *     Normal siblings are covered (but remain in the DOM):
 *     <SomeForm />
 *     <SomeList />
 *
 *   </div>
 */
export default {
  name: "ComponentReplacer",

  props: {
    /** When true: covers all siblings and shows slot content. */
    visible: { type: Boolean, default: false },
  },
};
</script>

<style scoped>
/*
 * Stretches to fill the nearest position:relative ancestor,
 * sitting above all siblings (z-index) and centring slot content.
 * The parent container must have position:relative (or absolute/fixed).
 */
.replacer-root {
  position: absolute;
  inset: 0;
  z-index: 10;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  background: var(--background-color);
}

/*
 * Add class="replacer-above" to any sibling that should remain
 * visible and interactive above the replacer overlay.
 */
:global(.replacer-above) {
  position: relative;
  z-index: 11;
}
</style>
