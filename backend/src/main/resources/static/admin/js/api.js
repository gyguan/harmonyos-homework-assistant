const TOKEN_KEY = 'xiaoban.admin.token';

export function getToken() { return sessionStorage.getItem(TOKEN_KEY) || ''; }
export function setToken(token) { if (token) sessionStorage.setItem(TOKEN_KEY, token); else sessionStorage.removeItem(TOKEN_KEY); }

async function request(path, options = {}) {
  const headers = new Headers(options.headers || {});
  const token = getToken();
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (options.body && !(options.body instanceof FormData) && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  const response = await fetch(path, { ...options, headers });
  if (!response.ok) {
    let message = `请求失败（${response.status}）`;
    try { const body = await response.json(); message = body.message || body.detail || body.error || message; }
    catch { const text = await response.text().catch(() => ''); if (text) message = text; }
    const error = new Error(message); error.status = response.status; throw error;
  }
  if (response.status === 204) return null;
  const type = response.headers.get('content-type') || '';
  return type.includes('application/json') ? response.json() : response.text();
}

function query(path, filters = {}) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(filters)) {
    if (value !== undefined && value !== null && String(value) !== '') params.set(key, String(value));
  }
  return request(`${path}?${params.toString()}`);
}

export async function login(loginName, password) {
  const result = await request('/api/v1/auth/login', { method: 'POST', body: JSON.stringify({ loginName, password }) });
  setToken(result.token); return result;
}
export const session = () => request('/api/v1/auth/session');
export async function logout() { try { await request('/api/v1/auth/logout', { method: 'POST' }); } finally { setToken(''); } }
export const listStudents = () => request('/api/v1/students');

export const searchVoiceTasks = filters => query('/api/v1/voice-tasks', filters);
export const getVoiceTaskDetail = assignmentId => request(`/api/v1/voice-tasks/${encodeURIComponent(assignmentId)}`);
export const searchVoiceFolders = filters => query('/api/v1/voice-material-folders', filters);
export const getVoiceFolderDetail = packageId => request(`/api/v1/voice-material-folders/${encodeURIComponent(packageId)}`);

export const createVoiceMaterialBatch = studentId => request(`/api/v1/students/${encodeURIComponent(studentId)}/voice-material-batches`, { method: 'POST' });
export const registerVoiceMaterialPackage = (batchId, item) => request(`/api/v1/voice-material-batches/${encodeURIComponent(batchId)}/packages`, {
  method: 'POST', body: JSON.stringify({ directoryName: item.directoryName, subjectCode: item.subjectCode, title: '', expectedMinutes: item.expectedMinutes, dueAtEpochMs: 0, assignmentType: 'EXTRA' })
});
export async function uploadVoiceMaterialFile(packageId, item, sortOrder) {
  const form = new FormData(); form.append('file', item.file, item.file.name);
  const params = new URLSearchParams({ resourceType: item.resourceType, relativeName: item.relativeName, sortOrder: String(sortOrder) });
  return request(`/api/v1/voice-material-packages/${encodeURIComponent(packageId)}/files?${params.toString()}`, { method: 'POST', body: form });
}
export const completeVoiceMaterialBatch = batchId => request(`/api/v1/voice-material-batches/${encodeURIComponent(batchId)}/complete`, { method: 'POST' });
export const createVoiceMaterialAssignment = (packageId, payload) => request(`/api/v1/voice-material-packages/${encodeURIComponent(packageId)}/create-assignment`, { method: 'POST', body: JSON.stringify(payload) });

export async function fetchVoiceMaterialAsset(assetId) {
  const headers = new Headers(); const token = getToken(); if (token) headers.set('Authorization', `Bearer ${token}`);
  const response = await fetch(`/api/v1/media-assets/${encodeURIComponent(assetId)}`, { headers });
  if (!response.ok) throw new Error(`素材读取失败（${response.status}）`);
  return response.blob();
}

// Legacy compatibility for non-Web clients.
export const listVoiceMaterialPackages = studentId => request(`/api/v1/students/${encodeURIComponent(studentId)}/voice-material-packages`);
