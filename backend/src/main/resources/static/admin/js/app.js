import {
  completeVoiceMaterialBatch,
  createVoiceMaterialBatch,
  fetchVoiceMaterialAsset,
  getToken,
  listStudents,
  listVoiceMaterialPackages,
  login,
  logout,
  registerVoiceMaterialPackage,
  session,
  uploadVoiceMaterialFile
} from './api.js';
import {
  SUBJECTS,
  parseVoiceMaterialPackages,
  uploadOrder,
  validatePackage
} from './voice-material.js';

const state = {
  displayName: '',
  defaultSubjectCode: 'CHINESE',
  packages: [],
  ignoredCount: 0,
  uploading: false,
  importedPackages: []
};

const el = id => document.getElementById(id);
const loginView = el('login-view');
const adminView = el('admin-view');
const loginForm = el('login-form');
const loginButton = loginForm.querySelector('button[type="submit"]');
const loginError = el('login-error');
const loginStatus = document.createElement('p');
loginStatus.className = 'login-status';
loginStatus.hidden = true;
loginForm.insertBefore(loginStatus, loginError);

const LoginState = Object.freeze({
  LOGGED_OUT: 'logged_out',
  AUTHENTICATING: 'authenticating',
  INITIALIZING: 'initializing',
  READY: 'ready'
});

let loginState = LoginState.LOGGED_OUT;

function setView(view) {
  const showLoginView = view === 'login';
  loginView.hidden = !showLoginView;
  adminView.hidden = showLoginView;
  loginView.style.display = showLoginView ? '' : 'none';
  adminView.style.display = showLoginView ? 'none' : 'grid';
}

function setLoginState(nextState, message = '', error = '') {
  loginState = nextState;
  const busy = nextState === LoginState.AUTHENTICATING || nextState === LoginState.INITIALIZING;
  loginButton.disabled = busy;
  loginButton.textContent = busy ? '登录中…' : '登录';
  loginStatus.hidden = !message;
  loginStatus.textContent = message;
  loginError.hidden = !error;
  loginError.textContent = error;
}

function authErrorMessage(error) {
  if (error?.status === 401) {
    return '账号或密码错误。默认密码只在首次初始化数据库时创建；已有账号不会在重启时自动覆盖。';
  }
  return error?.message || '登录失败，请检查后端服务是否可访问。';
}

function showLogin(error = '') {
  setView('login');
  setLoginState(LoginState.LOGGED_OUT, '', error);
}

function showAdminShell(displayName) {
  state.displayName = displayName || '家长';
  el('account-name').textContent = state.displayName;
  setView('admin');
  setLoginState(LoginState.READY);
  console.debug('admin shell ready');
}

async function initializeAdmin() {
  setLoginState(LoginState.INITIALIZING, '登录成功，正在加载学生信息…');
  try {
    await loadStudents();
    setLoginState(LoginState.READY);
  } catch (error) {
    console.error('admin initialization failed', error);
    progressCard.hidden = false;
    showResult('学生信息加载失败：' + (error?.message || '请刷新重试。'), false);
    setLoginState(LoginState.READY, '已登录，但学生信息加载失败，请刷新重试。');
  }
}

async function handleLogin(event) {
  event.preventDefault();
  setLoginState(LoginState.AUTHENTICATING, '正在验证账号…');
  try {
    const result = await login(el('login-name').value.trim(), el('login-password').value);
    showAdminShell(result.displayName);
    await initializeAdmin();
  } catch (error) {
    showLogin(authErrorMessage(error));
  }
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
    return;
  }
  try {
    state.importedPackages = await listVoiceMaterialPackages(studentSelect.value);
    renderImportedPackages();
  } catch (error) {
    importedSummary.textContent = '已导入文件加载失败：' + (error?.message || '请稍后刷新。');
  }
}

function renderImportedPackages() {
  importedCard.hidden = state.importedPackages.length === 0;
  if (state.importedPackages.length === 0) {
    importedSummary.textContent = '当前学生还没有已导入的语音素材。';
    importedList.innerHTML = '';
    return;
  }
  importedSummary.textContent = `共 ${state.importedPackages.length} 个已导入目录，可展开查看文件。`;
  importedList.innerHTML = state.importedPackages.map((item, index) => {
    const status = item.status === 'READY' || item.status === 'CONSUMED' ? '可用' : item.status;
    const files = (item.files || []).map(file => `
      <div class="imported-file">
        <span class="imported-file-name" title="${escapeHtml(file.relativeName)}">${escapeHtml(file.relativeName)}<span class="imported-file-type">${fileKindLabel(file.resourceType)}</span></span>
        <button class="preview-button" type="button" data-preview-asset="${escapeHtml(file.assetId)}" data-preview-name="${escapeHtml(file.relativeName)}" data-preview-type="${escapeHtml(file.resourceType)}">查看</button>
      </div>`).join('');
    return `<details class="imported-package" ${index === 0 ? 'open' : ''}>
      <summary><div class="imported-package-main"><strong>${escapeHtml(item.directoryName)}</strong><span>${escapeHtml(subjectLabel(item.subjectCode))} · ${escapeHtml(status)}</span></div><span class="imported-package-meta">${(item.files || []).length} 个文件</span></summary>
      <div class="imported-file-list">${files}</div>
    </details>`;
  }).join('');
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
    const batchPackages = await listVoiceMaterialPackages(studentSelect.value);
    const results = batchPackages.filter(item => item.batchId === batch.id);
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

    state.importedPackages = batchPackages;
    renderImportedPackages();

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

loginForm.addEventListener('submit', handleLogin);

el('logout-button').addEventListener('click', async () => {
  await logout();
  state.packages = [];
  state.ignoredCount = 0;
  folderInput.value = '';
  renderPackages();
  showLogin();
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
el('refresh-imported').addEventListener('click', () => void loadImportedPackages());
importedList.addEventListener('click', event => {
  const button = event.target.closest('[data-preview-asset]');
  if (button) void openAssetViewer(button.dataset.previewAsset, button.dataset.previewName, button.dataset.previewType);
});
el('close-asset-viewer').addEventListener('click', closeAssetViewer);
assetViewer.addEventListener('click', event => { if (event.target.hasAttribute('data-close-viewer')) closeAssetViewer(); });
uploadButton.addEventListener('click', () => void uploadSelected());

async function bootstrap() {
  setDefaultSubject('CHINESE');
  showLogin();

  if (!getToken()) return;

  try {
    const current = await session();
    showAdminShell(current.displayName);
    await initializeAdmin();
  } catch {
    showLogin('登录状态已失效，请重新登录。');
  }
}

void bootstrap();
