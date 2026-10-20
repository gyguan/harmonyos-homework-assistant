package com.xiaoban.homework.organizer;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import javax.imageio.ImageIO;
import javax.imageio.stream.MemoryCacheImageInputStream;

/** Exact outward-rounded crop of an independently located unclear block. Never replaces pass one. */
final class HomeworkImageCrop {
  record Crop(String dataUrl, int width, int height, int bytes) {}

  static Optional<HomeworkSourceDocument.Block> target(HomeworkSourceDocument doc,
      List<HomeworkOrganizerDtos.Candidate> initial) {
    if (doc == null || doc.schemaVersion() < 2 || !"IMAGE".equals(doc.inputKind())
        || doc.blocks().stream().map(HomeworkSourceDocument.Block::id).distinct().count() != doc.blocks().size()) return Optional.empty();
    return doc.blocks().stream().filter(b -> "IMAGE".equals(b.inputKind()) && Integer.valueOf(0).equals(b.imageIndex())
        && b.id() != null && b.id().matches("[A-Za-z0-9_-]{1,80}")
        && ("UNCLEAR".equals(b.legibility()) || b.text() == null || b.text().isBlank())
        && List.of("UNRESOLVED", "TASK").contains(String.valueOf(b.classification()))
        && b.region().size() == 4 && HomeworkSourceEvidence.validRegion(b.region())
        && b.region().get(2) * b.region().get(3) <= .5
        // A candidate spanning an unrelated source cannot be safely changed using this crop alone.
        && initial.stream().noneMatch(c -> c.sourceBlockIds().contains(b.id()) && c.sourceBlockIds().stream().anyMatch(id -> !id.equals(b.id()))))
        .findFirst();
  }

  static Crop prepare(String dataUrl, HomeworkSourceDocument.Block block) throws Exception {
    if (!dataUrl.startsWith("data:image/png;base64,") && !dataUrl.startsWith("data:image/jpeg;base64,"))
      throw new IllegalArgumentException("Unsupported image input");
    byte[] raw = Base64.getDecoder().decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
    if (raw.length > HomeworkImageInput.MAX_BYTES) throw new IllegalArgumentException("Image input too large");
    try (var input = new MemoryCacheImageInputStream(new ByteArrayInputStream(raw))) {
      var readers = ImageIO.getImageReaders(input);
      if (!readers.hasNext()) throw new IllegalArgumentException("Image unavailable");
      var reader = readers.next();
      try {
        reader.setInput(input, true, true);
        int width = reader.getWidth(0), height = reader.getHeight(0);
        if (width <= 0 || height <= 0 || (long) width * height > 40_000_000) throw new IllegalArgumentException("Image dimensions out of bounds");
        var r = block.region();
        int left = (int)Math.floor(r.get(0) * width), top = (int)Math.floor(r.get(1) * height);
        int right = Math.min(width,(int)Math.ceil((r.get(0)+r.get(2)) * width));
        int bottom = Math.min(height,(int)Math.ceil((r.get(1)+r.get(3)) * height));
        if (right <= left || bottom <= top || (long)(right-left)*(bottom-top) > 4_000_000)
          throw new IllegalArgumentException("Crop dimensions out of bounds");
        // Decode only the required pixel rectangle where supported by the installed image reader.
        var options = reader.getDefaultReadParam();
        options.setSourceRegion(new java.awt.Rectangle(left,top,right-left,bottom-top));
        BufferedImage image = reader.read(0,options);
        try {
          byte[] png = HomeworkImageInput.encodePng(image, HomeworkImageInput.MAX_BYTES);
          return new Crop("data:image/png;base64,"+Base64.getEncoder().encodeToString(png),
              image.getWidth(),image.getHeight(),png.length);
        } finally { if (image != null) image.flush(); }
      } finally { reader.dispose(); }
    }
  }
}
