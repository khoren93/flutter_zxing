<script setup lang="ts">
// The home page, as designed in Claude Design ("flutter_zxing docs site").
import { ref } from 'vue'
import { withBase } from 'vitepress'
import TemplateGallery from './TemplateGallery.vue'
import scanSample from '../samples/home_scan.snippet?raw'
import screenSample from '../samples/home_screen.snippet?raw'
import createSample from '../samples/home_create.snippet?raw'

const version: string = __PACKAGE_VERSION__
const install = `flutter pub add flutter_zxing:^${version}`

const copied = ref(false)
async function copyInstall() {
  try {
    await navigator.clipboard.writeText(install)
    copied.value = true
    setTimeout(() => (copied.value = false), 1600)
  } catch {
    // No clipboard (an insecure page): the command stays selectable.
  }
}

const features = [
  {
    title: 'Scan with the camera',
    text: 'A whole screen in one line, 16 templates, or the camera alone under your own interface.',
    api: 'scanBarcode · BarcodeScanner',
    link: '/scanning/scan-one-code',
  },
  {
    title: 'Read images',
    text: 'Photos and screenshots in any format Flutter decodes, on a background isolate, every code in them.',
    api: 'BarcodeReader',
    link: '/reading/images',
  },
  {
    title: 'Create barcodes',
    text: '30 formats as widgets, sharp at any size, styled, with a logo, exported to PNG and SVG.',
    api: 'BarcodeView · BarcodeWriter',
    link: '/creating/barcode-view',
  },
  {
    title: 'Know what is inside',
    text: 'Links, Wi-Fi, contacts, events, GS1 data and payments as Dart types, with a link to open each.',
    api: 'barcode.content',
    link: '/content/overview',
  },
  {
    title: 'Your look, your language',
    text: 'Your colors, icons, window shape, scan line and buttons; texts in six languages that follow the app.',
    api: 'ScannerTheme · ScannerLocalizations',
    link: '/scanning/theming',
  },
  {
    title: 'Print sheets of labels',
    text: 'Thousands of codes on A4 or Letter pages in a grid, as a PDF or SVG, with a preview.',
    api: 'BarcodeLabelSheet',
    link: '/creating/label-sheets',
  },
]

// Checked by tool/check_site_snippets.dart like the code in the pages.
const samples = [
  { id: 'scan', label: 'Scan a code', code: scanSample },
  { id: 'screen', label: 'A scanner screen', code: screenSample },
  { id: 'create', label: 'Create a code', code: createSample },
]
const tab = ref('scan')

const stats = [
  { n: '32', text: 'formats to read, Micro QR, rMQR and DataBar included' },
  { n: '30', text: 'formats to create, with one format list for both' },
  { n: '6', text: 'platforms on one C++ engine, WebAssembly on the web' },
  { n: '0', text: 'calls to Google services or the network' },
]
</script>

<template>
  <div class="home">
    <section class="hero">
      <div class="lead">
        <p class="eyebrow">Barcodes for Flutter · Android, iOS, macOS, Linux, Windows, web</p>
        <h1>Point. Lock. Done.</h1>
        <p class="text">
          Scan and create QR codes and barcodes on every platform with zxing-cpp built into your app. A
          complete scanner in one line, or just the camera and your own interface.
        </p>
        <div class="actions">
          <a class="button primary" :href="withBase('/guide/quick-start')">Get started</a>
          <a class="button" :href="withBase('/demo/')" target="_self">Open the demo</a>
        </div>
        <div class="install">
          <span class="prompt" aria-hidden="true">$</span>
          <code>{{ install }}</code>
          <button type="button" @click="copyInstall">{{ copied ? 'Copied' : 'Copy' }}</button>
        </div>
      </div>
      <div class="phone">
        <img
          :src="withBase('/shots/content.png')"
          alt="The Content template with a Wi-Fi network read from a QR code"
        />
      </div>
    </section>

    <section class="features">
      <a v-for="f in features" :key="f.title" class="feature" :href="withBase(f.link)">
        <span class="title">{{ f.title }}</span>
        <span class="text">{{ f.text }}</span>
        <code>{{ f.api }}</code>
      </a>
    </section>

    <section class="quick">
      <div class="inner">
        <div class="lead">
          <p class="eyebrow">Quick start</p>
          <h2>Three lines to a working scanner</h2>
          <p class="text">
            No CMake, CocoaPods or Gradle setup: a build hook compiles the engine. Every call that
            touches it runs off the UI thread.
          </p>
          <a :href="withBase('/guide/quick-start')">Read the quick start</a>
        </div>
        <div class="code">
          <div class="tabs" role="tablist" aria-label="Examples">
            <button
              v-for="s in samples"
              :key="s.id"
              type="button"
              role="tab"
              :aria-selected="tab === s.id"
              :class="{ on: tab === s.id }"
              @click="tab = s.id"
            >
              {{ s.label }}
            </button>
          </div>
          <pre><code>{{ samples.find((s) => s.id === tab)!.code.trimEnd() }}</code></pre>
        </div>
      </div>
    </section>

    <section class="templates">
      <div class="head">
        <div>
          <p class="eyebrow">Templates</p>
          <h2>A finished screen for every job</h2>
        </div>
        <a :href="withBase('/templates')">All 16 templates</a>
      </div>
      <TemplateGallery :limit="5" compact />
    </section>

    <section class="stats">
      <div v-for="s in stats" :key="s.n + s.text" class="stat">
        <span class="n">{{ s.n }}</span>
        <span class="text">{{ s.text }}</span>
      </div>
    </section>
  </div>
</template>

<style scoped>
.home {
  --gutter: 24px;
  color: var(--vp-c-text-1);
}

section {
  max-width: 1240px;
  margin: 0 auto;
  padding: 0 var(--gutter);
}

