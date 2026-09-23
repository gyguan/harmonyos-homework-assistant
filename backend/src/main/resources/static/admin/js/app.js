import {
  completeVoiceMaterialBatch,
  createVoiceMaterialAssignment,
  createVoiceMaterialBatch,
  fetchVoiceMaterialAsset,
  listStudents,
  listVoiceMaterialPackages,
  logout,
  registerVoiceMaterialPackage,
  uploadVoiceMaterialFile
} from './api.js?v=20260923-2';
import {
  SUBJECTS,
  parseVoiceMaterialPackages,
  uploadOrder,
  validatePackage
} from './voice-material.js?v=20260923-2';

const state = {
  displayName: '',
  defaultSubjectCode: 'CHINESE',
  packages: [],
  ignoredCount: 0,
  uploading: false,
  importedPackages: []
};

const el = id => document.getElementById(id);
let adminInitialized = false;

async function initializeAdmin() {
  if (adminInitialized) return;
  adminInitialized = true;
  try {
    await loadStudents();
  } catch (error) {
    console.error('admin initialization failed', error);
    progressCard.hidden = false;
    showResult('学生信息加载失败：' + (error?.message || '请刷新重试。'), false);
  }
}

function startAdmin(displayName) {
  state.displayName = displayName || '家长';
  el('account-name').textContent = state.displayName;
  void initializeAdmin();
}

const studentSelect = el('student-select');
const defaultMinutes = el('default-minutes');
const subjectChips = el('subject-chips');
const folderInput = el('folder-input');
const folderPicker = el('folder-picker');
const folderFilesInput = el('folder-files-input');
const importedCard = el('imported-card');
const importedSummary = el('imported-summary');
const importedList = el('imported-list');
const assetViewer = el('asset-viewer');
const assetViewerContent = el('asset-viewer-content');
const previewCard = el('preview-card');
const previewSummary = el('preview-summary');
const packageList = el('package-list');
const selectedSummary = el('selected-summary');
const ignoredSummary = el('ignored-summary');
const uploadButton = el('upload-button');
const applyDefaultsButton = el('apply-defaults');
const voiceTaskSummary = el('voice-task-summary');
const voiceTaskList = el('voice-task-list');
const voiceStatCreated = el('voice-stat-created');
const voiceStatReady = el('voice-stat-ready');
const voiceStatFolders = el('voice-stat-folders');
const uploadMaterialEntry = el('upload-material-entry');
const uploadSection = el('upload-section');
const progressCard = el('progress-card');
const progressText = el('progress-text');
const progressPercent = el('progress-percent');
const progressBar = el('progress-bar');
const resultMessage = el('result-message');

async function loadStudents() {
  const students = await listStudents();
  studentSelect.innerHTML = '';
  for (const student of students) {
    const option = document.createElement('option');
    option.value = student.id;
    option.textContent = `${student.name} · ${student.grade} ${student.semester}`;
    studentSelect.append(option);
  }
  if (students.length === 0) {
    const option = document.createElement('option');
    option.value = '';
    option.textContent = '当前家庭还没有学生';
    studentSelect.append(option);
  }
  updateUploadState();
  await loadImportedPackages();
}

function mergeSelectedFiles(fileList) {
  const incoming = Array.from(fileList || []);
  if (incoming.length === 0) return;
  const parsed = parseVoiceMaterialPackages(incoming, state.defaultSubjectCode, readDefaultMinutes());
  const existing = new Map(state.packages.map(item => [item.key, item]));
  for (const item of parsed.packages) {
    const current = existing.get(item.key);
    if (!current) existing.set(item.key, item);
    else {
      const known = new Set(current.files.map(file => `${file.resourceType}|${file.relativeName}`));
      for (const file of item.files) {
        const key = `${file.resourceType}|${file.relativeName}`;
        if (!known.has(key)) current.files.push(file);
      }
    }
  }
  state.packages = Array.from(existing.values()).sort((a, b) => a.directoryName.localeCompare(b.directoryName, 'zh-CN'));
  state.ignoredCount += parsed.ignoredCount;
  progressCard.hidden = true;
  resultMessage.hidden = true;
  renderPackages();
}

