import {
  completeVoiceMaterialBatch,
  createVoiceMaterialAssignment,
  createVoiceMaterialBatch,
  fetchVoiceMaterialAsset,
  getVoiceTaskDetail,
  listStudents,
  logout,
  registerVoiceMaterialPackage,
  searchVoiceTasks,
  uploadVoiceMaterialFile
} from './api.js?v=20260923-3';
import {
  SUBJECTS,
  parseVoiceMaterialPackages,
  uploadOrder,
  validatePackage
} from './voice-material.js?v=20260923-3';

const el = id => document.getElementById(id);
const state = {
  initialized: false,
  students: [],
  items: [],
  page: 0,
  size: 20,
  totalPages: 0,
  totalElements: 0,
  loading: false,
  detail: null,
  importPackages: [],
  importIgnoredCount: 0,
  importing: false,
  importResults: [],
  importResultFilter: 'ALL'
};

const studentSelect = el('student-select');
const statusFilter = el('status-filter');
const subjectFilter = el('subject-filter');
const keywordFilter = el('keyword-filter');
const createdFrom = el('created-from');
const createdTo = el('created-to');
const taskTableBody = el('task-table-body');
const taskEmpty = el('task-empty');
const resultSummary = el('result-summary');
const pageSize = el('page-size');
const pagination = el('pagination');

const detailDrawer = el('detail-drawer');
const detailSubtitle = el('detail-subtitle');
const detailContent = el('detail-content');
const detailFooter = el('detail-footer');

const importDrawer = el('import-drawer');
const importStudentSelect = el('import-student-select');
const importDefaultSubject = el('import-default-subject');
const importDefaultMinutes = el('import-default-minutes');
const folderInput = el('folder-input');
const folderPicker = el('folder-picker');
const importFolderSearch = el('import-folder-search');
const importTableBody = el('import-table-body');
const importEmpty = el('import-empty');
const importPreviewSummary = el('import-preview-summary');
const selectAllImport = el('select-all-import');
const importSelectStage = el('import-select-stage');
const importProgressStage = el('import-progress-stage');
const importProgressText = el('import-progress-text');
const importProgressPercent = el('import-progress-percent');
const importProgressBar = el('import-progress-bar');
const importResultStage = el('import-result-stage');
const importResultSummary = el('import-result-summary');
const importResultBody = el('import-result-body');
const importSelectedSummary = el('import-selected-summary');
const startImportButton = el('start-import');
const importCancelButton = el('import-cancel');
const importAnotherButton = el('import-another');
const importFinishButton = el('import-finish');

const assetViewer = el('asset-viewer');
const assetViewerContent = el('asset-viewer-content');

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
  })[char]);
}

function subjectLabel(code) {
  return SUBJECTS.find(item => item.code === code)?.label || '其他';
}

function statusInfo(status) {
  const map = {
    ACTIVE: { label: '已创建', className: 'success' },
    READY: { label: '待创建', className: 'ready' },
    USED_BEFORE: { label: '已创建过', className: 'used' },
    INVALID: { label: '导入失败', className: 'danger' },
    PROCESSING: { label: '处理中', className: 'muted' }
  };
  return map[status] || { label: status || '未知', className: 'muted' };
}

