/// <reference types="vite/client" />

// The package version, from pubspec.yaml (config.mts).
declare const __PACKAGE_VERSION__: string

// Code samples kept as files, so tool/check_site_snippets.dart checks them.
declare module '*.snippet?raw' {
  const text: string
  export default text
}

interface ImportMetaEnv {
  readonly VITE_DEMO_URL?: string
}
