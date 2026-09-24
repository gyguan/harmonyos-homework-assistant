import {
  completeVoiceMaterialBatch, createVoiceMaterialAssignment, createVoiceMaterialBatch,
  fetchAssignmentResource, fetchVoiceMaterialAsset, getVoiceFolderDetail, getVoiceTaskDetail, listStudents,
  logout, registerVoiceMaterialPackage, searchVoiceFolders, searchVoiceTasks,
  uploadVoiceMaterialFile
} from './api.js?v=20260924-1';
import { SUBJECTS, parseVoiceMaterialPackages, uploadOrder, validatePackage } from './voice-material.js?v=20260924-1';
import {
  folderStatusClass, folderStatusLabel, renderFolderDetailContent, renderFolderRows,
  renderTaskDetailContent, renderTaskRows, taskStatusClass, taskStatusLabel
} from './voice-management-view.js?v=20260924-1';

const el = id => document.getElementById(id);
const state = {
  initialized: false, students: [], activeTab: 'tasks',
  tasks: { items: [], page: 0, size: 20, totalPages: 0, totalElements: 0 },
  folders: { items: [], page: 0, size: 20, totalPages: 0, totalElements: 0 },
  create: { items: [], page: 0, size: 10, totalPages: 0, totalElements: 0, selected: null, requestId: '' },
  taskDetail: null, folderDetail: null,
  importPackages: [], importIgnoredCount: 0, importing: false, importResults: [], importResultFilter: 'ALL'
};

