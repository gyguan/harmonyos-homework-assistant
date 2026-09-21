import { ImportedMessage } from '../../domain/model/ImportModels';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';
import {
  ClassifiedHomeworkMessage,
  HomeworkMessageClassification,
  HomeworkMessageGroup,
  HomeworkTaskDraft,
  HomeworkUnderstandingConfig,
  HomeworkUnderstandingResult,
  TeacherResolutionStatus
} from '../../domain/model/HomeworkUnderstandingModels';
import { DeterministicHomeworkClassifier } from './DeterministicHomeworkClassifier';
import { DeterministicHomeworkContextGrouper } from './DeterministicHomeworkContextGrouper';
import { DeterministicHomeworkRevisionResolver } from './DeterministicHomeworkRevisionResolver';
import { DeterministicHomeworkTaskExtractor } from './DeterministicHomeworkTaskExtractor';
import { DeterministicTeacherResolver } from './DeterministicTeacherResolver';

export class HomeworkUnderstandingPipeline {
  private readonly teacherResolver: DeterministicTeacherResolver = new DeterministicTeacherResolver();
  private readonly classifier: DeterministicHomeworkClassifier = new DeterministicHomeworkClassifier();
  private readonly grouper: DeterministicHomeworkContextGrouper = new DeterministicHomeworkContextGrouper();
  private readonly extractor: DeterministicHomeworkTaskExtractor = new DeterministicHomeworkTaskExtractor();
  private readonly revisionResolver: DeterministicHomeworkRevisionResolver =
    new DeterministicHomeworkRevisionResolver(this.extractor);

  understand(batchId: string, studentId: string, sourceLabel: string, sourceType: string,
    messages: ImportedMessage[], config: HomeworkUnderstandingConfig): HomeworkUnderstandingResult {
    let classified: ClassifiedHomeworkMessage[] = [];
    let pendingReviewMessageIds: string[] = [];
    let warnings: string[] = [];

    let ordered: ImportedMessage[] = [];
    for (let message of messages) ordered.push(message);
    ordered.sort((left: ImportedMessage, right: ImportedMessage) => left.orderNo - right.orderNo);

    for (let message of ordered) {
      let teacher = this.teacherResolver.resolve(message.sender, config);
      let classification = this.classifier.classify(message, teacher);
      let confidence = this.classifier.confidence(classification, teacher);
      classified.push({
        message: message,
        teacher: teacher,
        classification: classification,
        confidence: confidence
      });
      if (classification === HomeworkMessageClassification.UNKNOWN) {
        pendingReviewMessageIds.push(message.id);
        if (teacher.status === TeacherResolutionStatus.UNKNOWN) {
          this.addWarning(warnings, `UNKNOWN_SENDER:${message.sender.length > 0 ? message.sender : message.id}`);
        }
      }
    }

    let groups = this.grouper.group(classified);
    let tasks: HomeworkTaskDraft[] = [];
    for (let group of groups) {
      let groupTasks = this.processGroup(group, warnings);
      for (let task of groupTasks) tasks.push(task);
    }

    let candidates: CandidateAssignment[] = [];
    for (let i = 0; i < tasks.length; i++) {
      candidates.push(this.toCandidate(
        batchId, studentId, sourceLabel, sourceType, tasks[i], ordered, i + 1));
    }

    return {
      candidates: candidates,
      classifiedMessages: classified,
      pendingReviewMessageIds: pendingReviewMessageIds,
      warnings: warnings
    };
  }

  private processGroup(group: HomeworkMessageGroup, warnings: string[]): HomeworkTaskDraft[] {
    let homeworkTasks: HomeworkTaskDraft[] = [];
    let preparationTasks: HomeworkTaskDraft[] = [];

    for (let item of group.messages) {
      if (item.classification === HomeworkMessageClassification.HOMEWORK) {
        let extracted = this.extractor.extractHomework(
          item.message.text, group.subject, item.message.id, item.confidence);
        for (let task of extracted) homeworkTasks.push(task);
        if (extracted.length === 0) this.addWarning(warnings, `TASK_EXTRACTION_EMPTY:${item.message.id}`);
      } else if (item.classification === HomeworkMessageClassification.PREPARATION) {
        let prepared = this.extractor.extractPreparation(
          item.message.text, group.subject, item.message.id, item.confidence);
        for (let task of prepared) preparationTasks.push(task);
      } else if (item.classification === HomeworkMessageClassification.HOMEWORK_REVISION) {
        let resolved = this.revisionResolver.apply(
          homeworkTasks, item.message.text, group.subject, item.message.id, item.confidence);
        homeworkTasks = resolved.tasks;
        for (let warning of resolved.warnings) {
          this.addWarning(warnings, `${warning}:${item.message.id}`);
        }
      }
    }

    let result: HomeworkTaskDraft[] = [];
    for (let task of homeworkTasks) result.push(task);
    for (let task of preparationTasks) result.push(task);
    return result;
  }

  private toCandidate(batchId: string, studentId: string, sourceLabel: string, sourceType: string,
    task: HomeworkTaskDraft, messages: ImportedMessage[], sequence: number): CandidateAssignment {
    let rawTextParts: string[] = [];
    let capturedAt = 0;
    for (let messageId of task.sourceMessageIds) {
      let message = this.findMessage(messages, messageId);
      if (message === null) continue;
      if (message.text.length > 0) rawTextParts.push(message.text);
      let sourceTime = message.sourceEvidence.capturedAtEpochMs;
      if (sourceTime > 0 && (capturedAt === 0 || sourceTime < capturedAt)) capturedAt = sourceTime;
    }
    let rawText = rawTextParts.join('\n');
    return {
      id: `understanding-${batchId}-${sequence}`,
      studentId: studentId,
      subject: task.subject,
      title: task.title,
      instruction: task.instruction,
      textbookRef: this.textbookRef(task.subject, task.title),
      dueText: task.dueText,
      expectedMinutes: task.expectedMinutes,
      sourceEvidence: {
        sourceLabel: sourceLabel,
        excerpt: rawText.length > 0 ? rawText : task.title,
        batchId: batchId,
        sourceType: sourceType,
        sourceMessageIds: task.sourceMessageIds.slice(),
        rawText: rawText,
        imageRef: '',
        capturedAtEpochMs: capturedAt
      },
      confidence: task.confidence
    };
  }

  private findMessage(messages: ImportedMessage[], messageId: string): ImportedMessage | null {
    for (let message of messages) if (message.id === messageId) return message;
    return null;
  }

  private textbookRef(subject: Subject, title: string): string {
    let base = subject === Subject.CHINESE ? '部编版' :
      (subject === Subject.MATH ? '北师大版' :
        (subject === Subject.ENGLISH ? '沪教版' : '待家长确认'));
    let location = this.learningLocation(title);
    return location.length > 0 ? `${base} · ${location} · 待家长确认` : `${base} · 待家长确认`;
  }

  private learningLocation(text: string): string {
    let lesson = text.match(/第\d+课/);
    if (lesson !== null && lesson.length > 0) return lesson[0];
    let page = text.match(/\d{1,3}\s*页/);
    if (page !== null && page.length > 0) return page[0].replace(/\s+/g, '');
    let unit = text.match(/第\d+单元/);
    if (unit !== null && unit.length > 0) return unit[0];
    return '';
  }

  private addWarning(warnings: string[], value: string): void {
    if (warnings.indexOf(value) < 0) warnings.push(value);
  }
}
