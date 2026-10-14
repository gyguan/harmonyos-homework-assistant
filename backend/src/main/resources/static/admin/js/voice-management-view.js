import { SUBJECTS, validatePackage } from './voice-material.js?v=20261014-2';

export function taskStatusLabel(status) {
  return ({
    NOT_STARTED: '待开始',
    IN_PROGRESS: '进行中',
    PAUSED: '已暂停',
    READY_TO_SUBMIT: '待提交',
    SUBMITTED: '待验收',
    NEEDS_REWORK: '需重做',
    OVERDUE: '已逾期',
    COMPLETED: '已完成'
  })[status] || status || '—';
}

export function taskStatusClass(status) {
  if (status === 'COMPLETED') return 'success';
  if (status === 'OVERDUE' || status === 'NEEDS_REWORK') return 'danger';
  if (status === 'IN_PROGRESS' || status === 'READY_TO_SUBMIT' || status === 'SUBMITTED') return 'ready';
  return 'muted';
}

export function folderStatusLabel(status) {
  return ({ READY: '可用', INVALID: '导入失败', PROCESSING: '处理中', ARCHIVED: '已归档' })[status] ||
    status || '—';
}

export function folderStatusClass(status) {
  if (status === 'READY') return 'success';
  if (status === 'INVALID') return 'danger';
  return 'muted';
}

/** 单行目录的校验说明：能构成素材包就说可以导入，装的是多个子目录就提示往下选。 */
export function importRowStatus(item) {
  const result = validatePackage(item);
  if (result.valid) return { valid: true, text: '可以导入' };
  if (item.childDirectoryCount > 0 && (result.audioCount > 1 || result.audioCount === 0)) {
    return { valid: false, text: '请勾选下面更细的目录' };
  }
  return { valid: false, text: result.message };
}

/**
 * 导入抽屉的目录行。每个识别到的目录层级都是一行，勾选多个即可一次性导入多个文件夹；
 * 层级用缩进 + 灰色上级路径表达，避免同名目录在不同层级混淆。
 */
export function renderImportRows(rows, esc) {
  return rows.map(({ item, index }) => {
    const status = importRowStatus(item);
    const indent = Math.max(0, item.depth - 1) * 14;
    const prefix = item.parentPath ? `<span class="dir-path">${esc(item.parentPath)}/</span>` : '';
    const rowClass = status.valid ? (item.selected ? '' : 'unselected-row') : 'invalid-row';
    const subjects = SUBJECTS.map(subject =>
      `<option value="${subject.code}" ${subject.code === item.subjectCode ? 'selected' : ''}>${esc(subject.label)}</option>`
    ).join('');
    return `<tr data-import-index="${index}" class="${rowClass}">
    <td><input class="import-select" type="checkbox" ${item.selected ? 'checked' : ''} ${status.valid ? '' : 'disabled'}></td>
    <td class="primary-cell folder-cell"><span class="import-dir" style="padding-left:${indent}px">${prefix}${esc(item.name)}</span></td>
    <td><select class="compact-select import-subject">${subjects}</select></td>
    <td><div class="minutes-cell"><input class="compact-input import-minutes" type="number" min="1" max="240" value="${item.expectedMinutes}"><span>分钟</span></div></td>
    <td>${item.audioCount} 音频 · ${item.imageCount} 图片</td>
    <td><span class="validation-text ${status.valid ? 'ok' : 'bad'}">${esc(status.text)}</span></td>
    <td><button class="link-button toggle-import${item.selected ? ' danger-link' : ''}">${item.selected ? '不导入' : '导入'}</button></td>
  </tr>`;
  }).join('');
}

function renderFiles(files, esc) {
  if (!files || files.length === 0) return '<div class="detail-empty">暂无素材文件</div>';
  return files.map(file => `<div class="detail-file-row"><div><span class="file-kind">${file.resourceType === 'AUDIO' ? '语音' : '图片'}</span><strong>${esc(file.relativeName)}</strong></div><button class="link-button" data-preview-asset="${esc(file.assetId || '')}" data-preview-resource="${esc(file.id || '')}" data-preview-name="${esc(file.relativeName)}" data-preview-type="${esc(file.resourceType)}">${file.resourceType === 'AUDIO' ? '播放' : '预览'}</button></div>`).join('');
}

/**
 * 列表勾选单元格。勾选框自带宽高样式（见 .row-select），
 * 点击它不应该触发整行的"打开详情"，由 app.js 的事件处理里屏蔽。
 */
function selectCell(attribute, id, selectedIds, esc) {
  const checked = selectedIds && selectedIds.has(id) ? 'checked' : '';
  return `<td class="checkbox-column"><input class="row-select" type="checkbox" ${attribute}="${esc(id)}" ${checked}></td>`;
}

export function renderTaskRows(items, helpers) {
  const { esc, subjectLabel, formatDateTime, selectedIds } = helpers;
  return items.map(item => `<tr class="clickable-row${selectedIds && selectedIds.has(item.assignmentId) ? ' selected-row' : ''}" data-task-id="${esc(item.assignmentId)}" tabindex="0">
    ${selectCell('data-select-task', item.assignmentId, selectedIds, esc)}
    <td class="primary-cell">${esc(item.taskName)}</td>
    <td><span class="status-badge ${taskStatusClass(item.assignmentStatus)}">${esc(taskStatusLabel(item.assignmentStatus))}</span></td>
    <td>${esc(item.studentName)}</td>
    <td>${esc(subjectLabel(item.subjectCode))}</td>
    <td class="folder-cell">${esc(item.directoryName)}</td>
    <td>${item.expectedMinutes} 分钟</td>
    <td>${esc(formatDateTime(item.taskCreatedAtEpochMs))}</td>
    <td><button class="link-button" data-open-task="${esc(item.assignmentId)}">详情</button></td>
  </tr>`).join('');
}

