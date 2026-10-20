package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import java.awt.image.BufferedImage;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.zip.CRC32;

/** Bounded IFD0 Orientation reader, JPEG APP1 and PNG eXIf. Never follows EXIF/GPS pointers.
 * CIPA DC-008, tag 0x0112: https://www.cipa.jp/std/documents/e/DC-008-2012_E.pdf
 * Pixel permutation only: no interpolation, scaling, sharpening, or business interpretation.
 */
final class HomeworkImageOrientation {
  private HomeworkImageOrientation() {}

  static int read(byte[] bytes, String contentType) {
    return "image/jpeg".equals(contentType) ? jpeg(bytes) : png(bytes);
  }

  private static int jpeg(byte[] data) {
    int offset = 2, result = 1;
    boolean seen = false;
    while (offset < data.length) {
      require((data[offset++] & 255) == 255);
      while (offset < data.length && (data[offset] & 255) == 255) offset++;
      require(offset < data.length);
      int marker = data[offset++] & 255;
      if (marker == 0xda || marker == 0xd9) break;
      if (marker == 1 || marker >= 0xd0 && marker <= 0xd7) continue;
      require(offset + 2 <= data.length);
      int length = (data[offset] & 255) * 256 + (data[offset + 1] & 255);
      require(length >= 2 && (long) offset + length <= data.length);
      if (marker == 0xe1 && length >= 8 && data[offset + 2] == 'E' && data[offset + 3] == 'x'
          && data[offset + 4] == 'i' && data[offset + 5] == 'f' && data[offset + 6] == 0 && data[offset + 7] == 0) {
        require(!seen); seen = true;
        result = tiff(data, offset + 8, offset + length);
      }
      offset += length;
    }
    return result;
  }

  private static int png(byte[] data) {
    int offset = 8, result = 1;
    boolean seen = false;
    while ((long) offset + 12 <= data.length) {
      long length = Integer.toUnsignedLong(ByteBuffer.wrap(data, offset, 4).getInt());
      require(length <= data.length - (long) offset - 12);
      int size = (int) length;
      if (data[offset + 4] == 'e' && data[offset + 5] == 'X' && data[offset + 6] == 'I' && data[offset + 7] == 'f') {
        require(!seen); seen = true;
        var crc = new CRC32(); crc.update(data, offset + 4, size + 4);
        require(crc.getValue() == Integer.toUnsignedLong(ByteBuffer.wrap(data, offset + 8 + size, 4).getInt()));
        result = tiff(data, offset + 8, offset + 8 + size);
      }
      offset += size + 12;
    }
    return result;
  }

  private static int tiff(byte[] data, int start, int end) {
    require(end - start >= 8);
    boolean little = data[start] == 'I' && data[start + 1] == 'I';
    require(little || data[start] == 'M' && data[start + 1] == 'M');
    var input = ByteBuffer.wrap(data).order(little ? ByteOrder.LITTLE_ENDIAN : ByteOrder.BIG_ENDIAN);
    require(Short.toUnsignedInt(input.getShort(start + 2)) == 42);
    long relative = Integer.toUnsignedLong(input.getInt(start + 4));
    require(relative >= 8 && relative <= end - (long) start - 2);
    int directory = start + (int) relative;
    int count = Short.toUnsignedInt(input.getShort(directory));
    require(directory + 2L + count * 12L + 4 <= end);
    int result = 1; boolean seen = false;
    for (int index = 0; index < count; index++) {
      int entry = directory + 2 + index * 12;
      if (Short.toUnsignedInt(input.getShort(entry)) != 0x0112) continue;
      require(!seen); seen = true;
      require(Short.toUnsignedInt(input.getShort(entry + 2)) == 3 && input.getInt(entry + 4) == 1);
      result = Short.toUnsignedInt(input.getShort(entry + 8));
      require(result >= 1 && result <= 8);
    }
    return result;
  }

  static BufferedImage upright(BufferedImage input, int orientation) {
    require(orientation >= 1 && orientation <= 8);
    if (orientation == 1) return input;
    int width = input.getWidth(), height = input.getHeight();
    var result = new BufferedImage(orientation >= 5 ? height : width,
        orientation >= 5 ? width : height, BufferedImage.TYPE_INT_ARGB);
    // Each decoded pixel is copied once; alpha and thin strokes are preserved exactly.
    for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
      int dx = switch (orientation) { case 2, 3 -> width - 1 - x; case 5, 8 -> y; case 6, 7 -> height - 1 - y; default -> x; };
      int dy = switch (orientation) { case 3, 4 -> height - 1 - y; case 5, 6 -> x; case 7, 8 -> width - 1 - x; default -> y; };
      result.setRGB(dx, dy, input.getRGB(x, y));
    }
    return result;
  }

  private static void require(boolean valid) {
    if (!valid) throw new ApiExceptions.BadRequest("图片方向信息不完整，请重新导出图片后重试");
  }
}
