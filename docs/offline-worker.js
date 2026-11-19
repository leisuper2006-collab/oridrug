/* Release identity includes both the Vite app and the unversioned scientific runtime. */
'use strict'
const scope = new URL(self.registration.scope)
const prefix = 'oridrug-shell-' + scope.pathname
const cacheName = prefix + 'fullweb-v2-7d4417e32cc7ecaf58'
const entry = new URL('index.html', scope).href
const shell = ["assets/WorkflowOverlays-28FdR-a0.js","assets/WorkflowOverlays-BSMdzXtk.css","assets/jsx-runtime-Wy9s6hX0.js","assets/preload-helper-CgPOhYhF.js","assets/site-Bw1WdrZl.js","assets/site-CSh8U1cU.css","index.html","workflow/lotus-approved-01.png"].map(path => new URL(path, scope).href)

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName)
    await cache.addAll(shell.map(href => new Request(href, {cache: 'reload'})))
    await self.skipWaiting()
  })())
})
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const previous = (await caches.keys()).filter(key =>
      key.startsWith(prefix) && !key.slice(prefix.length).includes('/') && key !== cacheName)
    await Promise.all(previous.map(key => caches.delete(key)))
    await self.clients.claim()
  })())
})

async function navigation(request) {
  const cache = await caches.open(cacheName)
  try {
    const live = await fetch(request)
    if (live.ok) return live
  } catch {}
  return (await cache.match(entry)) || Response.error()
}
async function staticAsset(request) {
  const cache = await caches.open(cacheName)
  const previous = await cache.match(request)
  if (previous) return previous
  const response = await fetch(request)
  if (response.ok && response.type !== 'opaque' && !response.redirected) {
    try { await cache.put(request, response.clone()) } catch {}
  }
  return response
}
self.addEventListener('fetch', event => {
  const request = event.request
  const url = new URL(request.url)
  if (request.method !== 'GET' || url.origin !== scope.origin ||
      !url.pathname.startsWith(scope.pathname) || request.headers.has('range') ||
      request.headers.has('authorization')) return
  const relative = url.pathname.slice(scope.pathname.length)
  if (request.mode === 'navigate' && /^(?:(?:preview\/|device\/)?(?:index\.html)?|preview|device)$/.test(relative)) {
    event.respondWith(navigation(request))
    return
  }
  if (url.search || !/^(?:assets\/|original-runtime\/|science\/|structures\/|workflow\/|licenses\/|showcase\/|tours\/thumb-[\w-]+\.webp$|favicon\.(?:ico|svg)$)/.test(relative)) return
  event.respondWith(staticAsset(request))
})

