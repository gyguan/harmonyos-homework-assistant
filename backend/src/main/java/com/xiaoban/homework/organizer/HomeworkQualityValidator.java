package com.xiaoban.homework.organizer;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/** Flags structural/evidence risks; never rewrites, splits, merges, drops or interprets a task. */
public final class HomeworkQualityValidator {
  public enum Risk { LOW, MEDIUM, HIGH }
  public record Assessment(Risk risk, List<HomeworkOrganizerDtos.QualityFlag> flags,
      Set<String> blockIds, Set<Integer> assignmentIndexes, boolean reviewable) {}
  private static final Pattern NUMBER = Pattern.compile("[0-9]+(?:\\.[0-9]+)?");
  private static final Pattern MARKER = Pattern.compile("(?:^|(?<=[\\n\\s；;。：:，,]))\\s*[0-9]{1,2}\\s*[.、)）]|[①②③④⑤⑥⑦⑧⑨⑩]");
  private static final Set<String> HIGH = Set.of("POSSIBLE_OMISSION", "TASK_WITHOUT_EVIDENCE",
      "UNKNOWN_SOURCE_REFERENCE", "NON_TASK_CONTRADICTION", "UNSUPPORTED_NUMBER",
      "UNSUPPORTED_DATE", "SUBJECT_EVIDENCE_CONFLICT", "EXPERIENCE_APPLICATION_UNSUPPORTED");

