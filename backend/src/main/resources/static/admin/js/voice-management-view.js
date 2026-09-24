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

function renderFiles(files, esc) {
  if (!files || files.length === 0) return '<div class="detail-empty">暂无素材文件</div>';
  return files.map(file => `<div class="detail-file-row"><div><span class="file-kind">${file.resourceType === 'AUDIO' ? '语音' : '图片'}</span><strong>${esc(file.relativeName)}</strong></div><button class="link-button" data-preview-asset="${esc(file.assetId || '')}" data-preview-resource="${esc(file.id || '')}" data-preview-name="${esc(file.relativeName)}" data-preview-type="${esc(file.resourceType)}">${file.resourceType === 'AUDIO' ? '播放' : '预览'}</button></div>`).join('');
}

export function renderTaskRows(items, helpers) {
  const { esc, subjectLabel, formatDateTime } = helpers;
  return items.map(item => `<tr class="clickable-row" data-task-id="${esc(item.assignmentId)}" tabindex="0">
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
  const { esc, subjectLabel, formatDateTime } = helpers;
  return items.map(item => `<tr class="clickable-row" data-folder-id="${esc(item.packageId)}" tabindex="0">
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
