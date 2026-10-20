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

  record Inspection(int orientation, String status, byte[] bytes) {
    boolean uncertain() { return "IGNORED_INVALID".equals(status); }
  }

  static int read(byte[] bytes, String contentType) { return inspect(bytes, contentType).orientation(); }

  /** Orientation is optional metadata. Invalid EXIF cannot invalidate already decoded pixels. */
  static Inspection inspect(byte[] bytes, String contentType) {
    return "image/jpeg".equals(contentType) ? jpeg(bytes) : png(bytes);
  }

  private static Inspection jpeg(byte[] data) {
    int offset = 2;
    var scan = new Scan(data);
    while (offset < data.length) {
      int segmentStart = offset;
      container((data[offset++] & 255) == 255);
      while (offset < data.length && (data[offset] & 255) == 255) offset++;
      container(offset < data.length);
      int marker = data[offset++] & 255;
      if (marker == 0xda || marker == 0xd9) break;
      if (marker == 1 || marker >= 0xd0 && marker <= 0xd7) continue;
      container(offset + 2 <= data.length);
      int length = (data[offset] & 255) * 256 + (data[offset + 1] & 255);
      container(length >= 2 && (long) offset + length <= data.length);
      if (marker == 0xe1 && length >= 6 && exifPrefix(data, offset + 2, offset + length)) {
        scan.exif(segmentStart, offset + length, offset + 8, offset + length,
            length >= 8 && data[offset + 6] == 0 && data[offset + 7] == 0);
      }
      offset += length;
    }
    return scan.finish();
  }

  private static Inspection png(byte[] data) {
    int offset = 8;
    var scan = new Scan(data);
    while ((long) offset + 12 <= data.length) {
      long length = Integer.toUnsignedLong(ByteBuffer.wrap(data, offset, 4).getInt());
      container(length <= data.length - (long) offset - 12);
      int size = (int) length;
      if (data[offset + 4] == 'e' && data[offset + 5] == 'X' && data[offset + 6] == 'I' && data[offset + 7] == 'f') {
        var crc = new CRC32(); crc.update(data, offset + 4, size + 4);
        int start = offset + 8, end = start + size;
        // Some exporters copy the JPEG EXIF identifier into PNG eXIf. Accept the
        // identifier only when complete; it is not part of the TIFF byte order header.
        if (exifPrefix(data, start, end) && end - start >= 6 && data[start + 4] == 0 && data[start + 5] == 0) start += 6;
        scan.exif(offset, offset + size + 12, start, end,
            crc.getValue() == Integer.toUnsignedLong(ByteBuffer.wrap(data, end, 4).getInt()));
      }
      boolean end = data[offset + 4] == 'I' && data[offset + 5] == 'E' && data[offset + 6] == 'N' && data[offset + 7] == 'D';
      offset += size + 12;
      if (end) break; // Ignore exporter trailers after IEND, as the image decoder does.
    }
    return scan.finish();
  }

  private static boolean exifPrefix(byte[] data, int start, int end) {
    return end - start >= 4 && data[start] == 'E' && data[start + 1] == 'x' && data[start + 2] == 'i' && data[start + 3] == 'f';
  }

  private static final class Scan {
    private final byte[] original;
    private final java.io.ByteArrayOutputStream clean;
    private int copied, count, orientation = 1;
    private boolean invalid;
    Scan(byte[] bytes) { original = bytes; clean = new java.io.ByteArrayOutputStream(); }
    void exif(int segmentStart, int segmentEnd, int tiffStart, int tiffEnd, boolean intact) {
      // Strip only EXIF segments if any are invalid/ambiguous. Compressed image bytes,
      // XMP, color profiles and all other chunks remain byte-for-byte unchanged.
      clean.write(original, copied, segmentStart - copied); copied = segmentEnd;
      count++;
      if (!intact || count > 1) { invalid = true; return; }
      try { orientation = tiff(original, tiffStart, tiffEnd); }
      catch (InvalidMetadata ignored) { invalid = true; }
    }
    Inspection finish() {
      if (!invalid) return new Inspection(orientation, count == 0 ? "ABSENT" : "VALID", original);
      clean.write(original, copied, original.length - copied);
      return new Inspection(1, "IGNORED_INVALID", clean.toByteArray());
    }
  }

  private static int tiff(byte[] data, int start, int end) {
    metadata(end - start >= 8);
    boolean little = data[start] == 'I' && data[start + 1] == 'I';
    metadata(little || data[start] == 'M' && data[start + 1] == 'M');
    var input = ByteBuffer.wrap(data).order(little ? ByteOrder.LITTLE_ENDIAN : ByteOrder.BIG_ENDIAN);
    metadata(Short.toUnsignedInt(input.getShort(start + 2)) == 42);
    long relative = Integer.toUnsignedLong(input.getInt(start + 4));
    metadata(relative >= 8 && relative <= end - (long) start - 2);
    int directory = start + (int) relative;
    int count = Short.toUnsignedInt(input.getShort(directory));
    // IFD1/thumbnail/GPS pointers are unrelated to IFD0 Orientation. A missing
    // trailing next-directory pointer does not discard a complete Orientation entry.
    metadata(directory + 2L + count * 12L <= end);
    int result = 1; boolean seen = false;
    for (int index = 0; index < count; index++) {
      int entry = directory + 2 + index * 12;
      if (Short.toUnsignedInt(input.getShort(entry)) != 0x0112) continue;
      metadata(!seen); seen = true;
      metadata(Short.toUnsignedInt(input.getShort(entry + 2)) == 3 && input.getInt(entry + 4) == 1);
      result = Short.toUnsignedInt(input.getShort(entry + 8));
      metadata(result >= 1 && result <= 8);
    }
    return result;
  }

  private static void metadata(boolean valid) { if (!valid) throw new InvalidMetadata(); }
  private static final class InvalidMetadata extends RuntimeException {}
  private static void container(boolean valid) {
    if (!valid) throw new ApiExceptions.BadRequest("图片内容不完整，请重新选择图片后重试");
  }

  static BufferedImage upright(BufferedImage input, int orientation) {
    metadata(orientation >= 1 && orientation <= 8);
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

}