  public Assessment validate(HomeworkSourceDocument doc, List<HomeworkOrganizerDtos.Candidate> items,
      HomeworkOrganizerDtos.ExperienceUsage usage) {
    var flags = new ArrayList<>(HomeworkSourceEvidence.flags(doc, items));
    var blocks = doc == null ? List.<HomeworkSourceDocument.Block>of() : doc.blocks();
    for (int i = 0; i < items.size(); i++) {
      var item = items.get(i);
      String source = String.join("\n", blocks.stream().filter(b -> item.sourceBlockIds().contains(b.id()))
          .map(HomeworkSourceDocument.Block::text).filter(java.util.Objects::nonNull).toList());
      if (!source.isBlank()) {
        String produced = item.title() + "\n" + item.instruction() + "\n" + item.textbookRef();
        var unsupported = numbers(produced); unsupported.removeAll(numbers(source));
        // Pure numeric ranges can support their intermediate integers, independent of task meaning.
        var ranges = Pattern.compile("([0-9]+)\\s*[-–~至到]\\s*([0-9]+)").matcher(source);
        while (ranges.find()) {
          try {
            int from = Integer.parseInt(ranges.group(1)), to = Integer.parseInt(ranges.group(2));
            if (to >= from && to - from <= 1000) for (long n = from; n <= to; n++) unsupported.remove(Long.toString(n));
          } catch (NumberFormatException oversized) { /* Not an enumerable numeric range. */ }
        }
        if (!unsupported.isEmpty()) add(flags, "UNSUPPORTED_NUMBER", item.sourceBlockIds(), List.of(i));
        if (!compact(source).contains(compact(item.sourceExcerpt())))
          add(flags, "EXCERPT_NOT_IN_SOURCE", item.sourceBlockIds(), List.of(i));
        var subjects = List.of("语文", "数学", "英语", "阅读", "朗读", "体育", "实践", "兴趣", "其他")
            .stream().filter(subject -> List.of("语文", "数学", "英语").contains(subject)
                ? source.contains(subject)
                : source.matches("(?s).*(?:^|[\\s；;。])" + Pattern.quote(subject) + "\\s*[:：].*")).toList();
        if (subjects.size() == 1 && !subjects.getFirst().equals(item.subject()))
          add(flags, "SUBJECT_EVIDENCE_CONFLICT", item.sourceBlockIds(), List.of(i));
      }
      String today = LocalDate.now(ZoneId.of("Asia/Shanghai")).toString();
      if (!today.equals(item.taskDate())) {
        String fullSource = doc == null ? "" : doc.readableText();
        LocalDate explicit = ConfigurableHomeworkOrganizerModelClient.candidateTaskDate(fullSource);
        if (!HomeworkOrganizerService.hasExplicitTaskDate(fullSource) || explicit == null || !explicit.toString().equals(item.taskDate()))
          add(flags, "UNSUPPORTED_DATE", item.sourceBlockIds(), List.of(i));
      }
      var markers = MARKER.matcher(item.instruction());
      int count = 0; while (markers.find()) count++;
      if (count > 1) add(flags, "POSSIBLE_MERGED_TASKS", item.sourceBlockIds(), List.of(i));
      for (int j = 0; j < i; j++) {
        var prior = items.get(j);
        if (prior.subject().equals(item.subject()) && prior.taskDate().equals(item.taskDate())
            && compact(prior.title()).equals(compact(item.title()))
            && compact(prior.instruction()).equals(compact(item.instruction())))
          add(flags, "POSSIBLE_DUPLICATE", item.sourceBlockIds(), List.of(j, i));
      }
    }
    if (usage != null && !usage.unsupportedAppliedExperienceIds().isEmpty())
      add(flags, "EXPERIENCE_APPLICATION_UNSUPPORTED", List.of(), List.of());
    var ids = new LinkedHashSet<String>(); var indexes = new LinkedHashSet<Integer>();
    flags.forEach(f -> { ids.addAll(f.sourceBlockIds()); indexes.addAll(f.assignmentIndexes()); });
    indexes.forEach(i -> { if (i >= 0 && i < items.size()) ids.addAll(items.get(i).sourceBlockIds()); });
    if (ids.isEmpty() || ids.stream().noneMatch(id -> blocks.stream().anyMatch(b -> id.equals(b.id()))))
      blocks.stream().filter(HomeworkQualityValidator::reliable).forEach(b -> ids.add(b.id()));
    // Only explicitly risky candidate indexes may change. Siblings sharing a block remain untouched.
    Set<String> reliableIds = new LinkedHashSet<>();
    blocks.stream().filter(HomeworkQualityValidator::reliable).filter(b -> ids.contains(b.id())).forEach(b -> reliableIds.add(b.id()));
    boolean substantive = flags.stream().anyMatch(f -> HIGH.contains(f.code())
        || Set.of("UNCONFIRMED_SOURCE", "EXCERPT_NOT_IN_SOURCE", "POSSIBLE_MERGED_TASKS", "POSSIBLE_DUPLICATE").contains(f.code()));
    Risk risk = flags.isEmpty() ? Risk.LOW : flags.stream().anyMatch(f -> HIGH.contains(f.code())) ? Risk.HIGH : Risk.MEDIUM;
    return new Assessment(risk, List.copyOf(flags), Set.copyOf(reliableIds), Set.copyOf(indexes), substantive && !reliableIds.isEmpty());
  }
  static boolean reliable(HomeworkSourceDocument.Block b) {
    return b != null && b.id() != null && b.id().matches("[A-Za-z0-9_-]{1,80}")
        && b.text() != null && !b.text().isBlank() && "READABLE".equals(b.legibility())
        && List.of("TEXT", "IMAGE").contains(String.valueOf(b.inputKind()))
        && (b.imageIndex() == null || b.imageIndex() == 0)
        && HomeworkSourceEvidence.validRegion(b.region());
  }
  static Set<String> numbers(String text) {
    var result = new HashSet<String>(); var matcher = NUMBER.matcher(text == null ? "" : text);
    while (matcher.find()) result.add(matcher.group());
    return result;
  }
  private static String compact(String value) { return value == null ? "" : value.replaceAll("\\s+", ""); }
  private static void add(List<HomeworkOrganizerDtos.QualityFlag> flags, String code, List<String> blocks, List<Integer> indexes) {
    var flag = new HomeworkOrganizerDtos.QualityFlag(code, blocks, indexes);
    if (!flags.contains(flag)) flags.add(flag);
  }
}
