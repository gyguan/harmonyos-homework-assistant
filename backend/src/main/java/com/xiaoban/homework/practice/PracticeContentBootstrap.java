package com.xiaoban.homework.practice;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
public class PracticeContentBootstrap implements ApplicationRunner {
  private final PracticePaperRepository papers;
  private final PracticeQuestionRepository questions;
  private final ObjectMapper mapper;

  public PracticeContentBootstrap(PracticePaperRepository papers, PracticeQuestionRepository questions,
      ObjectMapper mapper) {
    this.papers = papers;
    this.questions = questions;
    this.mapper = mapper;
  }

  @Override
  public void run(ApplicationArguments args) {
    for (String grade : List.of("G1", "G2", "G3", "G4", "G5", "G6")) {
      seed(grade, "CHINESE");
      seed(grade, "MATH");
      seed(grade, "ENGLISH");
    }
  }

  private void seed(String grade, String subject) {
    String paperId = subject + "-" + grade + "-STARTER-001";
    String paperKey = paperId + "@1";
    PracticePaperEntity paper = papers.findByPaperIdAndVersion(paperId, 1).orElse(null);
    if (paper == null) {
      paper = new PracticePaperEntity();
      paper.paperKey = paperKey;
      paper.paperId = paperId;
      paper.version = 1;
      paper.grade = grade;
      paper.subject = subject;
      paper.title = title(subject);
      paper.description = gradeLabel(grade) + subjectLabel(subject) + "首批练习套卷，用于完成套卷作答闭环。";
      paper.difficulty = "L1";
      paper.questionCount = 10;
      paper.estimatedMinutes = "CHINESE".equals(subject) ? 20 : 15;
      paper.tagsJson = json(tags(subject));
      paper.sourceType = "PRESET";
      paper.status = "PUBLISHED";
      paper.createdAt = Instant.now();
      paper.updatedAt = paper.createdAt;
      papers.save(paper);
    }
    if (questions.countByPaperKey(paperKey) == 0) {
      questions.saveAll(createQuestions(paperKey, paperId, grade, subject));
    }
  }

  private List<PracticeQuestionEntity> createQuestions(
      String paperKey, String paperId, String grade, String subject) {
    if ("MATH".equals(subject)) return mathQuestions(paperKey, paperId, grade);
    if ("CHINESE".equals(subject)) return chineseQuestions(paperKey, paperId, grade);
    return englishQuestions(paperKey, paperId, grade);
  }

  private List<PracticeQuestionEntity> mathQuestions(String paperKey, String paperId, String grade) {
    int level = Integer.parseInt(grade.substring(1));
    List<PracticeQuestionEntity> result = new ArrayList<>();
    for (int i = 1; i <= 10; i++) {
      int a = level * 3 + i;
      int b = level + i;
      String stem;
      int answer;
      if (level <= 2) {
        stem = a + " + " + b + " = ?";
        answer = a + b;
      } else if (level <= 4) {
        stem = a + " × " + (2 + (i % 4)) + " = ?";
        answer = a * (2 + (i % 4));
      } else {
        stem = (a * 10) + " ÷ " + (2 + (i % 3)) + " = ?";
        int divisor = 2 + (i % 3);
        int dividend = divisor * (level * 5 + i);
        stem = dividend + " ÷ " + divisor + " = ?";
        answer = dividend / divisor;
      }
      result.add(question(paperKey, paperId, i, "NUMBER", stem, List.of(),
          Integer.toString(answer), "按运算顺序计算，结果是 " + answer + "。",
          List.of("先确认运算符。", "可以分步口算。"), List.of("计算")));
    }
    return result;
  }

