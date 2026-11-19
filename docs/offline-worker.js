const build='7028e3ec23aa'
const prefix='oridrug-shell-'+new URL(self.registration.scope).pathname
const name=prefix+build
const precache=["index.html", "workflow/lotus-approved-01.png", "workflow/ink-mountains.png", "assets/site-BS-5zTYc.js", "assets/site-Dm94CmUi.css"].map(path=>new URL(path,self.registration.scope).href)
self.addEventListener('install',event=>event.waitUntil((async()=>{
 const cache=await caches.open(name)
 await cache.addAll(precache.map(u=>new Request(u,{cache:'reload'})))
 await self.skipWaiting()
})()))
self.addEventListener('activate',event=>event.waitUntil((async()=>{
 for(const key of await caches.keys())if(key.startsWith(prefix)&&key!==name)await caches.delete(key)
 await self.clients.claim()
})()))
self.addEventListener('fetch',event=>{
 const request=event.request,base=new URL(self.registration.scope),u=new URL(request.url)
 if(request.method!=='GET'||u.origin!==base.origin||!u.pathname.startsWith(base.pathname)||request.headers.has('range'))return
 const rel=u.pathname.slice(base.pathname.length)
 if(request.mode==='navigate' && /^(?:(?:preview\/|device\/)?(?:index\.html)?|preview|device)$/.test(rel)){
  event.respondWith((async()=>{
   const cache=await caches.open(name)
   try{const r=await fetch(request);if(r.ok)return r}catch{}
   return await cache.match(new URL('index.html',base).href)||Response.error()
  })());return
 }
 if(!/^(assets|structures|science|workflow)\//.test(rel))return
 event.respondWith((async()=>{
  const cache=await caches.open(name),saved=await cache.match(request);if(saved)return saved
  const response=await fetch(request);if(response.ok)await cache.put(request,response.clone());return response
 })())
})

