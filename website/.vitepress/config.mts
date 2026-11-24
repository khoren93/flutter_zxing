import { readFileSync } from 'node:fs'
import { defineConfig } from 'vitepress'

// The site is served from GitHub Pages under /flutter_zxing/; the demo app
// sits next to it under /flutter_zxing/demo/ (.github/workflows/pages.yml).
const base = '/flutter_zxing/'
const site = 'https://khoren93.github.io/flutter_zxing/'
const repo = 'https://github.com/khoren93/flutter_zxing'

// The branch the pages link to for sources.
const branch = 'main'

// The version the pages describe: the package's own, so the two never differ.
const pubspec = readFileSync(new URL('../../pubspec.yaml', import.meta.url), 'utf8')
const version = /^version:\s*(\S+)\s*$/m.exec(pubspec)?.[1]
if (!version) {
  throw new Error('No version in pubspec.yaml')
}

// Old links to the demo (`/flutter_zxing/?tab=create`) open it at its new
// address. Runs before the page renders.
const demoRedirect = `(() => {
  const root = ${JSON.stringify(base)};
  const path = location.pathname.endsWith('/') ? location.pathname : location.pathname + '/';
  if (path === root && /[?&]tab=/.test(location.search)) {
    location.replace(root + 'demo/' + location.search + location.hash);
  }
})()`

export default defineConfig({
  base,
  lang: 'en-US',
  title: 'flutter_zxing',
  description:
    'Scan and create QR codes and barcodes in Flutter on Android, iOS, macOS, Linux, Windows and the web, with zxing-cpp built into your app.',
  cleanUrls: true,
  lastUpdated: false,
  sitemap: { hostname: site },

  head: [
    ['script', {}, demoRedirect],
    ['link', { rel: 'icon', type: 'image/png', href: `${base}favicon.png` }],
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    [
      'link',
      {
        rel: 'stylesheet',
        href: 'https://fonts.googleapis.com/css2?family=Instrument+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;500&family=Sora:wght@500;600&display=swap',
      },
    ],
    ['meta', { name: 'theme-color', content: '#2ee6b5' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:url', content: site }],
    ['meta', { property: 'og:image', content: `${site}shots/content.png` }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { property: 'og:title', content: 'flutter_zxing' }],
    [
      'meta',
      {
        property: 'og:description',
        content: 'Scan and create QR codes and barcodes in Flutter on every platform.',
      },
    ],
  ],

  markdown: {
    // Code is dark in both themes, as in the design.
    theme: { light: 'github-dark', dark: 'github-dark' },
    // %VERSION% in a page, code blocks included, is the package version.
    config(md) {
      md.core.ruler.after('normalize', 'package_version', (state) => {
        state.src = state.src.replaceAll('%VERSION%', version)
      })
    },
  },

  vite: {
    define: { __PACKAGE_VERSION__: JSON.stringify(version) },
  },

  themeConfig: {
    siteTitle: 'flutter_zxing',
    nav: [
      { text: 'Guides', link: '/guide/quick-start', activeMatch: '^/(guide|scanning|reading|creating|content|more)/' },
      { text: 'Templates', link: '/templates' },
      { text: 'Use cases', link: '/use-cases' },
      { text: 'Formats', link: '/formats' },
      { text: 'API reference', link: `https://pub.dev/documentation/flutter_zxing/${version}/` },
      { text: 'Demo', link: `${site}demo/`, target: '_self' },
      {
        text: version,
        items: [
          { text: 'Changelog', link: `${repo}/blob/${branch}/CHANGELOG.md` },
          { text: 'pub.dev', link: 'https://pub.dev/packages/flutter_zxing' },
        ],
      },
    ],

    sidebar: [
      {
        text: 'Get started',
        items: [
          { text: 'Quick start', link: '/guide/quick-start' },
          { text: 'Installation', link: '/guide/installation' },
          { text: 'Platforms', link: '/guide/platforms' },
        ],
      },
      {
        text: 'Scanning',
        items: [
          { text: 'Scan one code', link: '/scanning/scan-one-code' },
          { text: 'A ready-made screen', link: '/scanning/templates' },
          { text: 'Colours and texts', link: '/scanning/theming' },
          { text: 'Your own interface', link: '/scanning/custom-ui' },
          { text: 'The controller', link: '/scanning/controller' },
        ],
      },
      {
        text: 'Images',
        items: [
          { text: 'Read an image', link: '/reading/images' },
          { text: 'Reader options', link: '/reading/options' },
        ],
      },
      {
        text: 'Creating',
        items: [
          { text: 'Barcodes as widgets', link: '/creating/barcode-view' },
          { text: 'Styles and logos', link: '/creating/styles' },
          { text: 'PNG, SVG and images', link: '/creating/export' },
          { text: 'Label sheets', link: '/creating/label-sheets' },
          { text: 'Many codes', link: '/creating/batches' },
        ],
      },
      {
        text: 'Content',
        items: [
          { text: 'What is in a code', link: '/content/overview' },
          { text: 'Payments', link: '/content/payments' },
          { text: 'Building content', link: '/content/building' },
        ],
      },
      {
        text: 'More',
        items: [
          { text: 'Accuracy and speed', link: '/more/accuracy-and-speed' },
          { text: 'Upgrading from 3.x', link: '/more/upgrading-from-3x' },
          { text: 'Coming from mobile_scanner', link: '/more/from-mobile-scanner' },
        ],
      },
    ],

    outline: { level: [2, 3], label: 'On this page' },
    docFooter: { prev: 'Previous', next: 'Next' },
    socialLinks: [{ icon: 'github', link: repo }],
    search: { provider: 'local' },
    editLink: {
      pattern: `${repo}/edit/${branch}/website/:path`,
      text: 'Edit this page on GitHub',
    },
    footer: {
      message: 'MIT licence · zxing-cpp inside',
      copyright: `<a href="${repo}">GitHub</a> · <a href="https://pub.dev/packages/flutter_zxing">pub.dev</a>`,
    },
  },
})
