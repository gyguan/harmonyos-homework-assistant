import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

export interface EncodedHomeworkImage {
  imageBase64: string;
  contentType: string;
  encodedBytes: number;
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
      // Keep supported original files intact, including all pixels and orientation metadata.
      // A global resize/JPEG pass can erase small print and cannot be assumed accuracy-neutral.
      let originalSize = fileIo.statSync(file.fd).size;
      let encoded: ArrayBuffer;
      let contentType: string = '';
      if (originalSize > 0 && originalSize <= 4 * 1024 * 1024) {
        let original = await HomeworkImageEncoder.readOriginal(file.fd, originalSize);
        let bytes = new Uint8Array(original);
        if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
          contentType = 'image/jpeg';
        } else if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 &&
          bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a &&
          bytes[6] === 0x1a && bytes[7] === 0x0a) {
          contentType = 'image/png';
        }
        encoded = original;
      } else {
        throw new Error('图片超过4MB，请选择清晰截图或裁剪所需区域后重试');
      }
      if (contentType.length === 0) {
        // Other SDK-readable formats are converted losslessly at their original dimensions.
        // Do not silently lower resolution or JPEG quality to meet the upload limit.
        pixelMap = await source.createPixelMap();
        packer = image.createImagePacker();
        let packing: image.PackingOption = { format: 'image/png', quality: 100 };
        try {
          encoded = await packer.packToData(pixelMap, packing);
        } catch {
          throw new Error('图片格式转换失败，请选择JPEG或PNG图片后重试');
        }
        contentType = 'image/png';
      }
      if (encoded.byteLength === 0 || encoded.byteLength > 4 * 1024 * 1024) {
        throw new Error('图片处理后超过4MB，请裁剪所需区域后重试');
      }
      let helper = new util.Base64Helper();
      return {
        imageBase64: await helper.encodeToString(new Uint8Array(encoded)),
        contentType: contentType,
        encodedBytes: encoded.byteLength
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

  private static async readOriginal(fd: number, size: number): Promise<ArrayBuffer> {
    let buffer = new ArrayBuffer(size);
    let result = new Uint8Array(buffer);
    let offset: number = 0;
    while (offset < size) {
      let chunk = new ArrayBuffer(Math.min(64 * 1024, size - offset));
      let count = await fileIo.read(fd, chunk, { offset: offset, length: chunk.byteLength });
      if (count <= 0 || count > chunk.byteLength) throw new Error('图片读取不完整，请重新选择后重试');
      result.set(new Uint8Array(chunk, 0, count), offset);
      offset += count;
    }
    return buffer;
  }

}
