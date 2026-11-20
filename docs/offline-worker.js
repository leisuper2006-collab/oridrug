'use strict'
const scope = new URL(self.registration.scope)
const prefix = 'oridrug-shell-' + scope.pathname
const cacheName = prefix + 'fullweb-v3-a1db9f447c34c799fc'
const scienceCache = 'oridrug-science-v1-' + scope.pathname
const entry = new URL('index.html', scope).href
const shell = ["assets/ResearchPanels-6AoNQ9wA.js","assets/ResearchPanels-CLfAoo0B.css","assets/SkillStudio-BbIxHGEq.js","assets/SkillStudio-Kdsms9Sc.css","assets/api-WLDhd0y5.js","assets/jsx-runtime-Wy9s6hX0.js","assets/preload-helper-CgPOhYhF.js","assets/site-ObI055zE.js","assets/site-qLwzl0y_.css","assets/stage-stories-DAC2LuqJ.js","index.html","workflow/lotus-approved-01.png"].map(path => new URL(path, scope).href)
const hashes = new Map(Object.entries({"original-runtime/RDKit_minimal.js":"2160b93ad2f82aeeba90f5551d9dc8bc21fe9d20e1e7ae7428840c889c073733","original-runtime/RDKit_minimal.wasm":"caf7eb9f09733cfd3e1b038eb5e05f9eeafc05f58e5780561c583aba7e5d8fd4","original-runtime/chemistry.js":"9b3dc79962cd31ae1b3539f7027e7ef5addb82ad415527ab23af36295890ed90","original-runtime/openssl-1.1.1w.zip":"20b92cd9b9adb1a739af9f93772b60c084203aacf63ae1b2353951bd80c97f08","original-runtime/public-case.zip":"a4dd14fe62bc9b762c7ca033fecf932f8e7b2e6f7fca2b26b6932247d9e0d1d8","original-runtime/pyodide-lock.json":"9c45b916001a750f4102fc287494f3eab215909c7535c626a20db80fd6333e2c","original-runtime/pyodide.asm.js":"6b4c90de5b7172873f04f21884d0e9d2274e305fe32116558fe3e4fbe3618d51","original-runtime/pyodide.asm.wasm":"a50dd1843f805a0b7c45b61037ee0d7b26dfe85efe0e18ef95a34ad24e401f5f","original-runtime/pyodide.js":"b4cb23a53aba19c221659b9fb40a2f18281d685691dc06647fb0afd0681baf98","original-runtime/python_stdlib.zip":"16611534726e5d8ac2bd8f926410b2dcb8d6f49aa24913463533b457a2115c16","original-runtime/sqlite3-1.0.0-cp312-cp312-pyodide_2024_0_wasm32.whl":"43061928762b03482676a1e11dcef99a003148e59fe914b6a3e41180c382cfc3","original-runtime/ssl-1.0.0-cp312-cp312-pyodide_2024_0_wasm32.whl":"1af0b011a3043331a8a2a358832dcee736deff73a55ad0393222ea533942094a","original-runtime/workbench.zip":"8f04292392772ec296fbf5ff0c9748ab362af5d33bda95f6c8afc1d4c982b9d8","original-runtime/worker.js":"30cd0fc8e07d1d10a4ee88a3f7b7d7039f065f4ec8bfec4044f7023b1782f11d","science/RDKit_minimal.js":"2160b93ad2f82aeeba90f5551d9dc8bc21fe9d20e1e7ae7428840c889c073733","science/RDKit_minimal.wasm":"caf7eb9f09733cfd3e1b038eb5e05f9eeafc05f58e5780561c583aba7e5d8fd4","science/source.json":"ad80884e681ad91fd2fe55e2678911e6f615fb8fbdeb7ec45ccd33902c3c3828"}).map(([path, hash]) => [new URL(path, scope).href, hash]))
const core = ["original-runtime/pyodide.asm.wasm","original-runtime/workbench.zip","original-runtime/pyodide.asm.js","original-runtime/python_stdlib.zip","original-runtime/pyodide.js","original-runtime/pyodide-lock.json","original-runtime/openssl-1.1.1w.zip","original-runtime/sqlite3-1.0.0-cp312-cp312-pyodide_2024_0_wasm32.whl","original-runtime/ssl-1.0.0-cp312-cp312-pyodide_2024_0_wasm32.whl"].map(path => new URL(path, scope).href)
const workerHref = new URL('original-runtime/worker.js', scope).href
const workerCode = "/* The original Django workbench runs in this isolated project worker. */\n'use strict';\nconst base = new URL('./', self.location.href).href;\nlet loading;\nlet dispatch;\nlet interpreter;\nlet installedCase;\nlet pending = Promise.resolve();\nlet chemistry;\nasync function loadChemistry() {\n  if (!chemistry) chemistry = (async () => {\n    importScripts(base + 'RDKit_minimal.js', base + 'chemistry.js');\n    const library = await initRDKitModule({ locateFile: name => base + name });\n    self.oriDrugChemistry = defineChemistry(library);\n  })().catch(error => { chemistry = undefined; throw error; });\n  return chemistry;\n}\n\nasync function load(id) {\n  if (dispatch) return;\n  if (!loading) {\n    loading = (async () => {\n      self.postMessage({ id, type: 'progress', stage: '\u6b63\u5728\u6253\u5f00\u539f\u7248\u7814\u7a76\u5de5\u4f5c\u53f0' });\n      importScripts(base + 'pyodide.js');\n      const source = fetch(base + 'workbench.zip').then(async response => {\n        if (!response.ok) throw new Error('\u7814\u7a76\u7a0b\u5e8f\u4e0b\u8f7d\u5931\u8d25\uff0c\u8bf7\u91cd\u65b0\u6253\u5f00\u9879\u76ee\u3002');\n        return response.arrayBuffer();\n      });\n      const py = await loadPyodide({ indexURL: base });\n      interpreter = py;\n      await py.loadPackage(['sqlite3', 'ssl']);\n      py.FS.mkdirTree('/workbench');\n      py.unpackArchive(await source, 'zip', { extractDir: '/workbench' });\n      py.runPython(\"import sys; sys.path.insert(0,'/workbench')\");\n      dispatch = py.runPython(\"from browser_runtime.app import dispatch; dispatch\");\n    })().catch(error => { loading = undefined; throw error; });\n  }\n  return loading;\n}\nasync function handle(data) {\n  try {\n    await load(data.id);\n    if (data.op === 'ensure' && data.project?.example === true && !data.project.disablePublicCase && !data.project.portableImport) {\n      if (!installedCase) installedCase = (async () => {\n        const response = await fetch(base + 'public-case.zip');\n        if (!response.ok) throw new Error('\u4f0a\u9a6c\u66ff\u5c3c\u516c\u5f00\u6848\u4f8b\u6682\u65f6\u672a\u5b8c\u6210\u4e0b\u8f7d\uff0c\u8bf7\u91cd\u65b0\u6253\u5f00\u3002');\n        interpreter.FS.mkdirTree('/workbench/public-case');\n        interpreter.unpackArchive(await response.arrayBuffer(), 'zip', {extractDir:'/workbench/public-case'});\n      })().catch(error => { installedCase = undefined; throw error; });\n      await installedCase;\n    }\n    let result = JSON.parse(dispatch(JSON.stringify(data)));\n    if (result.status === 428 && JSON.parse(result.body).browserDependency === 'chemistry') {\n      self.postMessage({ id: data.id, type: 'progress', stage: '\u6b63\u5728\u8f7d\u5165\u5206\u5b50\u7ed3\u6784\u5de5\u5177' });\n      await loadChemistry();\n      result = JSON.parse(dispatch(JSON.stringify(data)));\n    }\n    self.postMessage({ id: data.id, ok: true, ...result });\n  } catch (error) {\n    console.error('OriDrug browser runtime', error);\n    self.postMessage({ id: data.id, ok: false, error: error.message || '\u5de5\u4f5c\u53f0\u6682\u65f6\u672a\u6253\u5f00\u3002' });\n  }\n}\nself.onmessage = event => { pending = pending.then(() => handle(event.data)); };\n\r\n"
const pending = new Map()
let warming

