export class AppConfig {
  // No built-in plaintext public endpoint. Existing saved server settings remain
  // in BackendSession preferences; new installs configure their own HTTPS backend.
  static readonly BACKEND_BASE_URL: string = '';
}
