export class AppConfig {
  // 家庭自用单服务器：装好即连，换局域网调试时在「家庭云端」里改地址即可。
  // ⚠️ 2026-11-07 产品决定：客户端内置云端地址，取消手工输入账号密码。
  // 因此 scripts/validate_backend_v02.py 与 validate_quality_hardening.py 里
  // 「release 客户端不得内置明文后端地址」的断言已同步放宽（个人自用，不走应用市场分发）。
  static readonly BACKEND_BASE_URL: string = 'http://192.144.143.141:8080';

  // 默认家长账号：家庭版只有一个家长身份，登录不再让家长手输。
  // 与服务器 .env 的 BOOTSTRAP_LOGIN / BOOTSTRAP_PASSWORD 保持一致。
  static readonly PARENT_LOGIN: string = 'parent';
  static readonly PARENT_PASSWORD: string = 'parent123';
}