async function loadImportedPackages() {
  if (!studentSelect.value) {
    state.importedPackages = [];
    renderImportedPackages();
    renderVoiceTasks();
    return;
  }
  try {
    state.importedPackages = await listVoiceMaterialPackages(studentSelect.value);
    renderImportedPackages();
    renderVoiceTasks();
  } catch (error) {
    state.importedPackages = [];
    renderImportedPackages();
    renderVoiceTasks();
    voiceTaskSummary.textContent = '语音任务加载失败：' + (error?.message || '请稍后刷新。');
  }
}

function renderImportedPackages() {
  // 语音素材已经合并到“语音任务”卡片中展示，避免再维护第二套素材列表。
  importedCard.hidden = true;
  importedList.innerHTML = '';
}

function voiceTaskStatus(item) {
  if (item.status === 'CONSUMED') return { label: '已创建', className: 'created' };
  if (item.status === 'READY') return { label: '待创建', className: 'ready' };
  if (item.status === 'INVALID') return { label: '导入失败', className: 'invalid' };
  return { label: item.status || '处理中', className: 'pending' };
}

function formatTaskTime(epochMs) {
  const value = Number(epochMs || 0);
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const pad = part => String(part).padStart(2, '0');
  return pad(date.getMonth() + 1) + '-' + pad(date.getDate()) + ' ' +
    pad(date.getHours()) + ':' + pad(date.getMinutes());
}

function renderTaskFiles(item) {
  const files = item.files || [];
  const audio = files.filter(file => file.resourceType === 'AUDIO');
  const images = files.filter(file => file.resourceType === 'IMAGE');
  const renderFile = (file, kind) =>
    '<button class="voice-material-file" type="button" data-preview-asset="' +
    escapeHtml(file.assetId) + '" data-preview-name="' + escapeHtml(file.relativeName) +
    '" data-preview-type="' + escapeHtml(file.resourceType) + '">' +
    '<span class="voice-material-kind">' + kind + '</span>' +
    '<span class="voice-material-name">' + escapeHtml(file.relativeName) + '</span></button>';

  const audioHtml = audio.length > 0
    ? audio.map(file => renderFile(file, '语音')).join('')
    : '<span class="voice-material-missing">无语音文件</span>';
  const imageHtml = images.length > 0
    ? images.map(file => renderFile(file, '图片')).join('')
    : '<span class="voice-material-missing">无图片</span>';

  return '<div class="voice-task-materials">' + audioHtml + imageHtml + '</div>';
}