h1,
h2 {
  font-family: var(--fz-font-display);
  font-weight: 600;
  margin: 0;
}

.eyebrow {
  margin: 0;
  font-size: 12px;
  font-weight: 500;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--vp-c-text-2);
}

.hero {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 56px;
  padding-top: 72px;
  padding-bottom: 72px;
}

.hero .lead {
  flex: 1 1 480px;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.hero h1 {
  font-size: clamp(44px, 7vw, 64px);
  line-height: 1.06;
  letter-spacing: -0.03em;
}

.hero .text {
  margin: 0;
  font-size: 19px;
  line-height: 30px;
  color: var(--vp-c-text-2);
  max-width: 560px;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.button {
  display: inline-flex;
  align-items: center;
  min-height: 48px;
  padding: 0 24px;
  border-radius: 999px;
  border: 1px solid var(--vp-c-divider);
  background: var(--vp-c-bg-elv);
  color: var(--vp-c-text-1);
  font-weight: 600;
  font-size: 16px;
  text-decoration: none;
}

.button.primary {
  background: var(--fz-lock);
  border-color: var(--fz-lock);
  color: var(--fz-on-lock);
}

.button.primary:hover {
  background: #27d3a5;
}

.install {
  display: flex;
  align-items: center;
  gap: 12px;
  max-width: 520px;
  padding: 10px 10px 10px 18px;
  border-radius: 16px;
  background: var(--fz-code);
  color: #eef1f5;
  font-family: var(--vp-font-family-mono);
  font-size: 15px;
}

.install .prompt {
  color: #4ff0c4;
}

.install code {
  flex: 1;
  min-width: 0;
  overflow-x: auto;
  white-space: nowrap;
  background: none;
  color: inherit;
  padding: 0;
}

.install button {
  min-height: 36px;
  padding: 0 12px;
  border-radius: 10px;
  border: 1px solid var(--fz-code-line);
  background: #161a21;
  color: #eef1f5;
  font: 600 13px var(--vp-font-family-base);
  cursor: pointer;
}

.phone {
  flex: 0 1 320px;
  display: flex;
  justify-content: center;
  margin: 0 auto;
}

.phone img {
  width: min(100%, 300px);
  border-radius: 44px;
  border: 10px solid #0e1218;
  background: var(--fz-camera);
  box-shadow: 0 30px 80px rgba(14, 18, 24, 0.28);
}

.features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 16px;
  padding-bottom: 80px;
}

.feature {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 24px;
  border-radius: 16px;
  background: var(--vp-c-bg-elv);
  border: 1px solid var(--vp-c-divider);
  color: var(--vp-c-text-1);
  text-decoration: none;
  transition: border-color 0.14s;
}

.feature:hover {
  border-color: var(--fz-lock);
}

.feature .title {
  font-family: var(--fz-font-display);
  font-weight: 600;
  font-size: 19px;
}

.feature .text {
  font-size: 15px;
  line-height: 22px;
  color: var(--vp-c-text-2);
}

.feature code {
  font-family: var(--vp-font-family-mono);
  font-size: 13px;
  color: var(--fz-lock-ink);
}

.quick {
  max-width: none;
  padding: 0;
  background: #0b0e13;
  color: #eef1f5;
}

.quick .inner {
  max-width: 1240px;
  margin: 0 auto;
  padding: 80px var(--gutter);
  display: flex;
  flex-wrap: wrap;
  gap: 48px;
  align-items: center;
}

.quick .lead {
  flex: 1 1 340px;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.quick .eyebrow,
.quick .text {
  color: #a7b0bd;
}

.quick h2 {
  font-size: clamp(30px, 4vw, 40px);
  line-height: 1.1;
  letter-spacing: -0.02em;
}

.quick .text {
  margin: 0;
  font-size: 17px;
  line-height: 26px;
}

.quick .lead a {
  color: #4ff0c4;
  font-weight: 600;
}

.quick .code {
  flex: 1 1 520px;
  min-width: 0;
  border-radius: 24px;
  background: #161a21;
  border: 1px solid #283039;
  overflow: hidden;
}

.tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  padding: 10px;
  border-bottom: 1px solid #283039;
}

.tabs button {
  min-height: 36px;
  padding: 0 14px;
  border-radius: 999px;
  color: #a7b0bd;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
}

.tabs button.on {
  background: var(--fz-lock);
  color: var(--fz-on-lock);
}

.quick pre {
  margin: 0;
  padding: 24px;
  overflow-x: auto;
  font-family: var(--vp-font-family-mono);
  font-size: 14px;
  line-height: 23px;
}

.templates {
  padding-top: 80px;
  padding-bottom: 56px;
}

.templates .head {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: flex-end;
  gap: 16px;
}

.templates .head > div {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.templates h2 {
  font-size: clamp(30px, 4vw, 40px);
  line-height: 1.1;
  letter-spacing: -0.02em;
}

.templates a {
  font-weight: 600;
}

.stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 1px;
  padding: 0;
  margin-bottom: 80px;
  background: var(--vp-c-divider);
  border: 1px solid var(--vp-c-divider);
  border-radius: 24px;
  overflow: hidden;
  max-width: calc(1240px - 2 * var(--gutter));
}

.stat {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 28px;
  background: var(--vp-c-bg-elv);
}

.stat .n {
  font-family: var(--fz-font-display);
  font-weight: 600;
  font-size: 34px;
}

.stat .text {
  font-size: 15px;
  color: var(--vp-c-text-2);
}

@media (max-width: 1288px) {
  .stats {
    margin-left: var(--gutter);
    margin-right: var(--gutter);
  }
}

@media (max-width: 640px) {
  .home {
    --gutter: 16px;
  }
  .hero {
    padding-top: 40px;
  }
}
</style>
