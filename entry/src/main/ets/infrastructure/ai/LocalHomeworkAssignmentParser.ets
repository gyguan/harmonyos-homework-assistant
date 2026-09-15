import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';

export class LocalHomeworkAssignmentParser implements HomeworkAssignmentParser {
  async parse(input: ExtractedHomeworkText): Promise<CandidateAssignment[]> {
    let segments = this.splitSegments(input.text);
    let result: CandidateAssignment[] = [];
    let currentSubject: Subject | null = null;

    for (let rawSegment of segments) {
      let segment = this.stripListMarker(rawSegment.trim());
      if (segment.length === 0) {
        continue;
      }

      let explicitSubject = this.detectSubject(segment);
      if (explicitSubject !== null) {
        currentSubject = explicitSubject;
      }
      if (currentSubject === null) {
        continue;
      }

      let body = this.cleanBody(this.removeSubjectPrefix(segment, explicitSubject));
      if (body.length === 0 || this.isNonHomeworkNotice(body)) {
        continue;
      }

      let taskBodies = this.splitTaskBodies(body);
      for (let taskBody of taskBodies) {
        let cleanTask = this.cleanBody(taskBody);
        if (cleanTask.length === 0 || this.isNonHomeworkNotice(cleanTask)) {
          continue;
        }
        result.push(this.buildCandidate(input, currentSubject, cleanTask,
          explicitSubject !== null, segment, result.length + 1));
      }
    }
    return result;
  }

  private buildCandidate(input: ExtractedHomeworkText, subject: Subject, body: string,
    hasExplicitSubject: boolean, sourceSegment: string, sequence: number): CandidateAssignment {
    return {
      id: `item-${input.importId}-${sequence}`,
      studentId: input.studentId,
      subject: subject,
      title: body,
      instruction: body,
      textbookRef: this.textbookRef(subject, body),
      dueText: this.dueText(body),
      expectedMinutes: 20,
      sourceEvidence: {
        sourceLabel: input.sourceLabel,
        excerpt: sourceSegment
      },
      confidence: this.confidence(body, hasExplicitSubject)
    };
  }

  private splitSegments(value: string): string[] {
    let text = value
      .split('\r').join('')
      .split('；').join('\n')
      .split(';').join('\n')
      .split('今天作业：').join('')
      .split('今天作业:').join('')
      .split('今天作业').join('')
      .split('今日作业：').join('')
      .split('今日作业:').join('')
      .split('今日作业').join('')
      .split('家庭作业：').join('')
      .split('家庭作业:').join('');

    for (let i = 1; i <= 30; i++) {
      let markers: string[] = [
        `${i}.`,
        `${i}．`,
        `${i}、`,
        `(${i})`,
        `（${i}）`
      ];
      for (let marker of markers) {
        text = text.split(marker).join(`\n${marker}`);
      }
    }

    text = text
      .split('语文').join('\n语文')
      .split('数学').join('\n数学')
      .split('英语').join('\n英语');

    return text.split('\n');
  }

  private stripListMarker(value: string): string {
    let result = value.trim();
    for (let i = 1; i <= 30; i++) {
      let markers: string[] = [
        `${i}.`,
        `${i}．`,
        `${i}、`,
        `(${i})`,
        `（${i}）`
      ];
      for (let marker of markers) {
        if (result.startsWith(marker)) {
          return result.substring(marker.length).trim();
        }
      }
    }
    if (result.startsWith('-') || result.startsWith('•') || result.startsWith('·')) {
      return result.substring(1).trim();
    }
    return result;
  }

  private detectSubject(value: string): Subject | null {
    let chinese = value.indexOf('语文');
    let math = value.indexOf('数学');
    let english = value.indexOf('英语');
    let bestIndex = -1;
    let bestSubject: Subject | null = null;

    if (chinese >= 0) {
      bestIndex = chinese;
      bestSubject = Subject.CHINESE;
    }
    if (math >= 0 && (bestIndex < 0 || math < bestIndex)) {
      bestIndex = math;
      bestSubject = Subject.MATH;
    }
    if (english >= 0 && (bestIndex < 0 || english < bestIndex)) {
      bestSubject = Subject.ENGLISH;
    }
    return bestSubject;
  }

  private removeSubjectPrefix(value: string, subject: Subject | null): string {
    if (subject === null) {
      return value;
    }
    let label = this.subjectLabel(subject);
    let index = value.indexOf(label);
    if (index < 0) {
      return value;
    }
    return value.substring(index + label.length);
  }

  private subjectLabel(subject: Subject): string {
    if (subject === Subject.CHINESE) {
      return '语文';
    }
    if (subject === Subject.MATH) {
      return '数学';
    }
    return '英语';
  }

  private cleanBody(value: string): string {
    let result = value.trim();
    while (result.length > 0) {
      let first = result.substring(0, 1);
      if (first === ':' || first === '：' || first === '；' || first === '，' || first === ',' ||
        first === '。' || first === '-' || first === '、') {
        result = result.substring(1).trim();
      } else {
        break;
      }
    }
    while (result.endsWith('；') || result.endsWith('。') || result.endsWith(',')) {
      result = result.substring(0, result.length - 1).trim();
    }
    return result;
  }

