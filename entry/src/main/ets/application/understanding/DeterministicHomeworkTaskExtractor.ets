import {
  HomeworkMessageClassification,
  HomeworkTaskDraft
} from '../../domain/model/HomeworkUnderstandingModels';
import { Subject } from '../../domain/model/HomeworkModels';

export class DeterministicHomeworkTaskExtractor {
  extractHomework(text: string, subject: Subject, messageId: string,
    confidence: number): HomeworkTaskDraft[] {
    let body = this.removeHomeworkIntro(text, subject);
    let parts = this.splitTasks(body);
    let result: HomeworkTaskDraft[] = [];
    for (let part of parts) {
      let clean = this.cleanTask(part);
      if (clean.length === 0) continue;
      result.push({
        subject: subject,
        title: clean,
        instruction: clean,
        dueText: this.dueText(text),
        expectedMinutes: 20,
        classification: HomeworkMessageClassification.HOMEWORK,
        sourceMessageIds: [messageId],
        confidence: confidence
      });
    }
    return result;
  }

  extractPreparation(text: string, subject: Subject, messageId: string,
    confidence: number): HomeworkTaskDraft[] {
    let clean = this.cleanPreparation(text);
    if (clean.length === 0) return [];
    return [{
      subject: subject,
      title: `明日准备：${clean}`,
      instruction: clean,
      dueText: '明天',
      expectedMinutes: 5,
      classification: HomeworkMessageClassification.PREPARATION,
      sourceMessageIds: [messageId],
      confidence: confidence
    }];
  }

  extractRevisionPayload(text: string, subject: Subject, messageId: string,
    confidence: number): HomeworkTaskDraft[] {
    let payload = this.revisionPayload(text);
    if (payload.length === 0) return [];
    return this.extractHomework(payload, subject, messageId, confidence);
  }

  revisionPayload(text: string): string {
    let markers: string[] = [
      '补充一下', '补充：', '补充:', '以这条为准', '以此为准'
    ];
    let normalized = text.trim();
    for (let marker of markers) {
      let index = normalized.indexOf(marker);
      if (index < 0) continue;
      let payload = normalized.substring(index + marker.length);
      return this.trimSeparators(payload);
    }
    return '';
  }

  pageCorrection(text: string): string {
    let match = text.match(/练习册(?:改成|是|为)?\s*(\d{1,3})\s*页/);
    if (match === null) {
      match = text.match(/练习册[^\d]{0,10}(\d{1,3})\s*页/);
    }
    return match === null ? '' : match[1];
  }

  genericReplacement(text: string): string {
    let index = text.indexOf('改成');
    if (index < 0) return '';
    return this.trimSeparators(text.substring(index + 2));
  }

  cancelledTaskIndex(text: string): number {
    let match = text.match(/第\s*([一二三四五六七八九十\d]+)\s*题[^。；，,]*(不用做|不需要做|取消)/);
    if (match === null) return -1;
    return this.ordinalNumber(match[1]);
  }

  replacePage(title: string, page: string): string {
    let pattern = /\d{1,3}\s*页/;
    if (pattern.test(title)) return title.replace(pattern, `${page}页`);
    if (title.indexOf('练习册') >= 0) return `练习册${page}页`;
    return title;
  }

  private removeHomeworkIntro(text: string, subject: Subject): string {
    let result = text.trim();
    let labels: string[] = [
      '今晚作业', '今天作业', '今日作业', '家庭作业',
      `今晚${subject}作业`, `今天${subject}作业`, `今日${subject}作业`,
      `今晚${subject}`, `今天${subject}`, `今日${subject}`,
      `${subject}作业`, `${subject}`
    ];
    for (let label of labels) {
      if (result.startsWith(label)) {
        result = result.substring(label.length);
        break;
      }
    }
    return this.trimSeparators(result);
  }

  private splitTasks(text: string): string[] {
    let expanded = text.split('\r').join('')
      .split('；').join('\n')
      .split(';').join('\n');

    for (let i = 1; i <= 20; i++) {
      let markers: string[] = [
        `${i}.`, `${i}．`, `${i}、`, `（${i}）`, `(${i})`
      ];
      for (let marker of markers) {
        expanded = expanded.split(marker).join(`\n${marker}`);
      }
    }

    let result: string[] = [];
    for (let raw of expanded.split('\n')) {
      let clean = this.stripListMarker(raw.trim());
      if (clean.length === 0) continue;
      let commaParts = this.splitActionClauses(clean);
      for (let part of commaParts) {
        if (part.trim().length > 0) result.push(part.trim());
      }
    }
    return result;
  }

  private splitActionClauses(value: string): string[] {
    let separators: string[] = ['，并', ',并', '；', ';'];
    let parts: string[] = [value];
    for (let separator of separators) {
      let next: string[] = [];
      for (let part of parts) {
        let split = part.split(separator);
        for (let item of split) next.push(item);
      }
      parts = next;
    }
    return parts;
  }

  private stripListMarker(value: string): string {
    let result = value;
    for (let i = 1; i <= 20; i++) {
      let markers: string[] = [
        `${i}.`, `${i}．`, `${i}、`, `（${i}）`, `(${i})`
      ];
      for (let marker of markers) {
        if (result.startsWith(marker)) return result.substring(marker.length).trim();
      }
    }
    if (result.startsWith('-') || result.startsWith('•') || result.startsWith('·')) {
      return result.substring(1).trim();
    }
    return result;
  }

  private cleanTask(value: string): string {
    let result = this.trimSeparators(value);
    let prefixes: string[] = ['作业：', '作业:', '要求：', '要求:'];
    for (let prefix of prefixes) {
      if (result.startsWith(prefix)) result = this.trimSeparators(result.substring(prefix.length));
    }
    return result;
  }

  private cleanPreparation(value: string): string {
    let result = value.trim();
    let prefixes: string[] = ['另外', '提醒', '请', '明天', '明日', '明早'];
    let changed = true;
    while (changed) {
      changed = false;
      for (let prefix of prefixes) {
        if (result.startsWith(prefix)) {
          result = this.trimSeparators(result.substring(prefix.length));
          changed = true;
          break;
        }
      }
    }
    return result;
  }

  private dueText(text: string): string {
    if (text.indexOf('明天') >= 0 || text.indexOf('明日') >= 0) return '明天';
    if (text.indexOf('今晚') >= 0 || text.indexOf('晚上') >= 0) return '今晚';
    return '今天';
  }

  private trimSeparators(value: string): string {
    let result = value.trim();
    while (result.length > 0) {
      let first = result.substring(0, 1);
      if (first === ':' || first === '：' || first === '，' || first === ',' ||
        first === '。' || first === '-' || first === '；' || first === ';') {
        result = result.substring(1).trim();
      } else {
        break;
      }
    }
    while (result.endsWith('。') || result.endsWith('；') || result.endsWith(';')) {
      result = result.substring(0, result.length - 1).trim();
    }
    return result;
  }

  private ordinalNumber(value: string): number {
    let numeric = Number(value);
    if (Number.isFinite(numeric) && numeric > 0) return Math.round(numeric);

    let direct: string[] = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    for (let i = 0; i < direct.length; i++) {
      if (value === direct[i]) return i + 1;
    }
    if (value.startsWith('十') && value.length === 2) {
      let tail = this.ordinalNumber(value.substring(1));
      return tail > 0 ? 10 + tail : -1;
    }
    if (value.endsWith('十') && value.length === 2) {
      let head = this.ordinalNumber(value.substring(0, 1));
      return head > 0 ? head * 10 : -1;
    }
    return -1;
  }
}