function formatDateTime(epochMs) {
  const value = Number(epochMs || 0);
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  const pad = part => String(part).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function populateStudents() {
  const options = state.students.map(student =>
    `<option value="${escapeHtml(student.id)}">${escapeHtml(student.name)} · ${escapeHtml(student.grade)} ${escapeHtml(student.semester)}</option>`
  ).join('');
  const empty = '<option value="">当前家庭还没有学生</option>';
  studentSelect.innerHTML = options || empty;
  importStudentSelect.innerHTML = options || empty;
}

function currentFilters() {
  return {
    studentId: studentSelect.value,
    status: statusFilter.value,
    subjectCode: subjectFilter.value,
    keyword: keywordFilter.value.trim(),
    createdFrom: createdFrom.value,
    createdTo: createdTo.value,
    page: state.page,
    size: state.size,
    sort: 'createdAt,desc'
  };
}

async function loadStudentsAndTasks() {
  state.students = await listStudents();
  populateStudents();
  state.page = 0;
  await loadTasks();
}

async function loadTasks() {
  if (state.loading) return;
  if (!studentSelect.value) {
    state.items = [];
    state.totalElements = 0;
    state.totalPages = 0;
    renderTaskTable();
    return;
  }
  state.loading = true;
  resultSummary.textContent = '正在查询…';
  taskTableBody.innerHTML = '<tr><td colspan="9" class="loading-cell">正在加载查询结果…</td></tr>';
  taskEmpty.hidden = true;
  try {
    const result = await searchVoiceTasks(currentFilters());
    state.items = result.items || [];
    state.totalElements = Number(result.totalElements || 0);
    state.totalPages = Number(result.totalPages || 0);
    state.page = Number(result.page || 0);
    renderTaskTable();
  } catch (error) {
    state.items = [];
    state.totalElements = 0;
    state.totalPages = 0;
    taskTableBody.innerHTML = `<tr><td colspan="9" class="error-cell">${escapeHtml(error?.message || '查询失败，请稍后重试。')}</td></tr>`;
    resultSummary.textContent = '查询失败';
    renderPagination();
  } finally {
    state.loading = false;
  }
}

function renderTaskTable() {
  resultSummary.textContent = `共 ${state.totalElements} 条`;
  taskEmpty.hidden = state.items.length > 0;
  if (state.items.length === 0) {
    taskTableBody.innerHTML = '';
    renderPagination();
    return;
  }

  taskTableBody.innerHTML = state.items.map(item => {
    const status = statusInfo(item.displayStatus);
    const material = `${item.audioCount} 音频 · ${item.imageCount} 图片`;
    return `
      <tr class="clickable-row" data-package-id="${escapeHtml(item.packageId)}" tabindex="0">
        <td class="primary-cell">${escapeHtml(item.taskName || '—')}</td>
        <td><span class="status-badge ${status.className}">${status.label}</span></td>
        <td>${escapeHtml(item.studentName || '—')}</td>
        <td>${escapeHtml(subjectLabel(item.subjectCode))}</td>
        <td class="folder-cell" title="${escapeHtml(item.directoryName)}">${escapeHtml(item.directoryName)}</td>
        <td>${escapeHtml(material)}</td>
        <td>${escapeHtml(item.expectedMinutes)} 分钟</td>
        <td>${escapeHtml(formatDateTime(item.taskCreatedAtEpochMs))}</td>
        <td><button class="link-button" type="button" data-open-detail="${escapeHtml(item.packageId)}">详情</button></td>
      </tr>`;
  }).join('');
  renderPagination();
}

function renderPagination() {
  if (state.totalPages <= 1) {
    pagination.innerHTML = '';
    return;
  }
  const buttons = [];
  buttons.push(`<button type="button" data-page="${state.page - 1}" ${state.page <= 0 ? 'disabled' : ''}>上一页</button>`);
  const start = Math.max(0, state.page - 2);
  const end = Math.min(state.totalPages - 1, state.page + 2);
  if (start > 0) {
    buttons.push('<button type="button" data-page="0">1</button>');
    if (start > 1) buttons.push('<span>…</span>');
  }
  for (let index = start; index <= end; index++) {
    buttons.push(`<button type="button" data-page="${index}" class="${index === state.page ? 'active' : ''}">${index + 1}</button>`);
  }
  if (end < state.totalPages - 1) {
    if (end < state.totalPages - 2) buttons.push('<span>…</span>');
    buttons.push(`<button type="button" data-page="${state.totalPages - 1}">${state.totalPages}</button>`);
  }
  buttons.push(`<button type="button" data-page="${state.page + 1}" ${state.page >= state.totalPages - 1 ? 'disabled' : ''}>下一页</button>`);
  pagination.innerHTML = buttons.join('');
}

async function openDetail(packageId) {
  detailDrawer.hidden = false;
  detailSubtitle.textContent = '正在加载…';
  detailContent.innerHTML = '<div class="drawer-loading">正在加载任务详情…</div>';
  detailFooter.innerHTML = '';
  try {
    const detail = await getVoiceTaskDetail(packageId);
    state.detail = detail;
    renderDetail();
  } catch (error) {
    detailSubtitle.textContent = '';
    detailContent.innerHTML = `<p class="error-text">${escapeHtml(error?.message || '详情加载失败')}</p>`;
  }
}

function renderDetail() {
  const detail = state.detail;
  if (!detail?.item) return;
  const item = detail.item;
  const status = statusInfo(item.displayStatus);
  detailSubtitle.textContent = item.directoryName;
  const files = detail.files || [];
  const fileHtml = files.length === 0
    ? '<div class="detail-empty">暂无素材文件</div>'
    : files.map(file => `
        <div class="detail-file-row">
          <div>
            <span class="file-kind">${file.resourceType === 'AUDIO' ? '语音' : '图片'}</span>
            <strong>${escapeHtml(file.relativeName)}</strong>
          </div>
          <button class="link-button" type="button"
            data-preview-asset="${escapeHtml(file.assetId)}"
            data-preview-name="${escapeHtml(file.relativeName)}"
            data-preview-type="${escapeHtml(file.resourceType)}">
            ${file.resourceType === 'AUDIO' ? '播放' : '预览'}
          </button>
        </div>`
      ).join('');

  const history = (detail.history || []).map(entry => `
      <div class="history-row">
        <span>${escapeHtml(formatDateTime(entry.atEpochMs))}</span>
        <strong>${escapeHtml(entry.label)}</strong>
      </div>`
    ).join('') || '<div class="detail-empty">暂无关联记录</div>';

  const taskName = item.taskName || '—';
  const taskCreated = item.taskCreatedAtEpochMs ? formatDateTime(item.taskCreatedAtEpochMs) : '—';
  const errorBlock = item.displayStatus === 'INVALID'
    ? `<div class="detail-alert error"><strong>导入失败原因</strong><span>${escapeHtml(item.errorMessage || '素材校验未通过')}</span></div>`
    : item.displayStatus === 'USED_BEFORE'
      ? '<div class="detail-alert"><strong>历史任务已不存在</strong><span>这个文件夹以前创建过语音任务，可以再次创建。</span></div>'
      : '';

  detailContent.innerHTML = `
    <div class="detail-status-line"><span class="status-badge ${status.className}">${status.label}</span></div>
    ${errorBlock}
    <section class="detail-section">
      <h3>基本信息</h3>
      <dl class="detail-grid">
        <div><dt>任务名称</dt><dd>${escapeHtml(taskName)}</dd></div>
        <div><dt>学生</dt><dd>${escapeHtml(item.studentName)}</dd></div>
        <div><dt>科目</dt><dd>${escapeHtml(subjectLabel(item.subjectCode))}</dd></div>
        <div><dt>预计用时</dt><dd>${escapeHtml(item.expectedMinutes)} 分钟</dd></div>
        <div><dt>任务创建时间</dt><dd>${escapeHtml(taskCreated)}</dd></div>
        <div><dt>文件夹导入时间</dt><dd>${escapeHtml(formatDateTime(item.importedAtEpochMs))}</dd></div>
      </dl>
    </section>
    <section class="detail-section">
      <h3>来源文件夹</h3>
      <div class="source-folder-box">
        <strong>${escapeHtml(item.directoryName)}</strong>
        <span>${item.audioCount} 个语音 · ${item.imageCount} 张图片</span>
      </div>
    </section>
    <section class="detail-section">
      <h3>素材文件</h3>
      <div class="detail-file-list">${fileHtml}</div>
    </section>
    <section class="detail-section">
      <h3>关联记录</h3>
      <div class="history-list">${history}</div>
    </section>`;

  const canCreate = item.displayStatus === 'READY' || item.displayStatus === 'USED_BEFORE';
  detailFooter.innerHTML = canCreate
    ? `<span id="detail-action-message" class="footer-summary"></span>
       <div class="footer-actions">
         <button class="secondary-button" type="button" data-close-detail>关闭</button>
         <button id="create-task-from-detail" class="primary-button" type="button">创建语音任务</button>
       </div>`
    : `<div></div><button class="secondary-button" type="button" data-close-detail>关闭</button>`;
}

async function createTaskFromDetail() {
  const item = state.detail?.item;
  if (!item) return;
  const button = el('create-task-from-detail');
  const message = el('detail-action-message');
  if (button) {
    button.disabled = true;
    button.textContent = '创建中…';
  }
  try {
    const result = await createVoiceMaterialAssignment(
      item.packageId, item.studentId, item.expectedMinutes);
    if (message) message.textContent = result.created ? '语音任务创建成功。' : '当前任务已经存在。';
    state.detail = await getVoiceTaskDetail(item.packageId);
    renderDetail();
    await loadTasks();
  } catch (error) {
    if (message) {
      message.textContent = error?.message || '创建语音任务失败。';
      message.classList.add('error-text');
    }
    if (button) {
      button.disabled = false;
      button.textContent = '创建语音任务';
    }
  }
}

function closeDetail() {
  detailDrawer.hidden = true;
  detailContent.innerHTML = '';
  detailFooter.innerHTML = '';
  state.detail = null;
}

function openImport() {
  resetImportWorkspace();
  importStudentSelect.value = studentSelect.value;
  importDrawer.hidden = false;
}

function closeImport() {
  if (state.importing) return;
  importDrawer.hidden = true;
}

function resetImportWorkspace() {
  state.importPackages = [];
  state.importIgnoredCount = 0;
  state.importResults = [];
  state.importResultFilter = 'ALL';
  state.importing = false;
  folderInput.value = '';
  importFolderSearch.value = '';
  importSelectStage.hidden = false;
  importProgressStage.hidden = true;
  importResultStage.hidden = true;
  startImportButton.hidden = false;
  importCancelButton.hidden = false;
  importAnotherButton.hidden = true;
  importFinishButton.hidden = true;
  renderImportPackages();
  renderImportProgress(0, 0, '准备上传…');
}

function readImportMinutes() {
  const value = Number(importDefaultMinutes.value);
  return Number.isInteger(value) && value >= 1 && value <= 240 ? value : -1;
}

function mergeSelectedFiles(fileList) {
  const minutes = readImportMinutes();
  if (minutes < 0) {
    importPreviewSummary.textContent = '默认预计用时请输入 1～240 分钟。';
    return;
  }
  const incoming = Array.from(fileList || []);
  if (incoming.length === 0) return;
  const parsed = parseVoiceMaterialPackages(
    incoming, importDefaultSubject.value, minutes);
  const existing = new Map(state.importPackages.map(item => [item.key, item]));
  for (const item of parsed.packages) {
    const current = existing.get(item.key);
    if (!current) {
      existing.set(item.key, item);
      continue;
    }
    const known = new Set(current.files.map(file =>
      `${file.resourceType}|${file.relativeName}`));
    for (const file of item.files) {
      const key = `${file.resourceType}|${file.relativeName}`;
      if (!known.has(key)) current.files.push(file);
    }
  }
  state.importPackages = Array.from(existing.values())
    .sort((left, right) => left.directoryName.localeCompare(right.directoryName, 'zh-CN'));
  state.importIgnoredCount += parsed.ignoredCount;
  renderImportPackages();
}

function renderImportPackages() {
  const keyword = importFolderSearch.value.trim().toLowerCase();
  const filtered = state.importPackages
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => !keyword || item.directoryName.toLowerCase().includes(keyword));
  const validCount = state.importPackages.filter(item => validatePackage(item).valid).length;
  const selectedValid = state.importPackages.filter(item =>
    item.selected && validatePackage(item).valid).length;

  importPreviewSummary.textContent = state.importPackages.length === 0
    ? '尚未选择文件夹'
    : `已识别 ${state.importPackages.length} 个目录，${validCount} 个可以导入${state.importIgnoredCount ? `，忽略 ${state.importIgnoredCount} 个不支持文件` : ''}。`;
  importSelectedSummary.textContent = `已选择 ${selectedValid} 个目录`;
  startImportButton.disabled = state.importing || !importStudentSelect.value || selectedValid === 0;
  importEmpty.hidden = state.importPackages.length > 0;
  selectAllImport.checked = state.importPackages.length > 0 &&
    state.importPackages.filter(item => validatePackage(item).valid)
      .every(item => item.selected);

  importTableBody.innerHTML = filtered.map(({ item, index }) => {
    const validation = validatePackage(item);
    return `
      <tr data-import-index="${index}" class="${validation.valid ? '' : 'invalid-row'}">
        <td><input class="import-select" type="checkbox"
          ${item.selected && validation.valid ? 'checked' : ''}
          ${validation.valid ? '' : 'disabled'} aria-label="选择 ${escapeHtml(item.directoryName)}"></td>
        <td class="primary-cell" title="${escapeHtml(item.directoryName)}">${escapeHtml(item.directoryName)}</td>
        <td><select class="compact-select import-subject">${subjectOptions(item.subjectCode)}</select></td>
        <td><div class="minutes-cell"><input class="compact-input import-minutes" type="number" min="1" max="240" value="${escapeHtml(item.expectedMinutes)}"><span>分钟</span></div></td>
        <td>${validation.audioCount} 音频 · ${validation.imageCount} 图片</td>
        <td><span class="validation-text ${validation.valid ? 'ok' : 'bad'}">${escapeHtml(validation.message)}</span></td>
        <td><button class="link-button danger-link remove-import" type="button">移除</button></td>
      </tr>`;
  }).join('');
}

