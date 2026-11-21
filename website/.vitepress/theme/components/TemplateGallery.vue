<script setup lang="ts">
// Every scanner template: a screenshot, its constructor and what it is for.
// `limit` shows the first ones only (the home page).
import { computed } from 'vue'
import { withBase } from 'vitepress'
import { templates } from '../templates'

const props = defineProps<{ limit?: number; compact?: boolean }>()
const shown = computed(() => (props.limit ? templates.slice(0, props.limit) : templates))
</script>

<template>
  <ul class="gallery" :class="{ compact }">
    <li v-for="t in shown" :key="t.demo">
      <img :src="withBase(`/shots/${t.shot}.png`)" :alt="`The ${t.name} template`" loading="lazy" />
      <span class="name">{{ t.name }}</span>
      <code class="ctor">{{ t.ctor }}</code>
      <span v-if="!compact" class="for">{{ t.forWhat }}</span>
    </li>
  </ul>
</template>

<style scoped>
.gallery {
  list-style: none;
  margin: 24px 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 28px 20px;
}

.gallery.compact {
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
}

.vp-doc .gallery li + li {
  margin-top: 0;
}

li {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin: 0;
}

img {
  width: 100%;
  aspect-ratio: 390 / 844;
  object-fit: cover;
  border-radius: 24px;
  background: var(--fz-camera);
  margin-bottom: 6px;
}

.name {
  font-weight: 600;
  font-size: 16px;
  color: var(--vp-c-text-1);
}

.ctor {
  align-self: flex-start;
  font-size: 12px !important;
  overflow-wrap: anywhere;
}

.for {
  font-size: 14px;
  line-height: 21px;
  color: var(--vp-c-text-2);
}
</style>
