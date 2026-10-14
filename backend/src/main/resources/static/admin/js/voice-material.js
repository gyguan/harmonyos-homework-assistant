const AUDIO_EXTENSIONS = ['mp3', 'm4a', 'wav'];
const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'heic'];
// Loose files (dropped without a folder, or legacy single-file picks) are grouped under this key.
const LOOSE_DIRECTORY_PATH = '';
const LOOSE_DIRECTORY_KEY = 'selected-files';
const LOOSE_DIRECTORY_LABEL = '直接选择的素材文件';

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

/** Stable identity so the same file picked twice (or via two roots) is only counted once. */
export function fileIdentity(file) {
  return [normalizePath(file), file.name, file.size ?? -1, file.lastModified ?? -1].join('|');
}

/** Directory order keeps every parent immediately before its own subtree. */
function compareDirectoryPath(a, b) {
  const left = a.path.split('/');
  const right = b.path.split('/');
  const shared = Math.min(left.length, right.length);
  for (let index = 0; index < shared; index++) {
    const result = left[index].localeCompare(right[index], 'zh-CN', { numeric: true });
    if (result !== 0) return result;
  }
  return left.length - right.length;
}

function comparePackageFiles(a, b) {
  if (a.resourceType !== b.resourceType) return a.resourceType === 'AUDIO' ? -1 : 1;
  return a.relativeName.localeCompare(b.relativeName, 'zh-CN', { numeric: true });
}

/**
 * 把一次选择（或一次拖拽）里的文件展开成完整的目录层级。
 *
 * 浏览器只允许一次选择一个目录，但会返回它下面的整棵子树，因此这里把每个中间目录都列出来，
 * 由调用方（或用户）决定哪一层才是真正的素材目录。每个目录的 audio/image 计数是**整棵子树**的，
 * 这样深层嵌套（父/日期/学科/文件）也能被正确识别，不再假设素材一定在固定层级。
 */
export function analyzeVoiceMaterialSelection(fileList) {
  const nodes = new Map();
  let ignoredCount = 0;

  for (const file of Array.from(fileList || [])) {
    const type = resourceType(file);
    if (!type) {
      ignoredCount++;
      continue;
    }
    const parts = pathParts(file);
    if (parts.length <= 1) continue;
    const directPath = parts.slice(0, parts.length - 1).join('/');
    for (let depth = 1; depth < parts.length; depth++) {
      const path = parts.slice(0, depth).join('/');
      let node = nodes.get(path);
      if (!node) {
        node = {
          path,
          depth,
          name: parts[depth - 1],
          parentPath: depth > 1 ? parts.slice(0, depth - 1).join('/') : '',
          audioCount: 0,
          imageCount: 0,
          childDirectoryCount: 0,
          suggested: false
        };
        nodes.set(path, node);
      }
      if (type === 'AUDIO') node.audioCount++; else node.imageCount++;
      if (path === directPath) {
        if (type === 'AUDIO') node.directAudioCount = (node.directAudioCount || 0) + 1;
        else node.directImageCount = (node.directImageCount || 0) + 1;
      }
    }
  }

  for (const node of nodes.values()) {
    if (!node.parentPath) continue;
    const parent = nodes.get(node.parentPath);
    if (parent) parent.childDirectoryCount++;
  }

  const directories = Array.from(nodes.values()).sort(compareDirectoryPath);
  const suggested = new Set(defaultSelectionPaths(directories));
  for (const node of directories) node.suggested = suggested.has(node.path);
  return { directories, ignoredCount };
}

/**
 * 默认勾选规则：整棵子树里"只有 1 个语音文件、且至少有 1 张图片"的**最深**目录。
 *
 * - 一个目录的子树里出现 2 个以上语音，说明它装的是多个素材包，应该继续往下选；
 * - 从深到浅遍历，一旦某个目录已经构成合法素材包，它的上级目录就不再默认勾选，
 *   避免父目录和子目录被重复导入；
 * - 因此 `父/01语文`、`父/日期/语文`、只有一层素材目录、素材分散在 audio/img 子目录、
 *   甚至整个子树只有一个素材包，都能落到正确的那一层。
 */
export function defaultSelectionPaths(directories) {
  const ordered = directories.slice().sort((a, b) => b.depth - a.depth);
  const picked = [];
  for (const node of ordered) {
    if (node.audioCount !== 1 || node.imageCount < 1) continue;
    if (picked.some(path => path.startsWith(`${node.path}/`))) continue;
    picked.push(node.path);
  }
  return picked;
}

/**
 * 取某个目录下（含更深层子目录）的全部素材文件，relativeName 相对该目录，
 * 因此深层目录里的文件会保留 `子目录/文件名` 的嵌套相对路径。
 */
export function collectDirectoryFiles(directoryPath, fileList) {
  const depth = directoryPath ? directoryPath.split('/').length : 0;
  const files = [];
  for (const file of Array.from(fileList || [])) {
    const type = resourceType(file);
    if (!type) continue;
    const parts = pathParts(file);
    const fileDirectory = parts.slice(0, parts.length - 1).join('/');
    if (!directoryPath) {
      if (!fileDirectory) files.push({ file, resourceType: type, relativeName: file.name });
      continue;
    }
    if (fileDirectory !== directoryPath && !fileDirectory.startsWith(`${directoryPath}/`)) continue;
    files.push({ file, resourceType: type, relativeName: parts.slice(depth).join('/') || file.name });
  }
  return files;
}

function createRow(directory, fileList, defaults) {
  const path = directory ? directory.path : LOOSE_DIRECTORY_PATH;
  const files = collectDirectoryFiles(path, fileList).sort(comparePackageFiles);
  return {
    key: path || LOOSE_DIRECTORY_KEY,
    path,
    depth: directory ? directory.depth : 1,
    name: directory ? directory.name : LOOSE_DIRECTORY_LABEL,
    parentPath: directory ? directory.parentPath : '',
    directoryName: path || LOOSE_DIRECTORY_LABEL,
    childDirectoryCount: directory ? directory.childDirectoryCount : 0,
    suggested: directory ? directory.suggested : true,
    selected: false,
    subjectCode: defaults.subjectCode,
    expectedMinutes: defaults.minutes,
    audioCount: files.filter(file => file.resourceType === 'AUDIO').length,
    imageCount: files.filter(file => file.resourceType === 'IMAGE').length,
    files
  };
}

/** 目录层级 + 散落文件 → 待导入行（默认勾选规则已写入 suggested，最终勾选态由调用方决定）。 */
export function buildVoiceMaterialRows(analysis, fileList, defaults) {
  const rows = analysis.directories.map(directory => createRow(directory, fileList, defaults));
  const hasLooseFiles = collectDirectoryFiles(LOOSE_DIRECTORY_PATH, fileList).length > 0;
  if (hasLooseFiles) rows.push(createRow(null, fileList, defaults));
  return rows;
}

/** 有多少素材文件没有落在任何已选目录里（用于提示用户还有内容没被导入）。 */
export function unassignedSupportedCount(fileList, selectedPaths) {
  const selected = Array.from(selectedPaths || []);
  let count = 0;
  for (const file of Array.from(fileList || [])) {
    if (!resourceType(file)) continue;
    const parts = pathParts(file);
    const fileDirectory = parts.slice(0, parts.length - 1).join('/');
    const covered = selected.some(path => path === LOOSE_DIRECTORY_PATH
      ? fileDirectory === LOOSE_DIRECTORY_PATH
      : fileDirectory === path || fileDirectory.startsWith(`${path}/`));
    if (!covered) count++;
  }
  return count;
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