function subjectOptions(selected) {
  return SUBJECTS.map(subject =>
    `<option value="${subject.code}" ${subject.code === selected ? 'selected' : ''}>${escapeHtml(subject.label)}</option>`
  ).join('');
}

function applyImportDefaults() {
  const minutes = readImportMinutes();
  if (minutes < 0) {
    importPreviewSummary.textContent = '默认预计用时请输入 1～240 分钟。';
    return;
  }
  for (const item of state.importPackages) {
    item.subjectCode = importDefaultSubject.value;
    item.expectedMinutes = minutes;
  }
  renderImportPackages();
}

async function collectDroppedDirectory(entry, files, parentPath = '') {
  const reader = entry.createReader();
  const entries = [];
  while (true) {
    const chunk = await new Promise(resolve =>
      reader.readEntries(resolve, () => resolve([])));
    if (chunk.length === 0) break;
    entries.push(...chunk);
  }
  for (const child of entries) {
    const path = parentPath ? `${parentPath}/${child.name}` : child.name;
    if (child.isDirectory) {
      await collectDroppedDirectory(child, files, path);
    } else {
      await new Promise(resolve => child.file(file => {
        try { Object.defineProperty(file, 'relativePath', { value: path }); } catch {}
        files.push(file);
        resolve();
      }, resolve));
    }
  }
}

