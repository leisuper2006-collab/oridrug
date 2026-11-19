/* The original Django workbench runs in this isolated project worker. */
'use strict';
const base = new URL('./', self.location.href).href;
let loading;
let dispatch;
let interpreter;
let installedCase;
let pending = Promise.resolve();
let chemistry;
async function loadChemistry() {
  if (!chemistry) chemistry = (async () => {
    importScripts(base + 'RDKit_minimal.js', base + 'chemistry.js');
    const library = await initRDKitModule({ locateFile: name => base + name });
    self.oriDrugChemistry = defineChemistry(library);
  })().catch(error => { chemistry = undefined; throw error; });
  return chemistry;
}

async function load(id) {
  if (dispatch) return;
  if (!loading) {
    loading = (async () => {
      self.postMessage({ id, type: 'progress', stage: '正在打开原版研究工作台' });
      importScripts(base + 'pyodide.js');
      const source = fetch(base + 'workbench.zip').then(async response => {
        if (!response.ok) throw new Error('研究程序下载失败，请重新打开项目。');
        return response.arrayBuffer();
      });
      const py = await loadPyodide({ indexURL: base });
      interpreter = py;
      await py.loadPackage(['sqlite3', 'ssl']);
      py.FS.mkdirTree('/workbench');
      py.unpackArchive(await source, 'zip', { extractDir: '/workbench' });
      py.runPython("import sys; sys.path.insert(0,'/workbench')");
      dispatch = py.runPython("from browser_runtime.app import dispatch; dispatch");
    })().catch(error => { loading = undefined; throw error; });
  }
  return loading;
}
async function handle(data) {
  try {
    await load(data.id);
    if (data.op === 'ensure' && data.project?.example === true && !data.project.disablePublicCase && !data.project.portableImport) {
      if (!installedCase) installedCase = (async () => {
        const response = await fetch(base + 'public-case.zip');
        if (!response.ok) throw new Error('伊马替尼公开案例暂时未完成下载，请重新打开。');
        interpreter.FS.mkdirTree('/workbench/public-case');
        interpreter.unpackArchive(await response.arrayBuffer(), 'zip', {extractDir:'/workbench/public-case'});
      })().catch(error => { installedCase = undefined; throw error; });
      await installedCase;
    }
    let result = JSON.parse(dispatch(JSON.stringify(data)));
    if (result.status === 428 && JSON.parse(result.body).browserDependency === 'chemistry') {
      self.postMessage({ id: data.id, type: 'progress', stage: '正在载入分子结构工具' });
      await loadChemistry();
      result = JSON.parse(dispatch(JSON.stringify(data)));
    }
    self.postMessage({ id: data.id, ok: true, ...result });
  } catch (error) {
    console.error('OriDrug browser runtime', error);
    self.postMessage({ id: data.id, ok: false, error: error.message || '工作台暂时未打开。' });
  }
}
self.onmessage = event => { pending = pending.then(() => handle(event.data)); };

