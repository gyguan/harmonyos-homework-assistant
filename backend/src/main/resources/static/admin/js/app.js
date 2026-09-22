import {
  completeVoiceMaterialBatch,
  createVoiceMaterialBatch,
  getToken,
  listStudents,
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
  uploading: false
};

const el = id => document.getElementById(id);
const loginView = el('login-view');
const adminView = el('admin-view');
const loginForm = el('login-form');
const loginSubmit = el('login-submit');
const loginStatus = el('login-status');
const loginError = el('login-error');
const studentSelect = el('student-select');
const defaultMinutes = el('default-minutes');
const subjectChips = el('subject-chips');
const folderInput = el('folder-input');
const folderPicker = el('folder-picker');
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

function setLoginBusy(busy, status = '') {
  loginSubmit.disabled = busy;
  loginSubmit.textContent = busy ? '登录中…' : '登录';
  loginStatus.hidden = !status;
  loginStatus.textContent = status;
}

function loginFailureMessage(error) {
  if (error && error.status === 401) {
    return '账号或密码错误。默认密码只在首次初始化数据库时创建；已有账号不会在重启时被自动覆盖。';
  }
  return error && error.message ? error.message : '登录失败，请检查后端服务是否可访问';
}

function showLogin(message = '', status = '') {
  loginView.hidden = false;
  adminView.hidden = true;
  setLoginBusy(false, status);
  loginError.hidden = !message;
  loginError.textContent = message;
}

async function showAdmin(displayName) {
  await loadStudents();
  state.displayName = displayName;
  el('account-name').textContent = displayName || '家长';
  loginView.hidden = true;
  adminView.hidden = false;
  setLoginBusy(false);
}

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
    const failures = completed.invalidCount + registrationFailures;
    updateProgress(selected.length, selected.length, '导入完成');
    showResult(
      failures > 0
        ? `导入结束：${completed.readyCount} 个可用，${failures} 个失败或素材异常。可根据结果修正后重新导入。`
        : `导入成功：${completed.readyCount} 个语音素材目录已保存到服务端。`,
      failures === 0
    );

    if (failures === 0 && completed.readyCount > 0) {
      state.packages = state.packages.filter(item => !item.selected || !validatePackage(item).valid);
      renderPackages();
      folderInput.value = '';
    }
  } catch (error) {
    showResult(error.message || '导入失败，请稍后重试', false);
  } finally {
    state.uploading = false;
    updateUploadState();
  }
}

loginForm.addEventListener('submit', async event => {
  event.preventDefault();
  loginError.hidden = true;
  setLoginBusy(true, '正在验证账号…');

  let result = null;
  try {
    result = await login(el('login-name').value.trim(), el('login-password').value);
  } catch (error) {
    showLogin(loginFailureMessage(error));
    return;
  }

  setLoginBusy(true, '登录成功，正在加载学生信息…');
  try {
    await showAdmin(result.displayName);
  } catch (error) {
    try { await logout(); } catch {}
    const detail = error && error.message ? error.message : '未知错误';
    showLogin('账号验证成功，但加载学生信息失败：' + detail);
  }
});

el('logout-button').addEventListener('click', async () => {
  await logout();
  state.packages = [];
  renderPackages();
  showLogin();
});

subjectChips.addEventListener('click', event => {
  const button = event.target.closest('[data-subject]');
  if (!button) return;
  setDefaultSubject(button.dataset.subject);
});

folderPicker.addEventListener('click', () => folderInput.click());

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

studentSelect.addEventListener('change', updateUploadState);
uploadButton.addEventListener('click', () => void uploadSelected());

async function bootstrap() {
  setDefaultSubject('CHINESE');
  if (!getToken()) {
    showLogin();
    return;
  }
  try {
    const current = await session();
    await showAdmin(current.displayName);
  } catch {
    showLogin('登录状态已失效，请重新登录');
  }
}

void bootstrap();