function renderImportProgress(done, total, message) {
  const percent = total <= 0 ? 0 : Math.round(done * 100 / total);
  importProgressText.textContent = message;
  importProgressPercent.textContent = `${percent}%`;
  importProgressBar.style.width = `${percent}%`;
}

async function uploadSelectedPackages() {
  const selected = state.importPackages.filter(item =>
    item.selected && validatePackage(item).valid);
  if (selected.length === 0 || !importStudentSelect.value || state.importing) return;

  state.importing = true;
  importSelectStage.hidden = true;
  importProgressStage.hidden = false;
  importResultStage.hidden = true;
  startImportButton.disabled = true;
  importCancelButton.disabled = true;
  renderImportProgress(0, selected.length, '正在创建导入批次…');

  const registrationFailures = [];
  try {
    const batch = await createVoiceMaterialBatch(importStudentSelect.value);
    let completedCount = 0;
    for (const item of selected) {
      renderImportProgress(completedCount, selected.length, `正在导入：${item.directoryName}`);
      let remotePackage = null;
      try {
        remotePackage = await registerVoiceMaterialPackage(batch.id, item);
      } catch (error) {
        registrationFailures.push({
          directoryName: item.directoryName,
          subjectCode: item.subjectCode,
          expectedMinutes: item.expectedMinutes,
          audioCount: item.files.filter(file => file.resourceType === 'AUDIO').length,
          imageCount: item.files.filter(file => file.resourceType === 'IMAGE').length,
          status: 'FAILED',
          errorMessage: error?.message || '目录注册失败'
        });
      }
      if (remotePackage) {
        for (const file of uploadOrder(item.files)) {
          try {
            await uploadVoiceMaterialFile(remotePackage.id, file, file.sortOrder);
          } catch (error) {
            console.error('voice material file upload failed',
              item.directoryName, file.relativeName, error);
          }
        }
      }
      completedCount++;
      renderImportProgress(completedCount, selected.length,
        `已处理 ${completedCount} / ${selected.length} 个目录`);
    }

    const completed = await completeVoiceMaterialBatch(batch.id);
    const serverResults = (completed.packages || []).map(item => ({
      ...item,
      resultStatus: item.status === 'READY' || item.status === 'CONSUMED'
        ? 'SUCCESS' : 'FAILED'
    }));
    state.importResults = serverResults.concat(
      registrationFailures.map(item => ({ ...item, resultStatus: 'FAILED' }))
    );
    renderImportProgress(selected.length, selected.length, '导入完成');
    showImportResults();
  } catch (error) {
    state.importResults = [{
      directoryName: '本次导入',
      subjectCode: '',
      audioCount: 0,
      imageCount: 0,
      status: 'FAILED',
      resultStatus: 'FAILED',
      errorMessage: error?.message || '导入失败，请稍后重试'
    }];
    showImportResults();
  } finally {
    state.importing = false;
    importCancelButton.disabled = false;
  }
}

