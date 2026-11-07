import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

/**
 * 提交作业前把照片压到「够清楚、又下得动」的尺寸。
 *
 * 背景：作业照片原本是相册原图（实测 4160×3120 / 2.98MB），而服务器出口带宽只有
 * 约 3Mbps（实测 377KB/s），家长回看时一张图要等 8 秒。压到长边 2048 后同一张图
 * 约 500KB，字迹放大依旧清楚，等待时间降到 1.5 秒以内。
 *
 * 本地留存的副本仍然是原图（拍照/批阅在本机看原图），只有上传的那一份是压缩件。
 */
const UPLOAD_MAX_SIDE: number = 2048;
const UPLOAD_QUALITY: number = 85;
/** 原图本来就小于这个体积、且长边没超限时，不再做一次有损重编码。 */
const UPLOAD_SKIP_BYTES: number = 420 * 1024;

export class SubmissionPhotoCompressor {
  /**
   * @returns 压缩后的临时文件路径；空字符串表示「直接用原图」
   * （无需压缩、或压缩失败——压缩失败绝不能挡住提交）。
   */
  static async compressToCache(
    context: common.UIAbilityContext,
    sourceUri: string,
    token: string
  ): Promise<string> {
    let sourceFile: fileIo.File | null = null;
    let imageSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    let destination: string = '';
    let destinationFile: fileIo.File | null = null;
    try {
      sourceFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      let originalBytes = fileIo.statSync(sourceFile.fd).size;
      imageSource = image.createImageSource(sourceFile.fd);
      let info: image.ImageInfo = await imageSource.getImageInfo(0);
      let width = info.size.width;
      let height = info.size.height;
      if (width <= 0 || height <= 0) return '';
      let longest = Math.max(width, height);
      if (longest <= UPLOAD_MAX_SIDE && originalBytes <= UPLOAD_SKIP_BYTES) return '';

      let ratio = Math.min(1, UPLOAD_MAX_SIDE / longest);
      let options: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(width * ratio)),
          height: Math.max(1, Math.round(height * ratio))
        }
      };
      pixelMap = await imageSource.createPixelMap(options);
      packer = image.createImagePacker();

      destination = `${context.cacheDir}/submission-upload-${token}.jpg`;
      destinationFile = await fileIo.open(destination,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      let packing: image.PackingOption = {
        format: 'image/jpeg',
        quality: UPLOAD_QUALITY
      };
      await packer.packToFile(pixelMap, destinationFile.fd, packing);
      try {
        await fileIo.close(destinationFile);
      } catch {
        // 关闭失败不影响已写入的内容，下面用 stat 判断结果。
      }
      destinationFile = null;

      let compressedBytes = fileIo.statSync(destination).size;
      if (compressedBytes <= 0 || compressedBytes >= originalBytes) {
        // 压完反而更大（例如原图本就是小截图）：保留原图，删掉临时件。
        SubmissionPhotoCompressor.discard(destination);
        return '';
      }
      return destination;
    } catch {
      if (destination.length > 0) SubmissionPhotoCompressor.discard(destination);
      return '';
    } finally {
      if (destinationFile !== null) {
        try { await fileIo.close(destinationFile); } catch { }
      }
      if (packer !== null) {
        try { await packer.release(); } catch { }
      }
      if (pixelMap !== null) {
        try { await pixelMap.release(); } catch { }
      }
      if (imageSource !== null) {
        try { await imageSource.release(); } catch { }
      }
      if (sourceFile !== null) {
        try { await fileIo.close(sourceFile); } catch { }
      }
    }
  }

  /** 删除上传用的临时压缩件；失败无所谓，cacheDir 会被系统回收。 */
  static discard(path: string): void {
    if (path.length === 0) return;
    try {
      fileIo.unlinkSync(path);
    } catch {
      // 删不掉就留着，下一次启动的孤儿清理会处理。
    }
  }
}
