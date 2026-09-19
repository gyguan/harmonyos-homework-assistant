export class AppConfig {
  // 默认后端地址：腾讯云轻量服务器上的生产环境（见 backend/DEPLOY.md）
  // 用户也可在「设置 → 后端连接」里改成自建地址
  static readonly BACKEND_BASE_URL: string = 'http://192.144.143.141:8080';
}
