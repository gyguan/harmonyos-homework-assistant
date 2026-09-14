import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';

interface SubjectMarker {
  index: number;
  label: string;
  subject: Subject;
}

export class LocalHomeworkAssignmentParser implements HomeworkAssignmentParser {
  async parse(input: ExtractedHomeworkText): Promise<CandidateAssignment[]> {
    let text = this.normalize(input.text);
    let markers = this.findMarkers(text);
    let result: CandidateAssignment[] = [];

    for (let i = 0; i < markers.length; i++) {
      let marker = markers[i];
      let end = i + 1 < markers.length ? markers[i + 1].index : text.length;
      let segment = text.substring(marker.index, end);
      let body = this.cleanBody(segment.substring(marker.label.length));
      if (body.length === 0) {
        continue;
      }
      result.push({
        id: `ocr-${input.importId}-${i + 1}`,
        subject: marker.subject,
        title: body,
        instruction: body,
        textbookRef: this.textbookRef(marker.subject, body),
        dueText: this.dueText(body),
        sourceEvidence: {
          sourceLabel: input.sourceLabel,
          excerpt: `${marker.label}${body}`
        },
        confidence: this.confidence(body)
      });
    }
    return result;
  }

  private normalize(value: string): string {
    return value
      .split('\r').join('')
      .split('\n').join('；')
      .split(';').join('；')
      .split('今天作业').join('')
      .split('今日作业').join('');
  }

  private findMarkers(text: string): SubjectMarker[] {
    let markers: SubjectMarker[] = [];
    this.addMarker(markers, text, '语文', Subject.CHINESE);
    this.addMarker(markers, text, '数学', Subject.MATH);
    this.addMarker(markers, text, '英语', Subject.ENGLISH);

    for (let i = 1; i < markers.length; i++) {
      let current = markers[i];
      let j = i - 1;
      while (j >= 0 && markers[j].index > current.index) {
        markers[j + 1] = markers[j];
        j--;
      }
      markers[j + 1] = current;
    }
    return markers;
  }

  private addMarker(markers: SubjectMarker[], text: string, label: string, subject: Subject): void {
    let index = text.indexOf(label);
    if (index >= 0) {
      markers.push({ index: index, label: label, subject: subject });
    }
  }

  private cleanBody(value: string): string {
    let result = value.trim();
    while (result.length > 0) {
      let first = result.substring(0, 1);
      if (first === ':' || first === '：' || first === '；' || first === '，' || first === ',' || first === '。') {
        result = result.substring(1).trim();
      } else {
        break;
      }
    }
    while (result.endsWith('；')) {
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

  private confidence(body: string): number {
    if (body.length >= 4) {
      return 0.88;
    }
    return 0.72;
  }
}
