<script setup lang="ts">
// Barcodes rendered by test/tool/site_images_test.dart into public/codes/
// (`make site-shots`), each checked to read back before it is written.
import { withBase } from 'vitepress'

defineProps<{
  items: { file: string; label: string; alt: string }[]
}>()
</script>

<template>
  <ul class="codes">
    <li v-for="item in items" :key="item.file">
      <img :src="withBase(`/codes/${item.file}`)" :alt="item.alt" loading="lazy" />
      <code>{{ item.label }}</code>
    </li>
  </ul>
</template>

<style scoped>
.codes {
  list-style: none;
  margin: 20px 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 20px 16px;
}

.vp-doc .codes li + li {
  margin-top: 0;
}

li {
  margin: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
}

img {
  width: 100%;
  aspect-ratio: 1;
  object-fit: contain;
  border-radius: 16px;
  border: 1px solid var(--vp-c-divider);
  background: #f4f6f9;
  padding: 8px;
  box-sizing: border-box;
}

code {
  font-size: 12px !important;
  overflow-wrap: anywhere;
}
</style>