function showImportResults() {
  importProgressStage.hidden = true;
  importResultStage.hidden = false;
  startImportButton.hidden = true;
  importCancelButton.hidden = true;
  importAnotherButton.hidden = false;
  importFinishButton.hidden = false;
  importSelectedSummary.textContent = '';
  renderImportResults();
}

function renderImportResults() {
  const successCount = state.importResults.filter(item => item.resultStatus === 'SUCCESS').length;
  const failedCount = state.importResults.length - successCount;
  importResultSummary.textContent =
    `本次导入 ${state.importResults.length} 个目录 · 成功 ${successCount} · 失败 ${failedCount}`;

  for (const button of el('import-result-filter').querySelectorAll('button')) {
    button.classList.toggle('active', button.dataset.resultFilter === state.importResultFilter);
  }
  const visible = state.importResults.filter(item =>
    state.importResultFilter === 'ALL' || item.resultStatus === state.importResultFilter);
  importResultBody.innerHTML = visible.map(item => {
    const success = item.resultStatus === 'SUCCESS';
    const explanation = success ? '待创建语音任务' : (item.errorMessage || '导入失败');
    return `
      <tr>
        <td class="primary-cell">${escapeHtml(item.directoryName)}</td>
        <td>${escapeHtml(item.subjectCode ? subjectLabel(item.subjectCode) : '—')}</td>
        <td>${Number(item.audioCount || 0)} 音频 · ${Number(item.imageCount || 0)} 图片</td>
        <td><span class="status-badge ${success ? 'success' : 'danger'}">${success ? '导入成功' : '导入失败'}</span></td>
        <td class="${success ? '' : 'error-text'}">${escapeHtml(explanation)}</td>
      </tr>`;
  }).join('');
}

