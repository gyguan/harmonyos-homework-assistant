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
      if (body.length === 0) {
        continue;
      }

      result.push({
        id: `item-${input.importId}-${result.length + 1}`,
        subject: currentSubject,
        title: body,
        instruction: body,
        textbookRef: this.textbookRef(currentSubject, body),
        dueText: this.dueText(body),
        sourceEvidence: {
          sourceLabel: input.sourceLabel,
          excerpt: `${this.subjectLabel(currentSubject)}${body}`
        },
        confidence: this.confidence(body, explicitSubject !== null)
      });
    }
    return result;
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
      .split('今日作业').join('');

    for (let i = 1; i <= 30; i++) {
      let markers: string[] = [
        `${i}. `,
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
      if (first === ':' || first === '：' || first === '；' || first === '，' || first === ',' || first === '。' || first === '-') {
        result = result.substring(1).trim();
      } else {
        break;
      }
    }
    while (result.endsWith('；') || result.endsWith('。')) {
      result = result.substring(0, result.length - 1).trim();
    }
    return result;
  }

  private dueText(body: string): string {
    if (body.indexOf('明天') >= 0 || body.indexOf('明日') >= 0) {
      return '明天';
    }
    if (body.indexOf('今晚') >= 0 || body.indexOf('晚上') >= 0) {
      return '今晚';
    }
    return '今天';
  }

  private textbookRef(subject: Subject, body: string): string {
    if (subject === Subject.CHINESE) {
      let lessonStart = body.indexOf('第');
      let lessonEnd = body.indexOf('课');
      if (lessonStart >= 0 && lessonEnd > lessonStart) {
        return `部编版 · ${body.substring(lessonStart, lessonEnd + 1)} · 待家长确认`;
      }
      return '部编版 · 待家长确认';
    }
    if (subject === Subject.MATH) {
      return '北师大版 · 待家长确认';
    }
    return '沪教版 · 待家长确认';
  }

  private confidence(body: string, hasExplicitSubject: boolean): number {
    if (body.length < 4) {
      return 0.72;
    }
    return hasExplicitSubject ? 0.92 : 0.84;
  }
}
