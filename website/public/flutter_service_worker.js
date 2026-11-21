// The demo app used to live at this address, and some Flutter versions
// registered a caching service worker for it. A browser that still has one
// fetches this file when it checks for an update: it takes the old worker's
// place, empties its caches, removes itself and reloads the open pages, so
// they show the documentation (the demo is at ./demo/ now).
self.addEventListener('install', () => self.skipWaiting())

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Only Flutter's caches: other projects on khoren93.github.io share
      // this origin and its caches.
      for (const key of await caches.keys()) {
        if (key.startsWith('flutter-')) {
          await caches.delete(key)
        }
      }
      await self.registration.unregister()
      const clients = await self.clients.matchAll({ type: 'window' })
      for (const client of clients) {
        client.navigate(client.url)
      }
    })(),
  )
})
