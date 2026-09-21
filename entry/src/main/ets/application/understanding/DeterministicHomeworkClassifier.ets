import {
  HomeworkMessageClassification,
  TeacherResolution,
  TeacherResolutionStatus
} from '../../domain/model/HomeworkUnderstandingModels';
import { ImportedMessage } from '../../domain/model/ImportModels';

export class DeterministicHomeworkClassifier {
  classify(message: ImportedMessage, teacher: TeacherResolution): HomeworkMessageClassification {
    let text = this.normalize(message.text);
    if (text.length === 0) return HomeworkMessageClassification.UNKNOWN;

    if (this.isChatAcknowledgement(text)) {
      return HomeworkMessageClassification.CHAT;
    }

    if (teacher.status !== TeacherResolutionStatus.RESOLVED) {
      return HomeworkMessageClassification.UNKNOWN;
    }

    if (this.containsAny(text, [
      '刚才说错了', '说错了', '改成', '不用做', '不需要做',
      '取消第', '补充一下', '补充：', '补充:', '以这条为准', '以此为准'
    ])) {
      return HomeworkMessageClassification.HOMEWORK_REVISION;
    }

    if (this.isPreparation(text)) return HomeworkMessageClassification.PREPARATION;
    if (this.isNotice(text)) return HomeworkMessageClassification.NOTICE;
    if (this.isHomework(text)) return HomeworkMessageClassification.HOMEWORK;
    return HomeworkMessageClassification.UNKNOWN;
  }

  confidence(classification: HomeworkMessageClassification, teacher: TeacherResolution): number {
    if (classification === HomeworkMessageClassification.CHAT) return 0.98;
    if (teacher.status !== TeacherResolutionStatus.RESOLVED) return 0.35;
    if (classification === HomeworkMessageClassification.UNKNOWN) return 0.45;
    if (classification === HomeworkMessageClassification.HOMEWORK_REVISION) return 0.93;
    if (classification === HomeworkMessageClassification.HOMEWORK) return 0.9;
    if (classification === HomeworkMessageClassification.PREPARATION) return 0.9;
    if (classification === HomeworkMessageClassification.NOTICE) return 0.88;
    return 0.5;
  }

  private isHomework(text: string): boolean {
    if (text.indexOf('作业') >= 0) return true;
    return this.containsAny(text, [
      '完成', '朗读', '阅读', '背诵', '抄写', '默写', '听读', '口算',
      '订正', '预习', '复习', '练习册', '练习', '写两遍', '写三遍',
      '读三遍', '读两遍', '做第', '第1题', '第2题', '第3题'
    ]);
  }

  private isPreparation(text: string): boolean {
    let hasPrepareAction = this.containsAny(text, [
      '带一本', '带上', '带好', '带齐', '携带', '准备一本', '准备好', '明天带', '明日带'
    ]);
    if (!hasPrepareAction) return false;
    return text.indexOf('明天') >= 0 || text.indexOf('明日') >= 0 ||
      text.indexOf('下节课') >= 0 || text.indexOf('明早') >= 0;
  }

  private isNotice(text: string): boolean {
    return this.containsAny(text, [
      '家长会', '放学', '返校', '缴费', '交费', '收费', '穿校服',
      '接龙', '值日', '请假', '停课', '调课', '上课时间', '集合'
    ]);
  }

  private isChatAcknowledgement(text: string): boolean {
    let compact = text.replace(/[，。！？!?~～\s]/g, '');
    return compact === '收到' || compact === '好的' || compact === '好' ||
      compact === '谢谢老师' || compact === '辛苦老师了' || compact === '明白' ||
      compact === '知道了' || compact === 'ok' || compact === 'OK';
  }

  private containsAny(value: string, words: string[]): boolean {
    for (let word of words) if (value.indexOf(word) >= 0) return true;
    return false;
  }

  private normalize(value: string): string {
    return value.trim().replace(/\s+/g, ' ');
  }
}
