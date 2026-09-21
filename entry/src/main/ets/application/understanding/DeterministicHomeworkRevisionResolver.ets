import {
  HomeworkTaskDraft
} from '../../domain/model/HomeworkUnderstandingModels';
import { Subject } from '../../domain/model/HomeworkModels';
import { DeterministicHomeworkTaskExtractor } from './DeterministicHomeworkTaskExtractor';

export interface RevisionResolution {
  tasks: HomeworkTaskDraft[];
  warnings: string[];
}

export class DeterministicHomeworkRevisionResolver {
  private readonly extractor: DeterministicHomeworkTaskExtractor;

  constructor(extractor: DeterministicHomeworkTaskExtractor) {
    this.extractor = extractor;
  }

  apply(tasks: HomeworkTaskDraft[], text: string, subject: Subject,
    messageId: string, confidence: number): RevisionResolution {
    let result = this.copyTasks(tasks);
    let warnings: string[] = [];

    if (text.indexOf('以这条为准') >= 0 || text.indexOf('以此为准') >= 0) {
      let replacements = this.extractor.extractRevisionPayload(text, subject, messageId, confidence);
      if (replacements.length > 0) return { tasks: replacements, warnings: warnings };
      warnings.push('REVISION_AUTHORITATIVE_WITHOUT_TASKS');
      return { tasks: result, warnings: warnings };
    }

    let cancelIndex = this.extractor.cancelledTaskIndex(text);
    if (cancelIndex > 0) {
      if (cancelIndex <= result.length) {
        result.splice(cancelIndex - 1, 1);
      } else {
        warnings.push('REVISION_CANCEL_TARGET_NOT_FOUND');
      }
      return { tasks: result, warnings: warnings };
    }

    let page = this.extractor.pageCorrection(text);
    if (page.length > 0) {
      let index = this.lastTaskContaining(result, '练习册');
      if (index >= 0) {
        result[index].title = this.extractor.replacePage(result[index].title, page);
        result[index].instruction = result[index].title;
        this.addEvidence(result[index], messageId);
        result[index].confidence = Math.max(result[index].confidence, confidence);
      } else {
        warnings.push('REVISION_PAGE_TARGET_NOT_FOUND');
      }
      return { tasks: result, warnings: warnings };
    }

    if (text.indexOf('补充一下') >= 0 || text.indexOf('补充：') >= 0 || text.indexOf('补充:') >= 0) {
      let additions = this.extractor.extractRevisionPayload(text, subject, messageId, confidence);
      for (let item of additions) result.push(item);
      if (additions.length === 0) warnings.push('REVISION_SUPPLEMENT_EMPTY');
      return { tasks: result, warnings: warnings };
    }

    let replacement = this.extractor.genericReplacement(text);
    if (replacement.length > 0) {
      if (result.length === 0) {
        warnings.push('REVISION_REPLACE_TARGET_NOT_FOUND');
        return { tasks: result, warnings: warnings };
      }
      let index = result.length - 1;
      result[index].title = replacement;
      result[index].instruction = replacement;
      this.addEvidence(result[index], messageId);
      result[index].confidence = Math.max(result[index].confidence, confidence);
      return { tasks: result, warnings: warnings };
    }

    if (text.indexOf('刚才说错了') >= 0 || text.indexOf('说错了') >= 0) {
      warnings.push('REVISION_UNRESOLVED');
      return { tasks: result, warnings: warnings };
    }

    warnings.push('REVISION_UNRECOGNIZED');
    return { tasks: result, warnings: warnings };
  }

  private lastTaskContaining(tasks: HomeworkTaskDraft[], token: string): number {
    for (let i = tasks.length - 1; i >= 0; i--) {
      if (tasks[i].title.indexOf(token) >= 0) return i;
    }
    return -1;
  }

  private addEvidence(task: HomeworkTaskDraft, messageId: string): void {
    if (task.sourceMessageIds.indexOf(messageId) < 0) task.sourceMessageIds.push(messageId);
  }

  private copyTasks(tasks: HomeworkTaskDraft[]): HomeworkTaskDraft[] {
    let result: HomeworkTaskDraft[] = [];
    for (let item of tasks) {
      result.push({
        subject: item.subject,
        title: item.title,
        instruction: item.instruction,
        dueText: item.dueText,
        expectedMinutes: item.expectedMinutes,
        classification: item.classification,
        sourceMessageIds: item.sourceMessageIds.slice(),
        confidence: item.confidence
      });
    }
    return result;
  }
}
