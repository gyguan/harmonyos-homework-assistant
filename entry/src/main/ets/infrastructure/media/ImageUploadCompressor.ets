import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

/**
 * 上传前把图片压到「够清楚、又传得动」的尺寸。
 *
 * 背景：服务器出口（也是入口）带宽只有约 3Mbps，实测 377KB/s。
 * - 作业照片是相册原图（4160×3120 / 2.98MB），回看一张要等 8 秒；
 * - 语音素材的情景图是课本截图 PNG（2164×850 / 1.8MB 一张，一本 9 张 ≈ 11MB），
 *   老师上传和学生下载都要 30 秒以上。
 * 压到长边 2048 的照片约 500KB、长边 1600 的截图约 140KB（JPEG 实测），肉眼无差。
 *
 * 本地留存的副本仍然是原图（本机查看不受影响），只有上传的那一份是压缩件。
 */
export class ImageUploadCompressor {
  /** 作业照片：字迹要能放大看，长边给到 2048。 */
  static readonly PHOTO_MAX_SIDE: number = 2048;
  static readonly PHOTO_QUALITY: number = 85;
  /** 课本/作业截图：以文字为主，长边 1600 + q88 仍然锐利，体积约为原 PNG 的 1/13。 */
  static readonly PAGE_MAX_SIDE: number = 1600;
  static readonly PAGE_QUALITY: number = 88;
  /** 原图本来就小于这个体积、且长边没超限时，不再做一次有损重编码。 */
  private static readonly DEFAULT_SKIP_BYTES: number = 420 * 1024;

  /**
   * @returns 压缩后的临时文件路径；空字符串表示「直接用原图」
   * （无需压缩、或压缩失败——压缩失败绝不能挡住上传）。
   */
  static async compressToCache(
    context: common.UIAbilityContext,
    sourceUri: string,
    token: string,
    maxSide: number,
    quality: number,
    skipBytes: number = ImageUploadCompressor.DEFAULT_SKIP_BYTES
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
      if (longest <= maxSide && originalBytes <= skipBytes) return '';

      let ratio = Math.min(1, maxSide / longest);
      let options: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(width * ratio)),
          height: Math.max(1, Math.round(height * ratio))
        }
      };
      pixelMap = await imageSource.createPixelMap(options);
      packer = image.createImagePacker();

      destination = `${context.cacheDir}/image-upload-${token}.jpg`;
      destinationFile = await fileIo.open(destination,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      let packing: image.PackingOption = {
        format: 'image/jpeg',
        quality: quality
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
        // 压完反而更大（例如原图本就是小尺寸 JPEG）：保留原图，删掉临时件。
        ImageUploadCompressor.discard(destination);
        return '';
      }
      return destination;
    } catch {
      if (destination.length > 0) ImageUploadCompressor.discard(destination);
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

  /** 作业照片（长边 2048 / q85）。 */
  static async compressPhoto(context: common.UIAbilityContext,
    sourceUri: string, token: string): Promise<string> {
    return await ImageUploadCompressor.compressToCache(context, sourceUri, token,
      ImageUploadCompressor.PHOTO_MAX_SIDE, ImageUploadCompressor.PHOTO_QUALITY);
  }

  /** 课本/作业截图（长边 1600 / q88）。 */
  static async compressPage(context: common.UIAbilityContext,
    sourceUri: string, token: string): Promise<string> {
    return await ImageUploadCompressor.compressToCache(context, sourceUri, token,
      ImageUploadCompressor.PAGE_MAX_SIDE, ImageUploadCompressor.PAGE_QUALITY);
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
