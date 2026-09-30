import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

export interface EncodedHomeworkImage {
  imageBase64: string;
  contentType: string;
}

export class HomeworkImageEncoder {
  static async encode(uri: string): Promise<EncodedHomeworkImage> {
    let file: fileIo.File | null = null;
    let source: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      try {
        file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
      } catch {
        throw new Error('无法读取所选图片，请重新选择后重试');
      }

      source = image.createImageSource(file.fd);
      let info = await source.getImageInfo();
      let width = info.size.width;
      let height = info.size.height;
      if (width <= 0 || height <= 0 || width * height > 40000000) {
        throw new Error('图片尺寸过大，请换一张截图重试');
      }
      let ratio = Math.min(1, 3072 / Math.max(width, height));
      let options: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(width * ratio)),
          height: Math.max(1, Math.round(height * ratio))
        }
      };
      pixelMap = await source.createPixelMap(options);
      packer = image.createImagePacker();
      let packing: image.PackingOption = { format: 'image/jpeg', quality: 90 };
      let encoded = await packer.packToData(pixelMap, packing);
      if (encoded.byteLength === 0 || encoded.byteLength > 4 * 1024 * 1024) {
        throw new Error('图片处理后超过4MB，请裁剪后重试');
      }
      let helper = new util.Base64Helper();
      return {
        imageBase64: await helper.encodeToString(new Uint8Array(encoded)),
        contentType: 'image/jpeg'
      };
    } finally {
      // Resource cleanup is best effort and must preserve the parse result or primary error.
      if (packer !== null) {
        try { await packer.release(); } catch { console.warn('Homework image packer cleanup failed'); }
      }
      if (pixelMap !== null) {
        try { await pixelMap.release(); } catch { console.warn('Homework image pixel cleanup failed'); }
      }
      if (source !== null) {
        try { await source.release(); } catch { console.warn('Homework image source cleanup failed'); }
      }
      if (file !== null) {
        try { await fileIo.close(file); } catch { console.warn('Homework image file cleanup failed'); }
      }
    }
  }
}