const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const subjectLabel = code => SUBJECTS.find(x => x.code === code)?.label || '其他';
const pad = n => String(n).padStart(2, '0');
function formatDateTime(ms) {
  const n = Number(ms || 0); if (!n) return '—'; const d = new Date(n); if (Number.isNaN(d.getTime())) return '—';
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
function uuid() { return globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`; }

function studentOptions() {
  if (!state.students.length) return '<option value="">当前家庭还没有学生</option>';
  return state.students.map(s => `<option value="${esc(s.id)}">${esc(s.name)} · ${esc(s.grade)} ${esc(s.semester)}</option>`).join('');
}
function populateStudents() {
  for (const id of ['task-student','folder-student','create-student','import-student']) el(id).innerHTML = studentOptions();
}

function renderPager(target, page, totalPages) {
  if (totalPages <= 1) { target.innerHTML = ''; return; }
  const out = [`<button data-page="${page-1}" ${page<=0?'disabled':''}>上一页</button>`];
  const start=Math.max(0,page-2), end=Math.min(totalPages-1,page+2);
  if(start>0){out.push('<button data-page="0">1</button>');if(start>1)out.push('<span>…</span>');}
  for(let i=start;i<=end;i++)out.push(`<button data-page="${i}" class="${i===page?'active':''}">${i+1}</button>`);
  if(end<totalPages-1){if(end<totalPages-2)out.push('<span>…</span>');out.push(`<button data-page="${totalPages-1}">${totalPages}</button>`);}
  out.push(`<button data-page="${page+1}" ${page>=totalPages-1?'disabled':''}>下一页</button>`);
  target.innerHTML=out.join('');
}

function taskFilters() {
  return { studentId:el('task-student').value,status:el('task-status').value,subjectCode:el('task-subject').value,
    keyword:el('task-keyword').value.trim(),createdFrom:el('task-created-from').value,createdTo:el('task-created-to').value,
    page:state.tasks.page,size:state.tasks.size,sort:'createdAt,desc' };
}
async function loadTasks() {
  if(!el('task-student').value){state.tasks.items=[];state.tasks.totalElements=0;state.tasks.totalPages=0;renderTasks();return;}
  el('task-result-summary').textContent='正在查询…';
  el('task-table-body').innerHTML='<tr><td colspan="8" class="loading-cell">正在加载查询结果…</td></tr>';
  try {
    const r=await searchVoiceTasks(taskFilters()); Object.assign(state.tasks,{items:r.items||[],page:Number(r.page||0),totalElements:Number(r.totalElements||0),totalPages:Number(r.totalPages||0)}); renderTasks();
  } catch(e){el('task-result-summary').textContent='查询失败';el('task-table-body').innerHTML=`<tr><td colspan="8" class="error-cell">${esc(e.message)}</td></tr>`;}
}
function renderTasks() {
  el('task-result-summary').textContent=`共 ${state.tasks.totalElements} 条`; el('task-empty').hidden=state.tasks.items.length>0;
  el('task-table-body').innerHTML=renderTaskRows(state.tasks.items,{esc,subjectLabel,formatDateTime});
  renderPager(el('task-pagination'),state.tasks.page,state.tasks.totalPages);
}

function folderFilters(prefix='folder') {
  const isCreate=prefix==='create';
  return { studentId:el(`${prefix}-student`).value,status:isCreate?'READY':el('folder-status').value,
    subjectCode:el(`${prefix}-subject`).value,keyword:el(`${prefix}-keyword`).value.trim(),
    usage:el(`${prefix}-usage`).value,importedFrom:isCreate?'':el('folder-imported-from').value,
    importedTo:isCreate?'':el('folder-imported-to').value,page:isCreate?state.create.page:state.folders.page,
    size:isCreate?state.create.size:state.folders.size,sort:'importedAt,desc' };
}
async function loadFolders() {
  if(!el('folder-student').value){state.folders.items=[];state.folders.totalElements=0;state.folders.totalPages=0;renderFolders();return;}
  el('folder-result-summary').textContent='正在查询…';el('folder-table-body').innerHTML='<tr><td colspan="9" class="loading-cell">正在加载查询结果…</td></tr>';
  try { const r=await searchVoiceFolders(folderFilters());Object.assign(state.folders,{items:r.items||[],page:Number(r.page||0),totalElements:Number(r.totalElements||0),totalPages:Number(r.totalPages||0)});renderFolders();}
  catch(e){el('folder-result-summary').textContent='查询失败';el('folder-table-body').innerHTML=`<tr><td colspan="9" class="error-cell">${esc(e.message)}</td></tr>`;}
}
function renderFolders() {
  el('folder-result-summary').textContent=`共 ${state.folders.totalElements} 条`;el('folder-empty').hidden=state.folders.items.length>0;
  el('folder-table-body').innerHTML=renderFolderRows(state.folders.items,{esc,subjectLabel,formatDateTime});
  renderPager(el('folder-pagination'),state.folders.page,state.folders.totalPages);
}

function switchTab(tab) {
  state.activeTab=tab;const tasks=tab==='tasks';el('task-view').hidden=!tasks;el('folder-view').hidden=tasks;
  el('tab-tasks').classList.toggle('active',tasks);el('tab-folders').classList.toggle('active',!tasks);
  el('tab-tasks').setAttribute('aria-selected',String(tasks));el('tab-folders').setAttribute('aria-selected',String(!tasks));
  if(tasks) void loadTasks(); else void loadFolders();
}

async function openTaskDetail(id) {
  el('task-detail-drawer').hidden=false;el('task-detail-subtitle').textContent='正在加载…';el('task-detail-content').innerHTML='<div class="drawer-loading">正在加载任务详情…</div>';
  try{state.taskDetail=await getVoiceTaskDetail(id);renderTaskDetail();}catch(e){el('task-detail-content').innerHTML=`<p class="error-text">${esc(e.message)}</p>`;}
}
function renderTaskDetail(){
  const d=state.taskDetail,x=d.item;el('task-detail-subtitle').textContent=x.taskName;
  el('task-detail-content').innerHTML=renderTaskDetailContent(d,{esc,subjectLabel,formatDateTime});
  el('task-detail-footer').innerHTML='<div></div><button class="secondary-button" data-close-task-detail>关闭</button>';
}
function closeTaskDetail(){el('task-detail-drawer').hidden=true;state.taskDetail=null;}

async function openFolderDetail(id){
  el('folder-detail-drawer').hidden=false;el('folder-detail-subtitle').textContent='正在加载…';el('folder-detail-content').innerHTML='<div class="drawer-loading">正在加载文件夹详情…</div>';
  try{state.folderDetail=await getVoiceFolderDetail(id);renderFolderDetail();}catch(e){el('folder-detail-content').innerHTML=`<p class="error-text">${esc(e.message)}</p>`;}
}
function renderFolderDetail(){
  const d=state.folderDetail,x=d.item;el('folder-detail-subtitle').textContent=x.directoryName;
  el('folder-detail-content').innerHTML=renderFolderDetailContent(d,{esc,subjectLabel,formatDateTime});
  el('folder-detail-footer').innerHTML=`<div></div><div class="footer-actions"><button class="secondary-button" data-close-folder-detail>关闭</button>${x.folderStatus==='READY'?'<button id="create-from-folder-detail" class="primary-button">创建语音任务</button>':''}</div>`;
}
function closeFolderDetail(){el('folder-detail-drawer').hidden=true;state.folderDetail=null;}

async function loadCreateFolders(){
  if(!el('create-student').value){state.create.items=[];state.create.totalElements=0;state.create.totalPages=0;renderCreateFolders();return;}
  el('create-folder-body').innerHTML='<tr><td colspan="6" class="loading-cell">正在加载可用文件夹…</td></tr>';
  try{const r=await searchVoiceFolders(folderFilters('create'));Object.assign(state.create,{items:r.items||[],page:Number(r.page||0),totalElements:Number(r.totalElements||0),totalPages:Number(r.totalPages||0)});renderCreateFolders();}
  catch(e){el('create-folder-body').innerHTML=`<tr><td colspan="6" class="error-cell">${esc(e.message)}</td></tr>`;}
}
function renderCreateFolders(){
  el('create-folder-summary').textContent=`共 ${state.create.totalElements} 个可用文件夹`;el('create-folder-empty').hidden=state.create.items.length>0;
  el('create-folder-body').innerHTML=state.create.items.map(x=>`<tr class="selectable-row" data-select-folder="${esc(x.packageId)}"><td><input type="radio" name="create-folder" value="${esc(x.packageId)}" ${state.create.selected?.packageId===x.packageId?'checked':''}></td><td class="primary-cell">${esc(x.directoryName)}</td><td>${esc(subjectLabel(x.subjectCode))}</td><td>${x.audioCount} 音频 · ${x.imageCount} 图片</td><td>${x.usageCount===0?'从未使用':`已使用 ${x.usageCount} 次`}${x.activeTaskCount>0?' · 当前使用中':''}</td><td>${esc(formatDateTime(x.lastUsedAtEpochMs))}</td></tr>`).join('');
  renderPager(el('create-folder-pagination'),state.create.page,state.create.totalPages);el('create-next').disabled=!state.create.selected;
}
function openCreate(preselected=null){
  state.create.selected=preselected;state.create.page=0;state.create.requestId='';el('create-drawer').hidden=false;
  el('create-folder-stage').hidden=!!preselected;el('create-settings-stage').hidden=!preselected;el('create-back').hidden=!preselected;el('create-next').hidden=!!preselected;el('create-submit').hidden=!preselected;
  el('create-step-caption').textContent=preselected?'2 设置任务':'1 选择语音文件夹';el('create-message').hidden=true;
  const student=preselected?.studentId||el(state.activeTab==='tasks'?'task-student':'folder-student').value;el('create-student').value=student;
  if(preselected)prepareCreateSettings();else void loadCreateFolders();
}
function prepareCreateSettings(){
  const x=state.create.selected;if(!x)return;state.create.requestId=uuid();el('create-folder-stage').hidden=true;el('create-settings-stage').hidden=false;el('create-step-caption').textContent='2 设置任务';
  el('create-selected-folder').innerHTML=`<strong>${esc(x.directoryName)}</strong><span>${esc(subjectLabel(x.subjectCode))} · ${x.audioCount} 音频 · ${x.imageCount} 图片 · 已使用 ${x.usageCount} 次</span>`;
  el('create-title').value=`${subjectLabel(x.subjectCode)} · 语音作业`;el('create-minutes').value=x.expectedMinutes;el('create-due-at').value='';el('create-back').hidden=false;el('create-next').hidden=true;el('create-submit').hidden=false;
}
function closeCreate(){el('create-drawer').hidden=true;state.create.selected=null;}
async function submitCreate(){
  const x=state.create.selected;if(!x)return;const minutes=Number(el('create-minutes').value);const title=el('create-title').value.trim();
  if(!title||!Number.isInteger(minutes)||minutes<1||minutes>240){el('create-message').hidden=false;el('create-message').textContent='请填写任务名称，并将预计用时设置为 1～240 分钟。';return;}
  const due=el('create-due-at').value;const button=el('create-submit');button.disabled=true;button.textContent='创建中…';el('create-message').hidden=true;
  try{await createVoiceMaterialAssignment(x.packageId,{studentId:x.studentId,expectedMinutes:minutes,dueAtEpochMs:due?new Date(due).getTime():0,dueText:'',title,requestId:state.create.requestId});closeCreate();closeFolderDetail();switchTab('tasks');state.tasks.page=0;await loadTasks();void loadFolders();}
  catch(e){el('create-message').hidden=false;el('create-message').textContent=e.message||'创建失败';}
  finally{button.disabled=false;button.textContent='创建任务';}
}

function openImport(){resetImport();el('import-student').value=el(state.activeTab==='tasks'?'task-student':'folder-student').value;el('import-drawer').hidden=false;}
function resetImport(){state.importPackages=[];state.importIgnoredCount=0;state.importResults=[];state.importResultFilter='ALL';state.importing=false;el('folder-input').value='';el('import-folder-search').value='';el('import-select-stage').hidden=false;el('import-progress-stage').hidden=true;el('import-result-stage').hidden=true;el('start-import').hidden=false;el('import-cancel').hidden=false;el('import-another').hidden=true;el('import-finish').hidden=true;renderImport();}
function closeImport(){if(!state.importing)el('import-drawer').hidden=true;}
function importMinutes(){const n=Number(el('import-minutes').value);return Number.isInteger(n)&&n>=1&&n<=240?n:-1;}
function mergeFiles(fileList){const m=importMinutes();if(m<0){el('import-preview-summary').textContent='默认预计用时请输入 1～240 分钟。';return;}const parsed=parseVoiceMaterialPackages(Array.from(fileList||[]),el('import-subject').value,m);const map=new Map(state.importPackages.map(x=>[x.key,x]));for(const x of parsed.packages){const cur=map.get(x.key);if(!cur){map.set(x.key,x);continue;}const known=new Set(cur.files.map(f=>`${f.resourceType}|${f.relativeName}`));for(const f of x.files){const k=`${f.resourceType}|${f.relativeName}`;if(!known.has(k))cur.files.push(f);}}state.importPackages=[...map.values()].sort((a,b)=>a.directoryName.localeCompare(b.directoryName,'zh-CN'));state.importIgnoredCount+=parsed.ignoredCount;renderImport();}
function renderImport(){const q=el('import-folder-search').value.trim().toLowerCase();const rows=state.importPackages.map((item,index)=>({item,index})).filter(x=>!q||x.item.directoryName.toLowerCase().includes(q));const valid=state.importPackages.filter(x=>validatePackage(x).valid).length;const selected=state.importPackages.filter(x=>x.selected&&validatePackage(x).valid).length;el('import-preview-summary').textContent=state.importPackages.length?`已识别 ${state.importPackages.length} 个目录，${valid} 个可以导入${state.importIgnoredCount?`，忽略 ${state.importIgnoredCount} 个不支持文件`:''}。`:'尚未选择文件夹';el('import-selected-summary').textContent=`已选择 ${selected} 个目录`;el('start-import').disabled=!el('import-student').value||selected===0||state.importing;el('import-empty').hidden=state.importPackages.length>0;el('select-all-import').checked=state.importPackages.length>0&&state.importPackages.filter(x=>validatePackage(x).valid).every(x=>x.selected);el('import-table-body').innerHTML=rows.map(({item,index})=>{const v=validatePackage(item);return `<tr data-import-index="${index}" class="${v.valid?'':'invalid-row'}"><td><input class="import-select" type="checkbox" ${item.selected&&v.valid?'checked':''} ${v.valid?'':'disabled'}></td><td class="primary-cell">${esc(item.directoryName)}</td><td><select class="compact-select import-subject">${SUBJECTS.map(s=>`<option value="${s.code}" ${s.code===item.subjectCode?'selected':''}>${esc(s.label)}</option>`).join('')}</select></td><td><div class="minutes-cell"><input class="compact-input import-minutes" type="number" min="1" max="240" value="${item.expectedMinutes}"><span>分钟</span></div></td><td>${v.audioCount} 音频 · ${v.imageCount} 图片</td><td><span class="validation-text ${v.valid?'ok':'bad'}">${esc(v.message)}</span></td><td><button class="link-button danger-link remove-import">移除</button></td></tr>`;}).join('');}
async function collectDirectory(entry,files,parent=''){const reader=entry.createReader(),entries=[];while(true){const chunk=await new Promise(r=>reader.readEntries(r,()=>r([])));if(!chunk.length)break;entries.push(...chunk);}for(const child of entries){const path=parent?`${parent}/${child.name}`:child.name;if(child.isDirectory)await collectDirectory(child,files,path);else await new Promise(r=>child.file(file=>{try{Object.defineProperty(file,'relativePath',{value:path});}catch{}files.push(file);r();},r));}}
function importProgress(done,total,msg){const p=total?Math.round(done*100/total):0;el('import-progress-text').textContent=msg;el('import-progress-percent').textContent=`${p}%`;el('import-progress-bar').style.width=`${p}%`;}
async function uploadImport(){const selected=state.importPackages.filter(x=>x.selected&&validatePackage(x).valid);if(!selected.length||state.importing)return;state.importing=true;el('import-select-stage').hidden=true;el('import-progress-stage').hidden=false;el('start-import').disabled=true;const regFailures=[];try{const batch=await createVoiceMaterialBatch(el('import-student').value);let done=0;for(const item of selected){importProgress(done,selected.length,`正在导入：${item.directoryName}`);let remote=null;try{remote=await registerVoiceMaterialPackage(batch.id,item);}catch(e){regFailures.push({directoryName:item.directoryName,subjectCode:item.subjectCode,audioCount:item.files.filter(f=>f.resourceType==='AUDIO').length,imageCount:item.files.filter(f=>f.resourceType==='IMAGE').length,resultStatus:'FAILED',errorMessage:e.message||'目录注册失败'});}if(remote){for(const f of uploadOrder(item.files)){try{await uploadVoiceMaterialFile(remote.id,f,f.sortOrder);}catch(e){console.error('file upload failed',item.directoryName,f.relativeName,e);}}}done++;importProgress(done,selected.length,`已处理 ${done} / ${selected.length} 个目录`);}const completed=await completeVoiceMaterialBatch(batch.id);state.importResults=(completed.packages||[]).map(x=>({...x,resultStatus:x.status==='READY'||x.status==='CONSUMED'?'SUCCESS':'FAILED'})).concat(regFailures);showImportResults();}catch(e){state.importResults=[{directoryName:'本次导入',subjectCode:'',audioCount:0,imageCount:0,resultStatus:'FAILED',errorMessage:e.message||'导入失败'}];showImportResults();}finally{state.importing=false;}}
function showImportResults(){el('import-progress-stage').hidden=true;el('import-result-stage').hidden=false;el('start-import').hidden=true;el('import-cancel').hidden=true;el('import-another').hidden=false;el('import-finish').hidden=false;el('import-selected-summary').textContent='';renderImportResults();}
function renderImportResults(){const ok=state.importResults.filter(x=>x.resultStatus==='SUCCESS').length;el('import-result-summary').textContent=`本次导入 ${state.importResults.length} 个目录 · 成功 ${ok} · 失败 ${state.importResults.length-ok}`;for(const b of el('import-result-filter').querySelectorAll('button'))b.classList.toggle('active',b.dataset.resultFilter===state.importResultFilter);const rows=state.importResults.filter(x=>state.importResultFilter==='ALL'||x.resultStatus===state.importResultFilter);el('import-result-body').innerHTML=rows.map(x=>{const success=x.resultStatus==='SUCCESS';return `<tr><td class="primary-cell">${esc(x.directoryName)}</td><td>${esc(x.subjectCode?subjectLabel(x.subjectCode):'—')}</td><td>${Number(x.audioCount||0)} 音频 · ${Number(x.imageCount||0)} 图片</td><td><span class="status-badge ${success?'success':'danger'}">${success?'导入成功':'导入失败'}</span></td><td class="${success?'':'error-text'}">${esc(success?'可用于创建语音任务':x.errorMessage||'导入失败')}</td></tr>`;}).join('');}

async function openAsset(assetId,resourceId,name,type){el('asset-viewer').hidden=false;const box=el('asset-viewer-content');box.innerHTML='<p class="muted">正在加载素材…</p>';try{const blob=assetId?await fetchVoiceMaterialAsset(assetId):await fetchAssignmentResource(resourceId),url=URL.createObjectURL(blob);box.innerHTML=`<h3 class="asset-viewer-title">${esc(name)}</h3>`;const node=type==='AUDIO'?document.createElement('audio'):document.createElement('img');node.controls=type==='AUDIO';node.autoplay=type==='AUDIO';node.src=url;if(type!=='AUDIO')node.alt=name;box.append(node);box.dataset.objectUrl=url;}catch(e){box.innerHTML=`<p class="error-text">${esc(e.message)}</p>`;}}
function closeAsset(){const box=el('asset-viewer-content'),url=box.dataset.objectUrl;if(url)URL.revokeObjectURL(url);box.innerHTML='';box.dataset.objectUrl='';el('asset-viewer').hidden=true;}

el('tab-tasks').onclick=()=>switchTab('tasks');el('tab-folders').onclick=()=>switchTab('folders');
el('task-search-form').onsubmit=e=>{e.preventDefault();state.tasks.page=0;void loadTasks();};el('task-reset').onclick=()=>{el('task-status').value='';el('task-subject').value='';el('task-keyword').value='';el('task-created-from').value='';el('task-created-to').value='';state.tasks.page=0;void loadTasks();};el('task-student').onchange=()=>{state.tasks.page=0;void loadTasks();};el('task-refresh').onclick=()=>void loadTasks();el('task-page-size').onchange=()=>{state.tasks.size=Number(el('task-page-size').value);state.tasks.page=0;void loadTasks();};el('task-pagination').onclick=e=>{const b=e.target.closest('[data-page]');if(!b||b.disabled)return;state.tasks.page=Number(b.dataset.page);void loadTasks();};
el('folder-search-form').onsubmit=e=>{e.preventDefault();state.folders.page=0;void loadFolders();};el('folder-reset').onclick=()=>{el('folder-status').value='';el('folder-subject').value='';el('folder-usage').value='ALL';el('folder-keyword').value='';el('folder-imported-from').value='';el('folder-imported-to').value='';state.folders.page=0;void loadFolders();};el('folder-student').onchange=()=>{state.folders.page=0;void loadFolders();};el('folder-refresh').onclick=()=>void loadFolders();el('folder-page-size').onchange=()=>{state.folders.size=Number(el('folder-page-size').value);state.folders.page=0;void loadFolders();};el('folder-pagination').onclick=e=>{const b=e.target.closest('[data-page]');if(!b||b.disabled)return;state.folders.page=Number(b.dataset.page);void loadFolders();};

el('task-table-body').onclick=e=>{const id=e.target.closest('[data-open-task]')?.dataset.openTask||e.target.closest('[data-task-id]')?.dataset.taskId;if(id)void openTaskDetail(id);};
el('folder-table-body').onclick=e=>{const id=e.target.closest('[data-open-folder]')?.dataset.openFolder||e.target.closest('[data-folder-id]')?.dataset.folderId;if(id)void openFolderDetail(id);};
el('close-task-detail').onclick=closeTaskDetail;el('task-detail-drawer').onclick=e=>{if(e.target.hasAttribute('data-close-task-detail'))closeTaskDetail();const p=e.target.closest('[data-preview-asset]');if(p)void openAsset(p.dataset.previewAsset,p.dataset.previewResource,p.dataset.previewName,p.dataset.previewType);const f=e.target.closest('[data-jump-folder]');if(f){closeTaskDetail();switchTab('folders');void openFolderDetail(f.dataset.jumpFolder);}};
el('close-folder-detail').onclick=closeFolderDetail;el('folder-detail-drawer').onclick=e=>{if(e.target.hasAttribute('data-close-folder-detail'))closeFolderDetail();const p=e.target.closest('[data-preview-asset]');if(p)void openAsset(p.dataset.previewAsset,p.dataset.previewResource,p.dataset.previewName,p.dataset.previewType);const t=e.target.closest('[data-jump-task]');if(t){closeFolderDetail();switchTab('tasks');void openTaskDetail(t.dataset.jumpTask);}if(e.target.id==='create-from-folder-detail')openCreate(state.folderDetail.item);};

el('open-create-task').onclick=()=>openCreate();el('close-create').onclick=closeCreate;el('create-cancel').onclick=closeCreate;el('create-folder-search-form').onsubmit=e=>{e.preventDefault();state.create.page=0;void loadCreateFolders();};el('create-folder-reset').onclick=()=>{el('create-subject').value='';el('create-usage').value='ALL';el('create-keyword').value='';state.create.page=0;state.create.selected=null;void loadCreateFolders();};el('create-student').onchange=()=>{state.create.page=0;state.create.selected=null;void loadCreateFolders();};el('create-folder-pagination').onclick=e=>{const b=e.target.closest('[data-page]');if(!b||b.disabled)return;state.create.page=Number(b.dataset.page);void loadCreateFolders();};el('create-folder-body').onclick=e=>{const row=e.target.closest('[data-select-folder]');if(!row)return;const x=state.create.items.find(i=>i.packageId===row.dataset.selectFolder);if(x){state.create.selected=x;renderCreateFolders();}};el('create-next').onclick=()=>prepareCreateSettings();el('create-back').onclick=()=>{el('create-settings-stage').hidden=true;el('create-folder-stage').hidden=false;el('create-step-caption').textContent='1 选择语音文件夹';el('create-back').hidden=true;el('create-submit').hidden=true;el('create-next').hidden=false;};el('create-submit').onclick=()=>void submitCreate();

el('open-import').onclick=openImport;el('close-import').onclick=closeImport;el('import-cancel').onclick=closeImport;el('folder-picker').onclick=()=>el('folder-input').click();el('folder-input').onchange=()=>{mergeFiles(el('folder-input').files);el('folder-input').value='';};el('folder-picker').ondragover=e=>{e.preventDefault();el('folder-picker').classList.add('drag-over');};el('folder-picker').ondragleave=()=>el('folder-picker').classList.remove('drag-over');el('folder-picker').ondrop=async e=>{e.preventDefault();el('folder-picker').classList.remove('drag-over');const files=[];for(const item of Array.from(e.dataTransfer?.items||[])){if(item.kind!=='file')continue;const entry=item.webkitGetAsEntry?.()||item.getAsEntry?.();if(entry?.isDirectory)await collectDirectory(entry,files,entry.name);else{const file=item.getAsFile();if(file)files.push(file);}}mergeFiles(files);};el('import-folder-search').oninput=renderImport;el('apply-import-defaults').onclick=()=>{const m=importMinutes();if(m<0)return;for(const x of state.importPackages){x.subjectCode=el('import-subject').value;x.expectedMinutes=m;}renderImport();};el('select-all-import').onchange=()=>{for(const x of state.importPackages)if(validatePackage(x).valid)x.selected=el('select-all-import').checked;renderImport();};el('import-table-body').onchange=e=>{const row=e.target.closest('[data-import-index]');if(!row)return;const x=state.importPackages[Number(row.dataset.importIndex)];if(e.target.classList.contains('import-select'))x.selected=e.target.checked;if(e.target.classList.contains('import-subject'))x.subjectCode=e.target.value;if(e.target.classList.contains('import-minutes'))x.expectedMinutes=Number(e.target.value);renderImport();};el('import-table-body').onclick=e=>{if(!e.target.classList.contains('remove-import'))return;const row=e.target.closest('[data-import-index]');state.importPackages.splice(Number(row.dataset.importIndex),1);renderImport();};el('start-import').onclick=()=>void uploadImport();el('import-another').onclick=resetImport;el('import-finish').onclick=()=>{el('import-drawer').hidden=true;switchTab('folders');state.folders.page=0;void loadFolders();};el('import-result-filter').onclick=e=>{const b=e.target.closest('[data-result-filter]');if(!b)return;state.importResultFilter=b.dataset.resultFilter;renderImportResults();};

el('logout-button').onclick=async()=>{await logout();window.location.reload();};el('close-asset-viewer').onclick=closeAsset;el('asset-viewer').onclick=e=>{if(e.target.hasAttribute('data-close-viewer'))closeAsset();};

async function startAdmin(){
  if(state.initialized)return;state.initialized=true;
  try{state.students=await listStudents();populateStudents();await Promise.all([loadTasks(),loadFolders()]);}
  catch(e){state.initialized=false;el('task-result-summary').textContent='学生信息加载失败';el('task-table-body').innerHTML=`<tr><td colspan="8" class="error-cell">${esc(e.message||'学生信息加载失败')}</td></tr>`;}
}
window.addEventListener('xiaoban-admin-authenticated',()=>void startAdmin());
if(window.__xiaobanAdminAuth)void startAdmin();
