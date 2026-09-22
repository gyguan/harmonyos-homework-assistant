import { common } from '@kit.AbilityKit';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';

export enum VoiceMaterialLocalResourceType {
  AUDIO = 'AUDIO',
  IMAGE = 'IMAGE'
}

export interface VoiceMaterialLocalFile {
  uri: string;
  name: string;
  resourceType: VoiceMaterialLocalResourceType;
}

export interface VoiceMaterialLocalPackage {
  directoryUri: string;
  directoryName: string;
  files: VoiceMaterialLocalFile[];
  subjectCode: string;
  expectedMinutes: number;
}

export class VoiceMaterialDirectoryPicker {
  static readonly instance: VoiceMaterialDirectoryPicker = new VoiceMaterialDirectoryPicker();
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async selectPackages(defaultSubjectCode: string, expectedMinutes: number):
    Promise<VoiceMaterialLocalPackage[]> {
    if (this.context === null) throw new Error('语音素材目录选择服务尚未初始化');

    let options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 200;
    options.fileSuffixFilters = [
      '语音与图片|.mp3,.m4a,.wav,.jpg,.jpeg,.png,.webp,.heic'
    ];
    options.selectMode = picker.DocumentSelectMode.FOLDER;
    options.allowsMulFolderSelection = true;

    try {
      let documentPicker = new picker.DocumentViewPicker(this.context);
      let uris = await documentPicker.select(options);
      return this.resolvePackages(uris, defaultSubjectCode, expectedMinutes);
    } catch {
      return [];
    }
  }

  private resolvePackages(uris: string[], defaultSubjectCode: string,
    expectedMinutes: number): VoiceMaterialLocalPackage[] {
    let byDirectory: Map<string, VoiceMaterialLocalPackage> =
      new Map<string, VoiceMaterialLocalPackage>();

    for (let uri of uris) {
      if (uri.length === 0) continue;
      let scanned = this.scanDirectory(uri, defaultSubjectCode, expectedMinutes);
      if (scanned !== null) {
        byDirectory.set(scanned.directoryUri, scanned);
        continue;
      }

      let file = this.localFile(uri);
      if (file === null) continue;
      let directoryUri = this.parentDirectoryUri(uri);
      if (directoryUri.length === 0) directoryUri = uri;
      let existing = byDirectory.get(directoryUri);
      if (existing === undefined) {
        existing = {
          directoryUri: directoryUri,
          directoryName: this.displayName(directoryUri, '语音素材目录'),
          files: [],
          subjectCode: defaultSubjectCode,
          expectedMinutes: expectedMinutes
        };
        byDirectory.set(directoryUri, existing);
      }
      if (!this.containsFile(existing.files, file.uri)) existing.files.push(file);
    }

    let result: VoiceMaterialLocalPackage[] = [];
    byDirectory.forEach((item: VoiceMaterialLocalPackage) => {
      item.files.sort((left: VoiceMaterialLocalFile, right: VoiceMaterialLocalFile) =>
        left.name.localeCompare(right.name));
      if (item.files.length > 0) result.push(item);
    });
    result.sort((left: VoiceMaterialLocalPackage, right: VoiceMaterialLocalPackage) =>
      left.directoryName.localeCompare(right.directoryName));
    return result;
  }

  private scanDirectory(uri: string, defaultSubjectCode: string,
    expectedMinutes: number): VoiceMaterialLocalPackage | null {
    try {
      let directory = new fileUri.FileUri(uri);
      let names = fileIo.listFileSync(directory.path);
      let files: VoiceMaterialLocalFile[] = [];
      for (let name of names) {
        let type = this.resourceType(name);
        if (type === null) continue;
        let childPath = this.joinPath(directory.path, name);
        let childUri = new fileUri.FileUri(childPath).toString();
        files.push({ uri: childUri, name: name, resourceType: type });
      }
      if (files.length === 0) return null;
      files.sort((left: VoiceMaterialLocalFile, right: VoiceMaterialLocalFile) =>
        left.name.localeCompare(right.name));
      return {
        directoryUri: uri,
        directoryName: directory.name.length > 0 ? directory.name : this.displayName(uri, '语音素材目录'),
        files: files,
        subjectCode: defaultSubjectCode,
        expectedMinutes: expectedMinutes
      };
    } catch {
      return null;
    }
  }

  private localFile(uri: string): VoiceMaterialLocalFile | null {
    let name = this.displayName(uri, '');
    let type = this.resourceType(name);
    if (name.length === 0 || type === null) return null;
    return { uri: uri, name: name, resourceType: type };
  }

  private resourceType(name: string): VoiceMaterialLocalResourceType | null {
    let lower = name.toLowerCase();
    if (lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.wav')) {
      return VoiceMaterialLocalResourceType.AUDIO;
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') ||
      lower.endsWith('.webp') || lower.endsWith('.heic')) {
      return VoiceMaterialLocalResourceType.IMAGE;
    }
    return null;
  }

  private parentDirectoryUri(uri: string): string {
    try {
      return new fileUri.FileUri(uri).getFullDirectoryUri();
    } catch {
      return '';
    }
  }

  private displayName(uri: string, fallback: string): string {
    try {
      let name = new fileUri.FileUri(uri).name;
      if (name.length > 0) return name;
    } catch {}
    let normalized = uri;
    let query = normalized.indexOf('?');
    if (query >= 0) normalized = normalized.substring(0, query);
    let slash = normalized.lastIndexOf('/');
    let name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    if (name.length === 0) return fallback;
    try { return decodeURIComponent(name); } catch { return name; }
  }

  private containsFile(files: VoiceMaterialLocalFile[], uri: string): boolean {
    for (let item of files) if (item.uri === uri) return true;
    return false;
  }

  private joinPath(parent: string, child: string): string {
    return parent.endsWith('/') ? parent + child : parent + '/' + child;
  }
}
