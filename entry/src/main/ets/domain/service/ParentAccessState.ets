export class ParentAccessState {
  static readonly CLOUD_ENABLED: string = '__CLOUD_PARENT_ACCESS_ENABLED__';

  static isLegacyCode(value: string): boolean {
    if (value.length !== 4) return false;
    for (let i = 0; i < value.length; i++) {
      let code = value.charCodeAt(i);
      if (code < 48 || code > 57) return false;
    }
    return true;
  }

  static isEnabled(value: string): boolean {
    return value === ParentAccessState.CLOUD_ENABLED || ParentAccessState.isLegacyCode(value);
  }
}
