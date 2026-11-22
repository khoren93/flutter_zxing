// The default VitePress theme in the flutter_zxing design system, with the
// site's own components: the home page, the live demo and the template
// gallery.
import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import CodeGallery from './components/CodeGallery.vue'
import HomePage from './components/HomePage.vue'
import LiveDemo from './components/LiveDemo.vue'
import TemplateGallery from './components/TemplateGallery.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('CodeGallery', CodeGallery)
    app.component('HomePage', HomePage)
    app.component('LiveDemo', LiveDemo)
    app.component('TemplateGallery', TemplateGallery)
  },
} satisfies Theme