  private List<PracticeQuestionEntity> chineseQuestions(String paperKey, String paperId, String grade) {
    String[][] items = {
      {"“认真”的近义词更接近哪一个？", "A", "仔细", "马虎", "忘记"},
      {"下面哪个词表示一种颜色？", "B", "奔跑", "金黄", "读书"},
      {"“安静”的反义词更接近哪一个？", "C", "平整", "清楚", "吵闹"},
      {"下面哪个词语搭配更自然？", "A", "明亮的教室", "明亮的声音", "明亮的味道"},
      {"“春风吹绿了小草”主要写的是哪个季节？", "B", "冬天", "春天", "秋天"},
      {"下面哪个词表示动作？", "C", "蓝色", "学校", "奔跑"},
      {"“我把书放进书包。”中的“书包”是什么？", "A", "物品", "动作", "时间"},
      {"下面哪一句标点使用更合适？", "B", "你好吗。", "你好吗？", "你好吗！。"},
      {"“太阳慢慢升起来了”中的“慢慢”表示什么？", "C", "地点", "人物", "速度"},
      {"下面哪个词可以形容天空？", "A", "晴朗", "香甜", "响亮"}
    };
    List<PracticeQuestionEntity> result = new ArrayList<>();
    for (int i = 0; i < items.length; i++) {
      String[] item = items[i];
      List<PracticeDtos.Option> options = List.of(
          new PracticeDtos.Option("A", item[2]),
          new PracticeDtos.Option("B", item[3]),
          new PracticeDtos.Option("C", item[4]));
      result.add(question(paperKey, paperId, i + 1, "SINGLE_CHOICE", item[0], options,
          item[1], "选择最符合题意的选项。",
          List.of("先读完整题目。", "逐个比较三个选项。"), List.of("语文基础")));
    }
    return result;
  }

  private List<PracticeQuestionEntity> englishQuestions(String paperKey, String paperId, String grade) {
    String[][] items = {
      {"Which word means “苹果”?", "A", "apple", "book", "dog"},
      {"Choose the greeting used in the morning.", "B", "Good night", "Good morning", "Goodbye"},
      {"Which word is a color?", "C", "run", "desk", "blue"},
      {"I ___ a student.", "A", "am", "is", "are"},
      {"Which word means “学校”?", "B", "family", "school", "water"},
      {"Choose the plural form of “book”.", "C", "bookes", "book's", "books"},
      {"She ___ my friend.", "A", "is", "am", "are"},
      {"Which one is an animal?", "B", "pencil", "cat", "yellow"},
      {"Choose the correct answer: How are you?", "C", "I'm ten.", "It's red.", "I'm fine."},
      {"Which word means “快乐的”?", "A", "happy", "small", "cold"}
    };
    List<PracticeQuestionEntity> result = new ArrayList<>();
    for (int i = 0; i < items.length; i++) {
      String[] item = items[i];
      List<PracticeDtos.Option> options = List.of(
          new PracticeDtos.Option("A", item[2]),
          new PracticeDtos.Option("B", item[3]),
          new PracticeDtos.Option("C", item[4]));
      result.add(question(paperKey, paperId, i + 1, "SINGLE_CHOICE", item[0], options,
          item[1], "根据词义或句型选择正确答案。",
          List.of("先读题干中的关键词。", "再比较三个选项。"), List.of("英语基础")));
    }
    return result;
  }

  private PracticeQuestionEntity question(String paperKey, String paperId, int orderNo,
      String type, String stem, List<PracticeDtos.Option> options, String answer,
      String explanation, List<String> hints, List<String> tags) {
    PracticeQuestionEntity question = new PracticeQuestionEntity();
    question.id = paperId + "-Q" + String.format("%02d", orderNo);
    question.paperKey = paperKey;
    question.orderNo = orderNo;
    question.questionType = type;
    question.stem = stem;
    question.optionsJson = json(options);
    question.answerSpec = answer;
    question.explanation = explanation;
    question.hintsJson = json(hints);
    question.tagsJson = json(tags);
    return question;
  }

  private String json(Object value) {
    try {
      return mapper.writeValueAsString(value);
    } catch (Exception e) {
      throw new IllegalStateException("无法初始化练习题库", e);
    }
  }

  private String title(String subject) {
    if ("CHINESE".equals(subject)) return "语文基础训练卷";
    if ("MATH".equals(subject)) return "数学基础训练卷";
    return "英语基础训练卷";
  }

  private String subjectLabel(String subject) {
    if ("CHINESE".equals(subject)) return "语文";
    if ("MATH".equals(subject)) return "数学";
    return "英语";
  }

  private String gradeLabel(String grade) {
    return switch (grade) {
      case "G1" -> "一年级";
      case "G2" -> "二年级";
      case "G3" -> "三年级";
      case "G4" -> "四年级";
      case "G5" -> "五年级";
      default -> "六年级";
    };
  }

  private List<String> tags(String subject) {
    if ("CHINESE".equals(subject)) return List.of("字词", "阅读");
    if ("MATH".equals(subject)) return List.of("计算", "应用");
    return List.of("词汇", "句型");
  }
}
