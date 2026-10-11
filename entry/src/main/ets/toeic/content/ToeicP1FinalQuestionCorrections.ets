import {
  ToeicDifficulty, ToeicQuestion, ToeicReviewStatus, ToeicSkill
} from '../domain/ToeicModels';
import { ToeicStandardDiagnosticContent } from './ToeicStandardDiagnosticContent';
import { ToeicWeekThreeContent } from './ToeicWeekThreeContent';

/**
 * #478 final P1 active-only replacements.
 * Preserve the original IDs/content for saved reports; new/general training uses
 * these IDs so malformed or misleading distractors are never re-served.
 */
export class ToeicP1FinalQuestionCorrections {
  static questions():ToeicQuestion[] {
    let sprintP5=ToeicWeekThreeContent.p5SprintQuestions()[27];
    let sprintP6=ToeicWeekThreeContent.p6SprintQuestions()[5];
    let mock=ToeicWeekThreeContent.mockQuestions();
    let dx=ToeicStandardDiagnosticContent.questions()[4];
    return [
      new ToeicQuestion('R-FP1-P5-1528',sprintP5.section,sprintP5.part,ToeicSkill.PRONOUN,
        sprintP5.passage,sprintP5.stem,sprintP5.options.slice(),2,
        'identify oneself 需要与主语回指一致的反身代词。Each applicant 可用单数 they，因此 themselves 合适。itself 通常回指非人/中性事物；himself 把申请人限定为男性；ourselves 与第三人称主语不一致。',
        sprintP5.evidence,'identify themselves = prove their identity',
        sprintP5.recommendedSeconds,sprintP5.difficulty,sprintP5.scoreValue,
        ToeicReviewStatus.PUBLISHED,1),
      new ToeicQuestion('R-FP1-P6-1606',sprintP6.section,sprintP6.part,ToeicSkill.VOICE,
        sprintP6.passage,sprintP6.stem,
        ['receives','is received','has received','receiving'],1,
        'payment 是 receive 的承受者，after 引导的时间从句需要完整谓语，因此 is received。receives 和 has received 都是主动语态，会让 payment 成为接收者；receiving 是非谓语，不能独立完成该从句。',
        sprintP6.evidence,'payment is received = payment arrives and is recorded',
        sprintP6.recommendedSeconds,sprintP6.difficulty,sprintP6.scoreValue,
        ToeicReviewStatus.PUBLISHED,1),
      new ToeicQuestion('R-FP1-DX-P5-05',dx.section,dx.part,ToeicSkill.VOICE,
        dx.passage,dx.stem,['send','was sent','had sent','sending'],1,
        'last week 给出明确过去时间，policy 是被发送到各区域办公室，因此使用一般过去时被动 was sent。send 是原形主动；had sent 是过去完成主动，且 policy 不能在本句中充当发送者；sending 为非谓语。',
        dx.evidence,'was sent last week = was distributed last week',
        dx.recommendedSeconds,dx.difficulty,dx.scoreValue,
        ToeicReviewStatus.PUBLISHED,1),
      new ToeicQuestion('R-FP1-M2-P5-010',mock[9].section,mock[9].part,ToeicSkill.PRONOUN,
        mock[9].passage,mock[9].stem,['it','its','itself',"it's"],1,
        'policy 前需要形容词性物主限定词 its。it 是人称代词；itself 是反身代词；it\'s 是 it is 或 it has 的缩写，不是所有格。',
        mock[9].evidence,'its privacy policy = the company\'s privacy policy',
        mock[9].recommendedSeconds,mock[9].difficulty,mock[9].scoreValue,
        ToeicReviewStatus.PUBLISHED,1),
      new ToeicQuestion('R-FP1-M2-P6-002',mock[31].section,mock[31].part,ToeicSkill.VERB,
        mock[31].passage,mock[31].stem,['arrive','arrived','will arrive','arrival'],0,
        'when 引导表示未来时间的时间状语从句时，用一般现在时表示未来，因此 they arrive。arrived 是过去时；will arrive 在这里不是中性的未来时间从句形式；arrival 是名词，不能作谓语。',
        mock[31].evidence,'when they arrive = when they get there',
        mock[31].recommendedSeconds,mock[31].difficulty,mock[31].scoreValue,
        ToeicReviewStatus.PUBLISHED,1)
    ];
  }
}