export function renderFolderRows(items, helpers) {
  const { esc, subjectLabel, formatDateTime, selectedIds } = helpers;
  return items.map(item => `<tr class="clickable-row${selectedIds && selectedIds.has(item.packageId) ? ' selected-row' : ''}" data-folder-id="${esc(item.packageId)}" tabindex="0">
    ${selectCell('data-select-folder', item.packageId, selectedIds, esc)}
    <td class="primary-cell folder-cell">${esc(item.directoryName)}</td>
    <td><span class="status-badge ${folderStatusClass(item.folderStatus)}">${esc(folderStatusLabel(item.folderStatus))}</span></td>
    <td>${esc(item.studentName)}</td>
    <td>${esc(subjectLabel(item.subjectCode))}</td>
    <td>${item.audioCount} 音频 · ${item.imageCount} 图片</td>
    <td>${item.usageCount} 次</td>
    <td>${esc(formatDateTime(item.lastUsedAtEpochMs))}</td>
    <td>${esc(formatDateTime(item.importedAtEpochMs))}</td>
    <td><button class="link-button" data-open-folder="${esc(item.packageId)}">详情</button></td>
  </tr>`).join('');
}

export function renderTaskDetailContent(detail, helpers) {
  const { esc, subjectLabel, formatDateTime } = helpers;
  const item = detail.item;
  return `<div class="detail-status-line"><span class="status-badge ${taskStatusClass(item.assignmentStatus)}">${esc(taskStatusLabel(item.assignmentStatus))}</span></div>
  <section class="detail-section"><h3>基本信息</h3><dl class="detail-grid"><div><dt>任务名称</dt><dd>${esc(item.taskName)}</dd></div><div><dt>学生</dt><dd>${esc(item.studentName)}</dd></div><div><dt>科目</dt><dd>${esc(subjectLabel(item.subjectCode))}</dd></div><div><dt>预计用时</dt><dd>${item.expectedMinutes} 分钟</dd></div><div><dt>创建时间</dt><dd>${esc(formatDateTime(item.taskCreatedAtEpochMs))}</dd></div></dl></section>
  <section class="detail-section"><h3>素材来源</h3><div class="source-folder-box"><div><strong>${esc(item.directoryName)}</strong></div>${item.packageId ? `<button class="link-button" data-jump-folder="${esc(item.packageId)}">查看文件夹</button>` : '<span class="muted">APP 本地上传</span>'}</div></section>
  <section class="detail-section"><h3>素材文件</h3><div class="detail-file-list">${renderFiles(detail.files, esc)}</div></section>`;
}

export function renderFolderDetailContent(detail, helpers) {
  const { esc, subjectLabel, formatDateTime } = helpers;
  const item = detail.item;
  const history = (detail.recentTasks || []).map(task =>
    `<div class="history-task-row"><div><strong>${esc(task.taskName || '语音任务')}</strong><span>${esc(formatDateTime(task.createdAtEpochMs))} · ${esc(taskStatusLabel(task.assignmentStatus))}</span></div>${task.assignmentExists ? `<button class="link-button" data-jump-task="${esc(task.assignmentId)}">查看</button>` : '<span class="muted">任务已删除</span>'}</div>`
  ).join('') || '<div class="detail-empty">还没有创建过语音任务</div>';

  return `<div class="detail-status-line"><span class="status-badge ${folderStatusClass(item.folderStatus)}">${esc(folderStatusLabel(item.folderStatus))}</span></div>
  ${item.folderStatus === 'INVALID' ? `<div class="detail-alert error"><strong>导入失败原因</strong><span>${esc(item.errorMessage || '素材校验未通过')}</span></div>` : ''}
  <section class="detail-section"><h3>基本信息</h3><dl class="detail-grid"><div><dt>文件夹名称</dt><dd>${esc(item.directoryName)}</dd></div><div><dt>学生</dt><dd>${esc(item.studentName)}</dd></div><div><dt>科目</dt><dd>${esc(subjectLabel(item.subjectCode))}</dd></div><div><dt>默认预计用时</dt><dd>${item.expectedMinutes} 分钟</dd></div><div><dt>导入时间</dt><dd>${esc(formatDateTime(item.importedAtEpochMs))}</dd></div></dl></section>
  <section class="detail-section"><h3>素材文件</h3><div class="detail-file-list">${renderFiles(detail.files, esc)}</div></section>
  <section class="detail-section"><h3>使用情况</h3><div class="usage-summary"><div><strong>${item.usageCount}</strong><span>已创建任务</span></div><div><strong>${item.activeTaskCount}</strong><span>当前有效任务</span></div><div><strong>${esc(formatDateTime(item.lastUsedAtEpochMs))}</strong><span>最近使用</span></div></div></section>
  <section class="detail-section"><h3>最近关联任务</h3><div class="history-task-list">${history}</div></section>`;
}
