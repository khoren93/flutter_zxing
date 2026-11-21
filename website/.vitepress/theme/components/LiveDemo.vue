<script setup lang="ts">
// The demo app in a phone frame, next to the code it shows. It loads only
// when the reader asks for it: the app is several megabytes and wants the
// camera. Until then the frame shows a screenshot of the same screen.
import { computed, ref } from 'vue'
import { withBase } from 'vitepress'

const props = defineProps<{
  /** Query of the demo, such as `template=payment` or `tab=create`. */
  query?: string
  /** Screenshot in public/shots/ shown before the demo loads. */
  shot?: string
  /** What the frame shows, for screen readers. */
  label?: string
}>()

// The demo is built next to the site (/demo/). VITE_DEMO_URL points
// `npm run dev` at another one, such as a local `flutter run -d chrome`.
const demoBase: string = import.meta.env.VITE_DEMO_URL || withBase('/demo/')
const src = computed(() => (props.query ? `${demoBase}?${props.query}` : demoBase))
const started = ref(false)
</script>

<template>
  <figure class="live-demo">
    <div class="frame">
      <iframe
        v-if="started"
        :src="src"
        :title="label ?? 'flutter_zxing demo'"
        allow="camera; clipboard-write; fullscreen"
        loading="lazy"
      ></iframe>
      <template v-else>
        <img
          v-if="shot"
          class="poster"
          :src="withBase(`/shots/${shot}.png`)"
          :alt="label ?? 'The demo app'"
          loading="lazy"
        />
        <button type="button" class="start" @click="started = true">Start the live demo</button>
      </template>
    </div>
    <figcaption>
      <span>The demo app on the web build of the package. Allow the camera, or pick a photo of a code.</span>
      <a :href="src" target="_blank" rel="noopener">Open full screen</a>
    </figcaption>
  </figure>
</template>

<style scoped>
.live-demo {
  margin: 24px 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.frame {
  position: relative;
  width: min(100%, 340px);
  aspect-ratio: 390 / 844;
  border-radius: 40px;
  border: 8px solid #0e1218;
  background: var(--fz-camera);
  overflow: hidden;
  box-shadow: 0 20px 50px rgba(14, 18, 24, 0.22);
}

iframe,
.poster {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  object-fit: cover;
}

.start {
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  min-height: 48px;
  padding: 0 24px;
  border-radius: 999px;
  background: var(--fz-lock);
  color: var(--fz-on-lock);
  font-weight: 600;
  font-size: 16px;
  white-space: nowrap;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
  cursor: pointer;
}

.start:hover {
  background: #27d3a5;
}

figcaption {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  max-width: 340px;
  text-align: center;
  font-size: 13px;
  line-height: 19px;
  color: var(--vp-c-text-2);
}

figcaption a {
  font-weight: 600;
}
</style>