function renderVoiceTasks() {
  if (!studentSelect.value) {
    voiceTaskSummary.textContent = '请选择学生后查看语音任务。';
    voiceStatCreated.textContent = '0';
    voiceStatReady.textContent = '0';
    voiceStatFolders.textContent = '0';
    voiceTaskList.innerHTML = '';
    return;
  }

  const packages = state.importedPackages || [];
  const created = packages.filter(item => item.status === 'CONSUMED' && item.consumedAssignmentId).length;
  const ready = packages.filter(item => item.status === 'READY').length;
  const invalid = packages.filter(item => item.status === 'INVALID').length;
  voiceStatCreated.textContent = String(created);
  voiceStatReady.textContent = String(ready);
  voiceStatFolders.textContent = String(packages.length);
  voiceTaskSummary.textContent = invalid > 0
    ? '共 ' + packages.length + ' 个素材文件夹，其中 ' + invalid + ' 个需要处理。'
    : '任务与来源文件夹一一对应，可直接查看素材或创建任务。';

  if (packages.length === 0) {
    voiceTaskList.innerHTML =
      '<div class="voice-task-empty">' +
      '<strong>还没有语音任务</strong>' +
      '<span>先上传一个包含 1 个语音文件和至少 1 张图片的文件夹。</span>' +
      '<button class="secondary-button" type="button" data-upload-material>上传语音文件夹</button>' +
      '</div>';
    return;
  }

  const priority = { CONSUMED: 0, READY: 1, INVALID: 2 };
  const sorted = [...packages].sort((a, b) => {
    const statusCompare = (priority[a.status] ?? 9) - (priority[b.status] ?? 9);
    return statusCompare !== 0
      ? statusCompare
      : String(a.directoryName || '').localeCompare(String(b.directoryName || ''), 'zh-CN');
  });

  voiceTaskList.innerHTML = sorted.map(item => {
    const status = voiceTaskStatus(item);
    const createdAt = formatTaskTime(item.consumedAtEpochMs);
    const footerMeta = item.status === 'CONSUMED'
      ? (createdAt ? '创建时间 ' + createdAt : '任务已创建')
      : item.status === 'READY'
        ? '素材已就绪，可以创建任务'
        : item.status === 'INVALID'
          ? '未创建任务'
          : '素材处理中';

    const action = item.status === 'READY'
      ? '<button class="secondary-button voice-task-create" type="button" data-create-package="' +
        escapeHtml(item.id) + '">创建语音任务</button>'
      : item.status === 'CONSUMED'
        ? '<span class="voice-task-done">任务已关联</span>'
        : item.status === 'INVALID'
          ? '<span class="voice-task-error">' +
            escapeHtml(item.errorMessage || '素材校验未通过') + '</span>'
          : '<span class="muted">处理中</span>';

    return '<article class="voice-task-row">' +
      '<div class="voice-task-head">' +
        '<div class="voice-task-title">' +
          '<strong>' + escapeHtml(item.title || item.directoryName) + '</strong>' +
          '<span>' + escapeHtml(subjectLabel(item.subjectCode)) + ' · 预计 ' +
            escapeHtml(item.expectedMinutes) + ' 分钟</span>' +
        '</div>' +
        '<span class="voice-task-status ' + status.className + '">' + status.label + '</span>' +
      '</div>' +
      '<div class="voice-task-source">' +
        '<span class="voice-task-label">来源文件夹</span>' +
        '<div class="voice-task-folder-line">' +
          '<strong title="' + escapeHtml(item.directoryName) + '">' +
            escapeHtml(item.directoryName) + '</strong>' +
          '<span>' + (item.files || []).length + ' 个素材文件</span>' +
        '</div>' +
        renderTaskFiles(item) +
      '</div>' +
      '<div class="voice-task-footer">' +
        '<span class="voice-task-meta">' + escapeHtml(footerMeta) + '</span>' +
        '<div class="voice-task-action">' + action + '</div>' +
      '</div>' +
    '</article>';
  }).join('');
}

