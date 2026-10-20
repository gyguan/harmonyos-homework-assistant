package com.xiaoban.homework.organizer;

import java.util.ArrayList;
import java.util.List;

/** Evidence is independent of generated assignments. Pixels are never persisted here. */
public record HomeworkSourceDocument(int schemaVersion, String inputKind, String originalText,
    List<Block> blocks) {
  public HomeworkSourceDocument { blocks = blocks == null ? List.of() : List.copyOf(blocks); }
  public record Block(String id, String text, String inputKind, Integer page, Integer imageIndex,
      List<Double> region, String legibility, String classification) {
    public Block { region = region == null ? List.of() : List.copyOf(region); }
  }
  /** Only physical line boundaries; never classify, interpret or expand a business abbreviation. */
  static HomeworkSourceDocument text(String raw) {
    String source = raw == null ? "" : raw;
    var blocks = new ArrayList<Block>();
    for (String line : source.split("\\R", -1)) {
      if (!line.isBlank()) blocks.add(new Block("t" + (blocks.size() + 1), line,
          "TEXT", null, null, List.of(), "READABLE", "UNRESOLVED"));
    }
    return new HomeworkSourceDocument(2, "TEXT", source, blocks);
  }
  String readableText() {
    return String.join("\n", blocks.stream().map(Block::text).filter(java.util.Objects::nonNull).toList());
  }
}