function keyFor(href) {
  const key = new URL(href)
  key.searchParams.set('oridrug-sha256', hashes.get(href))
  return key.href
}
async function matches(response, hash) {
  if (!response || !response.ok || response.redirected || response.type === 'opaque') return false
  const bytes = await response.clone().arrayBuffer()
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))
  return Array.from(digest, n => n.toString(16).padStart(2, '0')).join('') === hash
}
async function twoAtATime(items, work) {
  const queue = items[Symbol.iterator]()
  async function next() { for (const item of queue) await work(item) }
  await Promise.all([next(), next()])
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName)
    await cache.addAll(shell.map(href => new Request(href, {cache: href === entry ? 'reload' : 'default'})))
    await self.skipWaiting()
  })())
})
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const old = (await caches.keys()).filter(key =>
      key.startsWith(prefix) && !key.slice(prefix.length).includes('/') && key !== cacheName)
    const science = await caches.open(scienceCache)
    const sources = await Promise.all(old.map(name => caches.open(name)))
    const retained = new Set()
    const current = new Set([...hashes.keys()].map(keyFor))
    for (const request of await science.keys()) if (!current.has(request.url)) await science.delete(request)
    await twoAtATime(hashes, async ([href, hash]) => {
      if (href === workerHref) return
      const key = keyFor(href), existing = await science.match(key)
      if (existing && await matches(existing, hash)) return
      if (existing) await science.delete(key)
      for (const [i, previous] of sources.entries()) {
        const file = await previous.match(href)
        if (!file || !await matches(file, hash)) continue
        try { await science.put(key, file) } catch { retained.add(old[i]) }
        break
      }
    })
    await Promise.all(old.filter(name => !retained.has(name)).map(name => caches.delete(name)))
    await self.clients.claim()
  })())
})

