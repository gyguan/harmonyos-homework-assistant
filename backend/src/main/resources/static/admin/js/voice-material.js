const AUDIO_EXTENSIONS = ['mp3', 'm4a', 'wav'];
const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'heic'];

export const SUBJECTS = [
  { code: 'CHINESE', label: '语文' },
  { code: 'MATH', label: '数学' },
  { code: 'ENGLISH', label: '英语' },
  { code: 'OTHER', label: '其他' }
];

function extension(name) {
  const index = name.lastIndexOf('.');
  return index < 0 ? '' : name.slice(index + 1).toLowerCase();
}

function resourceType(file) {
  const ext = extension(file.name);
  if (AUDIO_EXTENSIONS.includes(ext)) return 'AUDIO';
  if (IMAGE_EXTENSIONS.includes(ext)) return 'IMAGE';
  return '';
}

function normalizePath(file) {
  return (file.relativePath || file.webkitRelativePath || file.name).replaceAll('\\', '/');
}

function pathParts(file) {
  return normalizePath(file).split('/').filter(Boolean);
}

function buildSelectionContext(files) {
  const supported = files
    .filter(file => resourceType(file))
    .map(file => ({ file, parts: pathParts(file) }))
    .filter(item => item.parts.length > 1);
  const roots = new Set(supported.map(item => item.parts[0]));
  if (roots.size > 1) {
    return { multipleTopLevelRoots: true, singleRootIsPackage: false };
  }
  if (roots.size === 0) {
    return { multipleTopLevelRoots: false, singleRootIsPackage: false };
  }

  // A selected task folder normally contains its media files directly. When a selected
  // directory only contains child folders, treat those first-level children as packages so
  // selecting one common parent directory becomes a one-shot multi-folder import.
  const hasDirectSupportedFile = supported.some(item => item.parts.length === 2);
  return {
    multipleTopLevelRoots: false,
    singleRootIsPackage: hasDirectSupportedFile
  };
}

function packageLocation(file, context) {
  const parts = pathParts(file);
  if (parts.length <= 1) {
    return {
      key: 'selected-files',
      directoryName: '选择的素材',
      relativeName: file.name
    };
  }

  const root = parts[0];
  if (context.multipleTopLevelRoots || context.singleRootIsPackage) {
    return {
      key: root,
      directoryName: root,
      relativeName: parts.slice(1).join('/') || file.name
    };
  }

  const childDirectory = parts[1];
  if (!childDirectory || parts.length === 2) {
    return {
      key: root,
      directoryName: root,
      relativeName: file.name
    };
  }
  return {
    key: childDirectory,
    directoryName: childDirectory,
    relativeName: parts.slice(2).join('/') || file.name
  };
}

export function parseVoiceMaterialPackages(fileList, defaultSubjectCode, defaultMinutes) {
  const files = Array.from(fileList);
  const context = buildSelectionContext(files);
  const groups = new Map();
  let ignoredCount = 0;

  for (const file of files) {
    const type = resourceType(file);
    if (!type) {
      ignoredCount++;
      continue;
    }
    const location = packageLocation(file, context);
    if (!groups.has(location.key)) {
      groups.set(location.key, {
        key: location.key,
        directoryName: location.directoryName,
        subjectCode: defaultSubjectCode,
        expectedMinutes: defaultMinutes,
        selected: true,
        files: []
      });
    }
    groups.get(location.key).files.push({
      file,
      resourceType: type,
      relativeName: location.relativeName
    });
  }

  const packages = Array.from(groups.values());
  for (const item of packages) {
    item.files.sort((a, b) => {
      if (a.resourceType !== b.resourceType) return a.resourceType === 'AUDIO' ? -1 : 1;
      return a.relativeName.localeCompare(b.relativeName, 'zh-CN');
    });
  }
  packages.sort((a, b) => a.directoryName.localeCompare(b.directoryName, 'zh-CN'));
  return { packages, ignoredCount };
}

export function validatePackage(item) {
  const audioCount = item.files.filter(file => file.resourceType === 'AUDIO').length;
  const imageCount = item.files.filter(file => file.resourceType === 'IMAGE').length;
  if (audioCount === 0) return { valid: false, audioCount, imageCount, message: '缺少语音文件' };
  if (audioCount > 1) return { valid: false, audioCount, imageCount, message: '只能有 1 个语音文件' };
  if (imageCount === 0) return { valid: false, audioCount, imageCount, message: '至少需要 1 张图片' };
  if (!Number.isInteger(item.expectedMinutes) || item.expectedMinutes < 1 || item.expectedMinutes > 240) {
    return { valid: false, audioCount, imageCount, message: '预计用时需为 1～240 分钟' };
  }
  return { valid: true, audioCount, imageCount, message: '可以导入' };
}

export function uploadOrder(files) {
  let imageOrder = 1;
  return files.map(file => ({
    ...file,
    sortOrder: file.resourceType === 'AUDIO' ? 0 : imageOrder++
  }));
}
