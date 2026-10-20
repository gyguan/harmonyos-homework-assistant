package com.xiaoban.homework.organizer;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.Map;

/** Generic evidence checks only. One block can support zero, one or many assignments. */
final class HomeworkSourceEvidence {
  private HomeworkSourceEvidence() {}
  static HomeworkSourceDocument reconcileText(HomeworkSourceDocument original,
      List<HomeworkSourceDocument.Block> classified) {
    var byId = new LinkedHashMap<String, HomeworkSourceDocument.Block>();
    if (classified != null) for (var b : classified) if (b != null) byId.put(b.id(), b);
    return new HomeworkSourceDocument(2, "TEXT", original.originalText(), original.blocks().stream().map(b -> {
      var found = byId.get(b.id());
      String classification = found != null && b.text().equals(found.text())
          && List.of("TASK", "NON_TASK", "UNRESOLVED").contains(String.valueOf(found.classification()))
          ? found.classification() : "UNRESOLVED";
      return new HomeworkSourceDocument.Block(b.id(), b.text(), b.inputKind(), b.page(), b.imageIndex(),
          b.region(), b.legibility(), classification);
    }).toList());
  }
  static HomeworkOrganizerDtos.Response response(List<HomeworkOrganizerDtos.Candidate> items,
      String mode, HomeworkSourceDocument document) {
    var flags = flags(document, items);
    return new HomeworkOrganizerDtos.Response(items, mode, document, flags, !flags.isEmpty());
  }
  static List<HomeworkOrganizerDtos.QualityFlag> flags(HomeworkSourceDocument doc,
      List<HomeworkOrganizerDtos.Candidate> items) {
    var flags = new ArrayList<HomeworkOrganizerDtos.QualityFlag>();
    Map<String, HomeworkSourceDocument.Block> blocks = new LinkedHashMap<>();
    if (doc == null || doc.blocks().isEmpty()) add(flags, "SOURCE_EVIDENCE_UNAVAILABLE", List.of(), List.of());
    else for (var b : doc.blocks()) {
      if (b == null || b.id() == null || !b.id().matches("[A-Za-z0-9_-]{1,80}") || blocks.putIfAbsent(b.id(), b) != null) {
        add(flags, "INVALID_SOURCE_BLOCK", List.of(), List.of()); continue;
      }
      if (b.text() == null || b.text().isBlank() || !"READABLE".equals(b.legibility()))
        add(flags, "UNREADABLE_SOURCE", List.of(b.id()), List.of());
      if (b.imageIndex() != null && b.imageIndex() != 0)
        add(flags, "INVALID_SOURCE_LOCATION", List.of(b.id()), List.of());
      if (!b.region().isEmpty() && (b.region().size() != 4 || b.region().stream().anyMatch(
          v -> v == null || !Double.isFinite(v) || v < 0 || v > 1)))
        add(flags, "INVALID_SOURCE_LOCATION", List.of(b.id()), List.of());
    }
    var covered = new HashSet<String>();
    for (int i = 0; i < items.size(); i++) {
      var item = items.get(i);
      if (item.sourceBlockIds().isEmpty()) add(flags, "TASK_WITHOUT_EVIDENCE", List.of(), List.of(i));
      for (String id : item.sourceBlockIds()) {
        if (!blocks.containsKey(id)) add(flags, "UNKNOWN_SOURCE_REFERENCE", List.of(id), List.of(i));
        else {
          covered.add(id);
          if ("NON_TASK".equals(blocks.get(id).classification()))
            add(flags, "NON_TASK_CONTRADICTION", List.of(id), List.of(i));
        }
      }
    }
    for (var b : blocks.values()) {
      if (!List.of("TASK", "NON_TASK").contains(String.valueOf(b.classification())))
        add(flags, "UNCONFIRMED_SOURCE", List.of(b.id()), List.of());
      if (!covered.contains(b.id()) && !"NON_TASK".equals(b.classification()))
        add(flags, "POSSIBLE_OMISSION", List.of(b.id()), List.of());
    }
    flags.forEach(f -> HomeworkOrganizerTelemetry.flag(f.code()));
    return List.copyOf(flags);
  }
  static void add(List<HomeworkOrganizerDtos.QualityFlag> flags, String code, List<String> blocks, List<Integer> indexes) {
    flags.add(new HomeworkOrganizerDtos.QualityFlag(code, blocks, indexes));
  }
}