function scienceFile(href) {
  if (pending.has(href)) return pending.get(href)
  const key = keyFor(href)
  const options = {credentials: 'omit', redirect: 'error'}
  const read = (async () => {
    const cache = await caches.open(scienceCache)
    const saved = await cache.match(key)
    if (saved) return {file: saved}
    return {file: await fetch(href, options), cache}
  })()
  const stored = read.then(async ({file, cache}) => {
    if (!cache || !file.ok) return
    if (!await matches(file, hashes.get(href))) {
      file = await fetch(href, {...options, cache: 'reload'})
      if (!await matches(file, hashes.get(href))) return
    }
    await cache.put(key, file.clone())
  }).catch(() => {}).finally(() => pending.delete(href))
  const result = {read, stored}
  pending.set(href, result)
  return result
}
self.addEventListener('message', event => {
  if (event.data !== 'oridrug-warm-public-core-v1' || !event.source?.url) return
  const source = new URL(event.source.url)
  if (source.origin !== scope.origin || !source.pathname.startsWith(scope.pathname)) return
  if (!warming) warming = twoAtATime(core, href => scienceFile(href).stored).finally(() => { warming = undefined })
  event.waitUntil(warming)
})
async function navigation(request) {
  const cache = await caches.open(cacheName)
  try {
    const live = await fetch(request)
    if (live.ok) return live
  } catch {}
  return (await cache.match(entry)) || Response.error()
}
function staticAsset(event) {
  const request = event.request
  const read = (async () => {
    const cache = await caches.open(cacheName)
    const saved = await cache.match(request)
    return saved ? {file: saved} : {file: await fetch(request), cache}
  })()
  event.waitUntil(read.then(({file, cache}) => {
    if (cache && file.ok && file.type !== 'opaque' && !file.redirected) return cache.put(request, file.clone())
  }).catch(() => {}))
  event.respondWith(read.then(({file}) => file))
}
self.addEventListener('fetch', event => {
  const request = event.request, url = new URL(request.url)
  if (request.method !== 'GET' || url.origin !== scope.origin ||
      !url.pathname.startsWith(scope.pathname) || request.headers.has('range') ||
      request.headers.has('authorization')) return
  const relative = url.pathname.slice(scope.pathname.length)
  if (request.mode === 'navigate' && /^(?:(?:preview\/|device\/)?(?:index\.html)?|preview|device)$/.test(relative)) {
    event.respondWith(navigation(request))
    return
  }
  if (url.search) return
  if (url.href === workerHref) {
    event.respondWith(new Response(workerCode, {headers: {'Content-Type': 'text/javascript; charset=utf-8', 'Cache-Control': 'no-cache'}}))
    return
  }
  if (hashes.has(url.href)) {
    const asset = scienceFile(url.href)
    event.waitUntil(asset.stored)
    event.respondWith(asset.read.then(({file}) => file.clone()))
    return
  }
  if (!/^(?:assets\/|structures\/|workflow\/|licenses\/|favicon\.(?:ico|svg)$)/.test(relative)) return
  staticAsset(event)
})
