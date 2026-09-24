import { getToken, login, session } from './api.js?v=20260924-1';

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

function setView(view) {
  const showLogin = view === 'login';
  loginView.hidden = !showLogin;
  adminView.hidden = showLogin;
  loginView.style.display = showLogin ? '' : 'none';
  adminView.style.display = showLogin ? 'none' : 'grid';
}

function setBusy(busy, message = '') {
  loginButton.disabled = busy;
  loginButton.textContent = busy ? '登录中…' : '登录';
  loginStatus.hidden = !message;
  loginStatus.textContent = message;
}

function showError(message = '') {
  loginError.hidden = !message;
  loginError.textContent = message;
}

function authErrorMessage(error) {
  if (error?.status === 401) {
    return '账号或密码错误。默认密码只在首次初始化数据库时创建；已有账号不会在重启时自动覆盖。';
  }
  return error?.message || '登录失败，请检查后端服务是否可访问。';
}

function publishAuthenticated(displayName) {
  const detail = { displayName: displayName || '家长' };
  window.__xiaobanAdminAuth = detail;
  el('account-name').textContent = detail.displayName;
  setBusy(false);
  showError('');
  setView('admin');
  window.dispatchEvent(new CustomEvent('xiaoban-admin-authenticated', { detail }));
}

async function handleLogin(event) {
  event.preventDefault();
  if (loginButton.disabled) return;
  setBusy(true, '正在验证账号…');
  showError('');
  try {
    const result = await login(el('login-name').value.trim(), el('login-password').value);
    publishAuthenticated(result.displayName);
  } catch (error) {
    setBusy(false);
    showError(authErrorMessage(error));
    setView('login');
  }
}

async function bootstrapLogin() {
  setView('login');
  setBusy(false);
  showError('');
  if (!getToken()) return;
  setBusy(true, '正在恢复登录状态…');
  try {
    const current = await session();
    publishAuthenticated(current.displayName);
  } catch {
    setBusy(false);
    showError('登录状态已失效，请重新登录。');
    setView('login');
  }
}

loginForm.addEventListener('submit', handleLogin);
void bootstrapLogin();