async function finishImport() {
  importDrawer.hidden = true;
  state.page = 0;
  await loadTasks();
}

async function openAssetViewer(assetId, name, resourceType) {
  assetViewer.hidden = false;
  assetViewerContent.innerHTML = '<p class="muted">正在加载素材…</p>';
  try {
    const blob = await fetchVoiceMaterialAsset(assetId);
    const url = URL.createObjectURL(blob);
    assetViewerContent.innerHTML = `<h3 class="asset-viewer-title">${escapeHtml(name)}</h3>`;
    const node = resourceType === 'AUDIO'
      ? document.createElement('audio')
      : document.createElement('img');
    node.controls = resourceType === 'AUDIO';
    node.autoplay = resourceType === 'AUDIO';
    node.src = url;
    if (resourceType === 'IMAGE') node.alt = name;
    assetViewerContent.append(node);
    assetViewerContent.dataset.objectUrl = url;
  } catch (error) {
    assetViewerContent.innerHTML =
      `<p class="error-text">${escapeHtml(error?.message || '素材加载失败')}</p>`;
  }
}

function closeAssetViewer() {
  const url = assetViewerContent.dataset.objectUrl;
  if (url) URL.revokeObjectURL(url);
  assetViewerContent.dataset.objectUrl = '';
  assetViewerContent.innerHTML = '';
  assetViewer.hidden = true;
}