  private splitTaskBodies(body: string): string[] {
    let actions: string[] = [
      '背诵', '听读', '口算', '订正', '默写', '预习', '复习', '抄写', '朗读', '阅读', '完成', '练习'
    ];
    let splitPoints: number[] = [];

    for (let action of actions) {
      let start = 0;
      while (start < body.length) {
        let index = body.indexOf(action, start);
        if (index < 0) {
          break;
        }
        if (index > 0 && this.hasTaskSeparatorBefore(body, index)) {
          splitPoints.push(index);
        }
        start = index + action.length;
      }
    }

    this.sortNumbers(splitPoints);
    let uniquePoints: number[] = [];
    for (let point of splitPoints) {
      if (uniquePoints.length === 0 || uniquePoints[uniquePoints.length - 1] !== point) {
        uniquePoints.push(point);
      }
    }
    if (uniquePoints.length === 0) {
      return [body];
    }

    let result: string[] = [];
    let start = 0;
    for (let point of uniquePoints) {
      let part = this.cleanBody(body.substring(start, point));
      if (part.length > 0) {
        result.push(part);
      }
      start = point;
    }
    let tail = this.cleanBody(body.substring(start));
    if (tail.length > 0) {
      result.push(tail);
    }
    return result;
  }

  private hasTaskSeparatorBefore(body: string, index: number): boolean {
    if (index <= 0) {
      return false;
    }
    let previous = body.substring(index - 1, index);
    if (previous === '，' || previous === ',' || previous === '；' || previous === ';' || previous === '、') {
      return true;
    }
    if (previous === '并' || previous === '和' || previous === '及') {
      return true;
    }
    return false;
  }

  private sortNumbers(values: number[]): void {
    for (let i = 1; i < values.length; i++) {
      let current = values[i];
      let j = i - 1;
      while (j >= 0 && values[j] > current) {
        values[j + 1] = values[j];
        j--;
      }
      values[j + 1] = current;
    }
  }

  private isNonHomeworkNotice(body: string): boolean {
    let noticeWords: string[] = [
      '带书', '带齐', '带好', '缴费', '交费', '收费', '穿校服', '校服', '家长会', '接龙', '值日', '返校', '放学', '请假'
    ];
    let actionWords: string[] = [
      '背诵', '听读', '口算', '订正', '默写', '预习', '复习', '抄写', '朗读', '阅读', '完成', '练习', '作业'
    ];
    let hasNotice = false;
    for (let word of noticeWords) {
      if (body.indexOf(word) >= 0) {
        hasNotice = true;
        break;
      }
    }
    if (!hasNotice) {
      return false;
    }
    for (let action of actionWords) {
      if (body.indexOf(action) >= 0) {
        return false;
      }
    }
    return true;
  }

  private dueText(body: string): string {
    if (body.indexOf('明天') >= 0 || body.indexOf('明日') >= 0) {
      return '明天';
    }
    if (body.indexOf('今晚') >= 0 || body.indexOf('晚上') >= 0) {
      return '今晚';
    }

    let weekdays: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    for (let weekday of weekdays) {
      if (body.indexOf(weekday) >= 0) {
        return weekday;
      }
    }

    let dateMatch = body.match(/\d{1,2}月\d{1,2}[日号]/);
    if (dateMatch !== null && dateMatch.length > 0) {
      return dateMatch[0];
    }
    return '今天';
  }

  private textbookRef(subject: Subject, body: string): string {
    let base = '沪教版';
    if (subject === Subject.CHINESE) {
      base = '部编版';
    } else if (subject === Subject.MATH) {
      base = '北师大版';
    }

    let location = this.learningLocation(body);
    if (location.length > 0) {
      return `${base} · ${location} · 待家长确认`;
    }
    return `${base} · 待家长确认`;
  }

  private learningLocation(body: string): string {
    let lessonMatch = body.match(/第\d+课/);
    if (lessonMatch !== null && lessonMatch.length > 0) {
      return lessonMatch[0];
    }
    let unitMatch = body.match(/第\d+单元/);
    if (unitMatch !== null && unitMatch.length > 0) {
      return unitMatch[0];
    }
    let pageMatch = body.match(/[Pp]?\d+([~～\-—至到]\d+)?页?/);
    if (pageMatch !== null && pageMatch.length > 0) {
      return pageMatch[0];
    }
    let unitShort = body.match(/[Uu]\d+/);
    if (unitShort !== null && unitShort.length > 0) {
      return unitShort[0].toUpperCase();
    }
    return '';
  }

  private confidence(body: string, hasExplicitSubject: boolean): number {
    let score = hasExplicitSubject ? 0.88 : 0.78;
    if (this.learningLocation(body).length > 0) {
      score += 0.06;
    }
    if (this.dueText(body) !== '今天') {
      score += 0.03;
    }
    return Math.min(score, 0.98);
  }
}