async function createVoiceTask(packageId) {
  if (!studentSelect.value) return;
  const item = state.importedPackages.find(packageItem => packageItem.id === packageId);
  if (!item || item.status !== 'READY') return;
  const button = voiceTaskList.querySelector(\`[data-create-package="\${CSS.escape(packageId)}"]\`);
  if (button) {
    button.disabled = true;
    button.textContent = '创建中…';
  }
  try {
    await createVoiceMaterialAssignment(packageId, studentSelect.value, item.expectedMinutes);
    await loadImportedPackages();
    progressCard.hidden = false;
    showResult(\`已创建语音任务“\${item.title || item.directoryName}”，关联文件夹“\${item.directoryName}”。\`, true);
  } catch (error) {
    if (button) {
      button.disabled = false;
      button.textContent = '创建任务';
    }
    progressCard.hidden = false;
    showResult(error?.message || '创建语音任务失败，请稍后重试。', false);
  }
}

function fileKindLabel(type) {
  return type === 'AUDIO' ? '语音' : '图片';
}

async function openAssetViewer(assetId, name, resourceType) {
  assetViewer.hidden = false;
  assetViewerContent.innerHTML = '<p class="muted">正在加载素材…</p>';
  try {
    const blob = await fetchVoiceMaterialAsset(assetId);
    const url = URL.createObjectURL(blob);
    assetViewerContent.innerHTML = `<h3 class="asset-viewer-title">${escapeHtml(name)}</h3>`;
    const node = resourceType === 'AUDIO' ? document.createElement('audio') : document.createElement('img');
    node.controls = resourceType === 'AUDIO';
    node.autoplay = resourceType === 'AUDIO';
    node.src = url;
    if (resourceType === 'IMAGE') node.alt = name;
    assetViewerContent.append(node);
    assetViewerContent.dataset.objectUrl = url;
  } catch (error) {
    assetViewerContent.innerHTML = `<p class="error-text">${escapeHtml(error?.message || '素材加载失败')}</p>`;
  }
}

function closeAssetViewer() {
  const url = assetViewerContent.dataset.objectUrl;
  if (url) URL.revokeObjectURL(url);
  assetViewerContent.dataset.objectUrl = '';
  assetViewerContent.innerHTML = '';
  assetViewer.hidden = true;
}

function readDefaultMinutes() {
  const value = Number(defaultMinutes.value);
  return Number.isInteger(value) && value >= 1 && value <= 240 ? value : -1;
}

function subjectLabel(code) {
  return SUBJECTS.find(subject => subject.code === code)?.label || '其他';
}

function setDefaultSubject(code) {
  state.defaultSubjectCode = code;
  for (const chip of subjectChips.querySelectorAll('.chip')) {
    chip.classList.toggle('active', chip.dataset.subject === code);
  }
}

function packageOptions(selected) {
  return SUBJECTS.map(subject =>
    `<option value="${subject.code}" ${subject.code === selected ? 'selected' : ''}>${subject.label}</option>`
  ).join('');
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
  })[char]);
}

function renderPackages() {
  previewCard.hidden = state.packages.length === 0;
  applyDefaultsButton.disabled = state.packages.length === 0 || state.uploading;
  packageList.innerHTML = '';

  let validCount = 0;
  let selectedValidCount = 0;
  for (const [index, item] of state.packages.entries()) {
    const validation = validatePackage(item);
    if (validation.valid) validCount++;
    if (validation.valid && item.selected) selectedValidCount++;

    const row = document.createElement('div');
    row.className = `package-row ${validation.valid ? '' : 'invalid'}`;
    row.dataset.index = String(index);
    row.innerHTML = `
      <input class="package-select" type="checkbox" ${item.selected && validation.valid ? 'checked' : ''} ${validation.valid ? '' : 'disabled'}>
      <div class="package-main">
        <strong title="${escapeHtml(item.directoryName)}">${escapeHtml(item.directoryName)}</strong>
        <span>${item.files.length} 个支持文件</span>
      </div>
      <select class="package-subject">${packageOptions(item.subjectCode)}</select>
      <input class="minutes-input package-minutes" type="number" min="1" max="240" value="${item.expectedMinutes}">
      <span class="package-status ${validation.valid ? 'ok' : 'bad'}">
        ${validation.audioCount} 语音 · ${validation.imageCount} 图片 · ${validation.message}
      </span>
      <button class="remove-button" type="button">移除</button>
    `;
    packageList.append(row);
  }

  previewSummary.textContent = `共识别 ${state.packages.length} 个目录，${validCount} 个满足导入要求。`;
  selectedSummary.textContent = `${selectedValidCount} 个可导入`;
  ignoredSummary.textContent = state.ignoredCount > 0 ? `已忽略 ${state.ignoredCount} 个非语音/图片文件` : '';
  updateUploadState();
}

function updateUploadState() {
  const hasStudent = Boolean(studentSelect.value);
  const count = state.packages.filter(item => item.selected && validatePackage(item).valid).length;
  uploadButton.disabled = state.uploading || !hasStudent || count === 0;
  uploadButton.textContent = state.uploading ? '正在导入…' : `导入 ${count} 个目录`;
  folderPicker.disabled = state.uploading;
  studentSelect.disabled = state.uploading;
}

function updateProgress(done, total, message) {
  const percent = total <= 0 ? 0 : Math.round(done * 100 / total);
  progressText.textContent = message;
  progressPercent.textContent = `${percent}%`;
  progressBar.style.width = `${percent}%`;
}

function showResult(message, success) {
  resultMessage.hidden = false;
  resultMessage.className = `result-message ${success ? 'success' : 'error'}`;
  resultMessage.textContent = message;
}

async function collectDroppedDirectory(entry, files, parentPath = '') {
  const reader = entry.createReader();
  const entries = [];
  while (true) {
    const chunk = await new Promise(resolve => reader.readEntries(resolve, () => resolve([])));
    if (chunk.length === 0) break;
    entries.push(...chunk);
  }
  for (const child of entries) {
    const path = parentPath ? `${parentPath}/${child.name}` : child.name;
    if (child.isDirectory) await collectDroppedDirectory(child, files, path);
    else await new Promise(resolve => child.file(file => {
      try { Object.defineProperty(file, 'relativePath', { value: path }); } catch {}
      files.push(file);
      resolve();
    }, resolve));
  }
}

async function uploadSelected() {
  const selected = state.packages.filter(item => item.selected && validatePackage(item).valid);
  if (!studentSelect.value || selected.length === 0 || state.uploading) return;

  state.uploading = true;
  progressCard.hidden = false;
  resultMessage.hidden = true;
  updateUploadState();
  updateProgress(0, selected.length, '正在创建导入批次…');

  let batch = null;
  let finishedDirectories = 0;
  let registrationFailures = 0;
  try {
    batch = await createVoiceMaterialBatch(studentSelect.value);
    for (const item of selected) {
      updateProgress(finishedDirectories, selected.length, `正在导入：${item.directoryName}`);
      let remotePackage = null;
      try {
        remotePackage = await registerVoiceMaterialPackage(batch.id, item);
      } catch (error) {
        registrationFailures++;
        console.error('voice material package registration failed', item.directoryName, error);
      }
      if (remotePackage !== null) {
        try {
          for (const file of uploadOrder(item.files)) {
            await uploadVoiceMaterialFile(remotePackage.id, file, file.sortOrder);
          }
        } catch (error) {
          console.error('voice material file upload failed', item.directoryName, error);
        }
      }
      finishedDirectories++;
      updateProgress(finishedDirectories, selected.length, `已处理 ${finishedDirectories} / ${selected.length} 个目录`);
    }

    const completed = await completeVoiceMaterialBatch(batch.id);
    const results = completed.packages || [];
    const failedResults = results.filter(item => item.status === 'INVALID');
    const failures = failedResults.length + registrationFailures;

    updateProgress(selected.length, selected.length, '导入完成');

    const failureDetails = failedResults
      .map(item => `${item.directoryName}：${item.errorMessage || '素材校验未通过'}`)
      .concat(registrationFailures > 0 ? [`${registrationFailures} 个目录注册失败，请重新导入`] : []);

    showResult(
      failures > 0
        ? `导入结束：${completed.readyCount} 个可用，${failures} 个失败。\\n${failureDetails.join('；')}`
        : `导入成功：${completed.readyCount} 个语音素材目录已保存到服务端。`,
      failures === 0
    );

    await loadImportedPackages();

    if (completed.readyCount > 0) {
      const successfulKeys = new Set(
        results.filter(item => item.status === 'READY' || item.status === 'CONSUMED')
          .map(item => item.directoryName)
      );
      state.packages = state.packages.filter(item => !item.selected || !successfulKeys.has(item.directoryName));
      renderPackages();
      if (state.packages.length === 0) folderInput.value = '';
    }
  } catch (error) {
    showResult(error.message || '导入失败，请稍后重试', false);
  } finally {
    state.uploading = false;
    updateUploadState();
  }
}

el('logout-button').addEventListener('click', async () => {
  await logout();
  window.location.reload();
});

subjectChips.addEventListener('click', event => {
  const button = event.target.closest('[data-subject]');
  if (!button) return;
  setDefaultSubject(button.dataset.subject);
});

folderPicker.addEventListener('click', () => folderInput.click());
folderPicker.addEventListener('dragover', event => { event.preventDefault(); folderPicker.classList.add('drag-over'); });
folderPicker.addEventListener('dragleave', () => folderPicker.classList.remove('drag-over'));
folderPicker.addEventListener('drop', async event => {
  event.preventDefault();
  folderPicker.classList.remove('drag-over');
  const files = [];
  for (const item of Array.from(event.dataTransfer?.items || [])) {
    if (item.kind !== 'file') continue;
    const entry = item.webkitGetAsEntry?.() || item.getAsEntry?.();
    if (entry?.isDirectory) await collectDroppedDirectory(entry, files);
    else {
      const file = item.getAsFile();
      if (file) files.push(file);
    }
  }
  mergeSelectedFiles(files);
});


folderInput.addEventListener('change', () => {
  const minutes = readDefaultMinutes();
  if (minutes < 0) {
    showResult('预计用时请输入 1～240 分钟的整数。', false);
    progressCard.hidden = false;
    folderInput.value = '';
    return;
  }
  const parsed = parseVoiceMaterialPackages(folderInput.files, state.defaultSubjectCode, minutes);
  state.packages = parsed.packages;
  state.ignoredCount = parsed.ignoredCount;
  progressCard.hidden = true;
  resultMessage.hidden = true;
  renderPackages();
});

folderFilesInput.addEventListener('change', () => {
  const minutes = readDefaultMinutes();
  if (minutes < 0) { progressCard.hidden = false; showResult('预计用时请输入 1～240 分钟的整数。', false); folderFilesInput.value = ''; return; }
  mergeSelectedFiles(folderFilesInput.files);
  folderFilesInput.value = '';
});

applyDefaultsButton.addEventListener('click', () => {
  const minutes = readDefaultMinutes();
  if (minutes < 0) {
    progressCard.hidden = false;
    showResult('预计用时请输入 1～240 分钟的整数。', false);
    return;
  }
  for (const item of state.packages) {
    item.subjectCode = state.defaultSubjectCode;
    item.expectedMinutes = minutes;
  }
  renderPackages();
});

packageList.addEventListener('change', event => {
  const row = event.target.closest('.package-row');
  if (!row) return;
  const item = state.packages[Number(row.dataset.index)];
  if (!item) return;
  if (event.target.classList.contains('package-select')) item.selected = event.target.checked;
  if (event.target.classList.contains('package-subject')) item.subjectCode = event.target.value;
  if (event.target.classList.contains('package-minutes')) item.expectedMinutes = Number(event.target.value);
  renderPackages();
});

packageList.addEventListener('click', event => {
  if (!event.target.classList.contains('remove-button')) return;
  const row = event.target.closest('.package-row');
  if (!row) return;
  state.packages.splice(Number(row.dataset.index), 1);
  renderPackages();
});

el('clear-packages').addEventListener('click', () => {
  state.packages = [];
  state.ignoredCount = 0;
  folderInput.value = '';
  renderPackages();
});

studentSelect.addEventListener('change', () => { updateUploadState(); void loadImportedPackages(); });
uploadMaterialEntry.addEventListener('click', () => uploadSection.scrollIntoView({ behavior: 'smooth', block: 'start' }));
voiceTaskList.addEventListener('click', event => {
  const previewButton = event.target.closest('[data-preview-asset]');
  if (previewButton) {
    void openAssetViewer(
      previewButton.dataset.previewAsset,
      previewButton.dataset.previewName,
      previewButton.dataset.previewType
    );
    return;
  }
  if (event.target.closest('[data-upload-material]')) {
    uploadSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
    return;
  }
  const button = event.target.closest('[data-create-package]');
  if (button) void createVoiceTask(button.dataset.createPackage);
});
el('refresh-imported').addEventListener('click', () => void loadImportedPackages());
importedList.addEventListener('click', event => {
  const button = event.target.closest('[data-preview-asset]');
  if (button) void openAssetViewer(button.dataset.previewAsset, button.dataset.previewName, button.dataset.previewType);
});
el('close-asset-viewer').addEventListener('click', closeAssetViewer);
assetViewer.addEventListener('click', event => { if (event.target.hasAttribute('data-close-viewer')) closeAssetViewer(); });
uploadButton.addEventListener('click', () => void uploadSelected());

function onAuthenticated(event) {
  startAdmin(event?.detail?.displayName || '');
}

window.addEventListener('xiaoban-admin-authenticated', onAuthenticated);
setDefaultSubject('CHINESE');

if (window.__xiaobanAdminAuth) {
  startAdmin(window.__xiaobanAdminAuth.displayName || '');
}