el('task-search-form').addEventListener('submit', event => {
  event.preventDefault();
  state.page = 0;
  void loadTasks();
});

el('reset-search').addEventListener('click', () => {
  statusFilter.value = '';
  subjectFilter.value = '';
  keywordFilter.value = '';
  createdFrom.value = '';
  createdTo.value = '';
  state.page = 0;
  void loadTasks();
});

studentSelect.addEventListener('change', () => {
  state.page = 0;
  importStudentSelect.value = studentSelect.value;
  void loadTasks();
});

el('refresh-tasks').addEventListener('click', () => void loadTasks());

pageSize.addEventListener('change', () => {
  state.size = Number(pageSize.value) || 20;
  state.page = 0;
  void loadTasks();
});

pagination.addEventListener('click', event => {
  const button = event.target.closest('[data-page]');
  if (!button || button.disabled) return;
  const page = Number(button.dataset.page);
  if (!Number.isInteger(page) || page < 0 || page >= state.totalPages) return;
  state.page = page;
  void loadTasks();
});

taskTableBody.addEventListener('click', event => {
  const detailButton = event.target.closest('[data-open-detail]');
  const row = event.target.closest('[data-package-id]');
  const packageId = detailButton?.dataset.openDetail || row?.dataset.packageId;
  if (packageId) void openDetail(packageId);
});

taskTableBody.addEventListener('keydown', event => {
  if (event.key !== 'Enter' && event.key !== ' ') return;
  const row = event.target.closest('[data-package-id]');
  if (!row) return;
  event.preventDefault();
  void openDetail(row.dataset.packageId);
});

el('close-detail').addEventListener('click', closeDetail);
detailDrawer.addEventListener('click', event => {
  if (event.target.hasAttribute('data-close-detail')) closeDetail();
  const preview = event.target.closest('[data-preview-asset]');
  if (preview) {
    void openAssetViewer(
      preview.dataset.previewAsset,
      preview.dataset.previewName,
      preview.dataset.previewType);
  }
  if (event.target.id === 'create-task-from-detail') void createTaskFromDetail();
});

el('open-import').addEventListener('click', openImport);
el('close-import').addEventListener('click', closeImport);
importDrawer.addEventListener('click', event => {
  if (event.target.hasAttribute('data-close-import')) closeImport();
});

folderPicker.addEventListener('click', () => folderInput.click());
folderInput.addEventListener('change', () => {
  mergeSelectedFiles(folderInput.files);
  folderInput.value = '';
});
folderPicker.addEventListener('dragover', event => {
  event.preventDefault();
  folderPicker.classList.add('drag-over');
});
folderPicker.addEventListener('dragleave', () => folderPicker.classList.remove('drag-over'));
folderPicker.addEventListener('drop', async event => {
  event.preventDefault();
  folderPicker.classList.remove('drag-over');
  const files = [];
  for (const item of Array.from(event.dataTransfer?.items || [])) {
    if (item.kind !== 'file') continue;
    const entry = item.webkitGetAsEntry?.() || item.getAsEntry?.();
    if (entry?.isDirectory) {
      await collectDroppedDirectory(entry, files, entry.name);
    } else {
      const file = item.getAsFile();
      if (file) files.push(file);
    }
  }
  mergeSelectedFiles(files);
});

importFolderSearch.addEventListener('input', renderImportPackages);
el('apply-import-defaults').addEventListener('click', applyImportDefaults);

selectAllImport.addEventListener('change', () => {
  for (const item of state.importPackages) {
    if (validatePackage(item).valid) item.selected = selectAllImport.checked;
  }
  renderImportPackages();
});

importTableBody.addEventListener('change', event => {
  const row = event.target.closest('[data-import-index]');
  if (!row) return;
  const item = state.importPackages[Number(row.dataset.importIndex)];
  if (!item) return;
  if (event.target.classList.contains('import-select')) {
    item.selected = event.target.checked;
  } else if (event.target.classList.contains('import-subject')) {
    item.subjectCode = event.target.value;
  } else if (event.target.classList.contains('import-minutes')) {
    item.expectedMinutes = Number(event.target.value);
  }
  renderImportPackages();
});

importTableBody.addEventListener('click', event => {
  if (!event.target.classList.contains('remove-import')) return;
  const row = event.target.closest('[data-import-index]');
  if (!row) return;
  state.importPackages.splice(Number(row.dataset.importIndex), 1);
  renderImportPackages();
});

startImportButton.addEventListener('click', () => void uploadSelectedPackages());
importCancelButton.addEventListener('click', closeImport);
importAnotherButton.addEventListener('click', resetImportWorkspace);
importFinishButton.addEventListener('click', () => void finishImport());

el('import-result-filter').addEventListener('click', event => {
  const button = event.target.closest('[data-result-filter]');
  if (!button) return;
  state.importResultFilter = button.dataset.resultFilter;
  renderImportResults();
});

el('logout-button').addEventListener('click', async () => {
  await logout();
  window.location.reload();
});

el('close-asset-viewer').addEventListener('click', closeAssetViewer);
assetViewer.addEventListener('click', event => {
  if (event.target.hasAttribute('data-close-viewer')) closeAssetViewer();
});

async function startAdmin() {
  if (state.initialized) return;
  state.initialized = true;
  try {
    await loadStudentsAndTasks();
  } catch (error) {
    state.initialized = false;
    resultSummary.textContent = '学生信息加载失败';
    taskTableBody.innerHTML =
      `<tr><td colspan="9" class="error-cell">${escapeHtml(error?.message || '学生信息加载失败，请刷新重试。')}</td></tr>`;
  }
}

window.addEventListener('xiaoban-admin-authenticated', () => void startAdmin());
if (window.__xiaobanAdminAuth) void startAdmin();
