import {
  ToeicDifficulty, ToeicPart, ToeicQuestion, ToeicReadingGroup, ToeicReviewStatus, ToeicScoreValue, ToeicSection,
  ToeicSentenceDrill, ToeicSkill, ToeicStudyDay, ToeicVocabularyItem, ToeicVocabularyLevel
} from '../domain/ToeicModels';
import { ToeicContentValidator } from './ToeicContentValidator';
import { ToeicWeekOneContent } from './ToeicWeekOneContent';
import { ToeicWeekTwoContent } from './ToeicWeekTwoContent';
import { ToeicMockDay14V2Content } from './ToeicMockDay14V2Content';
import { ToeicMockDay19V2Content } from './ToeicMockDay19V2Content';
import { ToeicMockPart7EvidenceRevisionContent } from './ToeicMockPart7EvidenceRevisionContent';
import { ToeicMockDay19Part6V2Content } from './ToeicMockDay19Part6V2Content';
import { ToeicMockDay19Part5V2Content } from './ToeicMockDay19Part5V2Content';
import { ToeicMockDay14Part5V2Content } from './ToeicMockDay14Part5V2Content';
import { ToeicP5UniqueAnswerIssue478 } from './ToeicP5UniqueAnswerIssue478';
import { ToeicP6ConditionalIssue478 } from './ToeicP6ConditionalIssue478';
import { ToeicP1FinalQuestionCorrections } from './ToeicP1FinalQuestionCorrections';
import { ToeicP3FinalCorrections } from './ToeicP3FinalCorrections';
import { ToeicMockPart6V2RepairContent } from './ToeicMockPart6V2RepairContent';
import { ToeicMockDay19Part6CompletionContent } from './ToeicMockDay19Part6CompletionContent';
import { ToeicWeekThreeContent } from './ToeicWeekThreeContent';
import { ToeicPronunciationCatalog } from './ToeicPronunciationCatalog';
import { ToeicVocabularyExpansion } from './ToeicVocabularyExpansion';
import { ToeicVocabularyBatchTwo } from './ToeicVocabularyBatchTwo';
import { ToeicVocabularyBatchThree } from './ToeicVocabularyBatchThree';
import { ToeicVocabularyBatchFour } from './ToeicVocabularyBatchFour';
import { ToeicVocabularyBatchFive } from './ToeicVocabularyBatchFive';
import { ToeicVocabularyBatchSix } from './ToeicVocabularyBatchSix';
import { ToeicVocabularyBatchSeven } from './ToeicVocabularyBatchSeven';
import { ToeicStandardDiagnosticContent } from './ToeicStandardDiagnosticContent';
import { ToeicExtraReadingContent } from './ToeicExtraReadingContent';
import { ToeicExtraReadingBatchTwo } from './ToeicExtraReadingBatchTwo';
import { ToeicExtraReadingBatchThree } from './ToeicExtraReadingBatchThree';
import { ToeicExtraReadingBatchFour } from './ToeicExtraReadingBatchFour';
import { ToeicExtraReadingBatchFive } from './ToeicExtraReadingBatchFive';
import { ToeicExtraReadingBatchSix } from './ToeicExtraReadingBatchSix';

export class PresetToeicContent {
  static questions():ToeicQuestion[] {
    let base:ToeicQuestion[]=[
      new ToeicQuestion('R-P5-WF-0001',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.WORD_FORM,'',
        'The instructions in the training manual are _____ written.',
        ['clear','clearly','clarity','clearing'],1,
        'written 在这里是过去分词，修饰 written 需要副词 clearly。看到“be + ___ + 过去分词”时，优先检查副词。',
        '','clearly written = written in a clear way',12,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P5-VOICE-0002',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.VOICE,'',
        'All reimbursement requests must be _____ by a supervisor before payment.',
        ['approve','approved','approving','approval'],1,
        'request 是被审批，must be 后接过去分词构成被动语态，因此选 approved。',
        '','be approved = receive approval',15,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P5-PREP-0003',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.PREPOSITION,'',
        'Employees are eligible _____ a transportation allowance after six months.',
        ['at','for','with','by'],1,
        '固定搭配是 be eligible for，表示“有资格获得”。',
        '','be eligible for = qualify for',12,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P5-CONJ-0004',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.CONJUNCTION,'',
        'The conference room will remain closed _____ the renovation is completed.',
        ['until','during','despite','because of'],0,
        '空格后是完整句子 the renovation is completed，需要连词；until 表示“直到……为止”。',
        '','remain closed until = not reopen before',18,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P5-COL-0005',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.COLLOCATION,'',
        'Please _____ the attached expense form by Friday.',
        ['submit','attend','reserve','install'],0,
        'submit a form 是高频商务搭配，表示“提交表格”。',
        '','submit a form = send a form for review',18,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P5-VOC-0006',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.VOCABULARY,'',
        'The supplier has agreed to _____ the delivery until Monday.',
        ['postpone','inspect','occupy','purchase'],0,
        'postpone the delivery 表示“推迟交货”；until Monday 给出了延后到的时间。',
        '','postpone = delay',22,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL),
      new ToeicQuestion('R-P6-CTX-0001',ToeicSection.READING,ToeicPart.PART_6,ToeicSkill.CONTEXT,
        'Due to scheduled maintenance, online ordering will be unavailable from 10 P.M. to midnight. _____, customers may place orders by phone at 555-0186. Normal online service will resume after midnight.',
        'Which phrase best completes the online-ordering notice?',
        ['During this period','For example','Last month','In the same building'],0,
        '前句给出线上服务不可用的时间段，后句说明该时段可改用电话下单。During this period 能准确承接时间关系。',
        '','During this period = while online ordering is unavailable',35,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET,
        ToeicReviewStatus.PUBLISHED,2),
      new ToeicQuestion('R-P6-WF-0002',ToeicSection.READING,ToeicPart.PART_6,ToeicSkill.WORD_FORM,
        'Thank you for applying for the sales coordinator position. We will review all applications this week. _____ candidates will be contacted by Friday to arrange an interview.',
        'Which word best completes the applicant notification?',
        ['Qualification','Qualified','Qualify','Qualifies'],1,
        '空格修饰 candidates，需要形容词。qualified candidates 表示“符合条件的候选人”。',
        '','qualified candidates = candidates who meet the requirements',30,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET,
        ToeicReviewStatus.PUBLISHED,2),
      new ToeicQuestion('R-P7-DETAIL-0001',ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,
        'To: Office Staff\nFrom: Facilities Team\nThe new printer for the third floor will be delivered on Tuesday morning. Installation will begin immediately after delivery. Please send any installation questions to Nina Patel.',
        'When will the new printer be delivered?',
        ['Monday afternoon','Tuesday morning','Tuesday afternoon','Wednesday morning'],1,
        '定位 delivered，原文明确写 on Tuesday morning。',
        'The new printer for the third floor will be delivered on Tuesday morning.',
        'be delivered on Tuesday morning = arrive Tuesday morning',40,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P7-PURPOSE-0002',ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.PURPOSE,
        'NOTICE\nBeginning October 5, lunch service in the employee cafeteria will start at 11:30 A.M. instead of noon. The earlier opening time is intended to reduce crowding during the lunch period.',
        'What is the purpose of the notice?',
        ['To announce a change in cafeteria hours','To advertise a new restaurant','To request employee feedback','To explain a menu price increase'],0,
        '首句直接宣布员工餐厅午餐服务时间从中午改到 11:30，因此目的是通知时间变化。',
        'Beginning October 5, lunch service in the employee cafeteria will start at 11:30 A.M. instead of noon.',
        'start at 11:30 instead of noon = change cafeteria hours',45,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P7-PARA-0003',ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.PARAPHRASE,
        'Harbor View Hotel provides a complimentary shuttle between the hotel and Central Station every 30 minutes from 6 A.M. to 10 P.M.',
        'What does the hotel offer at no charge?',
        ['Breakfast','Parking','Transportation','Laundry service'],2,
        'complimentary 表示免费；shuttle 是接驳交通。因此 at no charge 对应 complimentary，答案是 Transportation。',
        'Harbor View Hotel provides a complimentary shuttle between the hotel and Central Station.',
        'complimentary = at no charge; shuttle = transportation',50,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P7-DETAIL-0004',ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,
        'Thank you to everyone who applied for the marketing assistant position. Applications will be reviewed through October 8. Candidates selected for an interview will be contacted by October 10.',
        'Who will be contacted by October 10?',
        ['All applicants','New customers','Selected interview candidates','Current marketing employees'],2,
        '原文明确限定 Candidates selected for an interview，因此并非所有申请者都会被联系。',
        'Candidates selected for an interview will be contacted by October 10.',
        'candidates selected for an interview = selected interview candidates',45,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P5-VERB-0007',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.VERB,'',
        'Ms. Chen has worked in the finance department _____ 2019.',
        ['since','for','during','while'],0,
        '现在完成时 has worked 搭配具体起点 2019，应使用 since；for 后通常接一段时间。',
        '','since + starting point',15,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P5-COL-0008',ToeicSection.READING,ToeicPart.PART_5,ToeicSkill.COLLOCATION,'',
        'The project team is working overtime to _____ the deadline.',
        ['meet','take','hold','carry'],0,
        '固定搭配 meet a deadline 表示“按时完成、赶上截止日期”。',
        '','meet a deadline = finish on time',14,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P6-CONJ-0003',ToeicSection.READING,ToeicPart.PART_6,ToeicSkill.CONJUNCTION,
        'The Riverside branch will be closed on Monday for electrical work. _____, customers can visit our Hill Street branch, which will operate during normal business hours.',
        'Choose the best word for the blank.',
        ['Instead','Unless','Recently','Similarly'],0,
        '前句说明 Riverside branch 关闭，后句提供替代方案，因此 Instead 最符合逻辑。',
        '','instead = as an alternative',30,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P7-DETAIL-0005',ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.DETAIL,
        'PARKING NOTICE\nThe employee parking lot will be closed this Thursday for resurfacing. Employees who drive to work that day should use the public garage across Pine Street. The company will reimburse the parking fee.',
        'Where should employees park on Thursday?',
        ['Behind the office','Across Pine Street','At Central Station','Next to the cafeteria'],1,
        '定位 Thursday 和 park，原文要求使用 across Pine Street 的 public garage。',
        'Employees who drive to work that day should use the public garage across Pine Street.',
        'use the public garage across Pine Street = park across Pine Street',45,ToeicDifficulty.EASY,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P7-PARA-0006',ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.PARAPHRASE,
        'Customer Notice\nOrders placed before 2 P.M. are normally dispatched on the same business day. Orders received after 2 P.M. are processed the following business day.',
        'What happens to an order placed at 3 P.M.?',
        ['It is canceled automatically','It is processed the next business day','It is delivered that evening','It receives a discount'],1,
        '3 P.M. 在 2 P.M. 之后，因此适用第二句：the following business day。',
        'Orders received after 2 P.M. are processed the following business day.',
        'the following business day = the next business day',50,ToeicDifficulty.MEDIUM,ToeicScoreValue.MUST_GET),
      new ToeicQuestion('R-P7-CROSS-0007',ToeicSection.READING,ToeicPart.PART_7,ToeicSkill.CROSS_DOCUMENT,
        'TRAIN SCHEDULE\nTrain 84: Lakeside 8:10 A.M. → Central 9:05 A.M.\nTrain 92: Lakeside 8:40 A.M. → Central 9:35 A.M.\n\nMESSAGE\nPriya, our presentation at Central Tower starts at 9:30. Please choose a train that gives us at least 15 minutes to walk from Central Station to the building. —Owen',
        'Which train should Priya take?',
        ['Train 84','Train 92','Either train','Neither train'],0,
        '会议 9:30 开始且至少需要 15 分钟步行，因此必须在 9:15 前到站。Train 84 在 9:05 到达，满足要求。',
        'Train 84 arrives at 9:05 A.M.; the message requires at least 15 minutes before the 9:30 presentation.',
        '9:30 minus 15 minutes = latest acceptable arrival 9:15',75,ToeicDifficulty.MEDIUM,ToeicScoreValue.NORMAL)
    ];
    return base.concat(ToeicWeekOneContent.questions()).concat(ToeicWeekTwoContent.questions()).concat(ToeicWeekThreeContent.questions()).concat(ToeicStandardDiagnosticContent.questions()).concat(ToeicExtraReadingContent.questions()).concat(ToeicExtraReadingBatchTwo.questions()).concat(ToeicExtraReadingBatchThree.questions()).concat(ToeicExtraReadingBatchFour.questions()).concat(ToeicExtraReadingBatchFive.questions()).concat(ToeicExtraReadingBatchSix.questions()).concat(ToeicMockDay14V2Content.questions()).concat(ToeicMockDay19V2Content.questions()).concat(ToeicMockPart7EvidenceRevisionContent.questions()).concat(ToeicMockDay19Part6V2Content.questions()).concat(ToeicMockDay19Part5V2Content.questions()).concat(ToeicMockDay14Part5V2Content.questions()).concat(ToeicP5UniqueAnswerIssue478.questions()).concat(ToeicP6ConditionalIssue478.questions()).concat(ToeicP1FinalQuestionCorrections.questions()).concat(ToeicP3FinalCorrections.questions()).concat([ToeicMockPart6V2RepairContent.day14(),ToeicMockPart6V2RepairContent.day19(),ToeicMockDay19Part6CompletionContent.inventory(),ToeicMockDay19Part6CompletionContent.library()]);
  }

  static publishedReadingGroups():ToeicReadingGroup[] {
    let candidates=ToeicExtraReadingContent.groups().concat(ToeicExtraReadingBatchTwo.groups()).concat(ToeicExtraReadingBatchThree.groups()).concat(ToeicExtraReadingBatchFour.groups()).concat(ToeicExtraReadingBatchFive.groups()).concat(ToeicExtraReadingBatchSix.groups()).concat(ToeicMockDay14V2Content.groups()).concat(ToeicMockDay19V2Content.groups());
    // The group catalog represents the CURRENT release only. Historic question
    // IDs remain published/addressable for saved drafts and reports, but they
    // must not be counted as extra members of an active five-question group.
    for (let group of candidates) {
      let activeIds:string[]=[];
      for (let id of group.questionIds) {
        let active=ToeicMockPart7EvidenceRevisionContent.activeId(id);
        active=ToeicP3FinalCorrections.activePart7Id(active);
        if (activeIds.indexOf(active)<0) activeIds.push(active);
      }
      group.questionIds=activeIds;
    }
    let items=ToeicExtraReadingContent.questions().concat(ToeicExtraReadingBatchTwo.questions()).concat(ToeicExtraReadingBatchThree.questions()).concat(ToeicExtraReadingBatchFour.questions()).concat(ToeicExtraReadingBatchFive.questions()).concat(ToeicExtraReadingBatchSix.questions()).concat(ToeicMockDay14V2Content.questions()).concat(ToeicMockDay19V2Content.questions()).concat(ToeicMockPart7EvidenceRevisionContent.questions()).concat(ToeicP3FinalCorrections.questions()).concat(ToeicMockDay19Part6V2Content.questions());
    let groups:ToeicReadingGroup[]=[];
    for (let group of candidates) {
      let everyPublished=true;
      for (let id of group.questionIds) {
        let published=false;
        for (let q of items) {
          if (q.id===id && q.reviewStatus===ToeicReviewStatus.PUBLISHED) {
            published=true; break;
          }
        }
        if (!published) { everyPublished=false; break; }
      }
      if (everyPublished) groups.push(group);
    }
    return groups;
  }

  /** Return only the CURRENT members of published reading groups for group
   * integrity validation. Historic published revisions intentionally remain
   * outside this set so they can still restore old drafts/reports without
   * being mistaken for extra members of today's paper.
   */
  static readingGroupValidationQuestions(questions:ToeicQuestion[],
    groups:ToeicReadingGroup[]):ToeicQuestion[] {
    let activeIds:string[]=[];
    for (let group of groups) {
      for (let id of group.questionIds) {
        if (activeIds.indexOf(id)<0) activeIds.push(id);
      }
    }
    let result:ToeicQuestion[]=[];
    for (let question of questions) {
      if (activeIds.indexOf(question.id)>=0) result.push(question);
    }
    return result;
  }

  static publishedQuestions():ToeicQuestion[] {
    let source=PresetToeicContent.questions();
    let readyGroups=PresetToeicContent.publishedReadingGroups();
    let published:ToeicQuestion[]=[];
    for (let q of source) {
      if (q.reviewStatus!==ToeicReviewStatus.PUBLISHED) continue;
      // A published individual question cannot expose an incomplete shared
      // passage. Every sibling of its group must first be PUBLISHED too.
      if (q.groupId.length>0) {
        let groupReady=false;
        for (let group of readyGroups) {
          if (group.groupId===q.groupId) { groupReady=true; break; }
        }
        if (!groupReady) continue;
      }
      published.push(q);
    }
    let validation=ToeicContentValidator.validateAll(published);
    let groupValidation=ToeicContentValidator.validateReadingGroups(
      PresetToeicContent.readingGroupValidationQuestions(published,readyGroups),readyGroups);
    if (!validation.valid || !groupValidation.valid) return [];
    return published;
  }

  /** Exclude editorially flagged archived items from new learning queues only.
   * Keep publishedQuestions() intact for saved mock v1 reports/drafts.
   * Issue #478: the old R-M1-P7-094 date inference is not independently supported.
   */
  static liveTrainingQuestions():ToeicQuestion[] {
    let published=PresetToeicContent.publishedQuestions();
    let live:ToeicQuestion[]=[];
    for (let question of published) {
      if (question.id==='R-FM1-P7-M1-01' || question.id==='R-FM1-P7-M4-01' || question.id==='R-FM2-P7-M1-01' || question.id==='R-FM2-P7-M5-03' || question.id==='R-M1-P7-094' || question.id==='R-M2-P5-007' || question.id==='R-M1-P5-022' || question.id==='R-P5-VERB-0206' || question.id==='R-P5-SPRINT-1517' || question.id==='R-P6-SPRINT-1610' || question.id==='R-P5-SPRINT-1528' || question.id==='R-P6-SPRINT-1606' || question.id==='R-DX-P5-05' || question.id==='R-M2-P5-010' || question.id==='R-M2-P6-002' || question.id==='R-M2-P6-004' || question.id==='R-M1-P6-033' || question.id==='R-M2-P6-009' || question.id==='R-FM2-P6-004' || question.id==='R-M2-P6-008' || question.id==='R-FP1-P5-1528' || question.id==='R-FM1-P7-M2-03' || question.id==='R-FM1-P7-S09-01' || question.id==='R-FM2-P7-S07-03') continue;
      live.push(question);
    }
    return live;
  }

  /** The Day 1 plan is the only source of truth for the comprehensive diagnostic. */
  static diagnosticQuestions():ToeicQuestion[] {
    return PresetToeicContent.questionsForDay(1);
  }

  // Every published extra reading group has exactly one assigned day. Keep all five
  // sibling questions adjacent; changing the plan does not change their stable IDs.
  static supplementaryGroupIdsForDay(day:number):string[] {
    if (day===12) return ['P7-EX-VENUE','P7-EX-DELIVERY'];
    if (day===13) return ['P7-EX-TRAVEL','P7-EX-FILTER'];
    if (day===17) return ['P7-EX-ONBOARD','P7-EX-RETAIL','P7-EX-SUPPORT','P7-EX-LEASE'];
    if (day===18) return ['P7-EX-TRAINING','P7-EX-MIGRATION','P7-EX-LICENSE'];
    if (day===20) return ['P7-EX-PERDIEM','P7-EX-CATERING'];
    return [];
  }

  static supplementaryReadingQuestionsForDay(day:number):ToeicQuestion[] {
    let ids=PresetToeicContent.supplementaryGroupIdsForDay(day);
    let groups=PresetToeicContent.publishedReadingGroups();
    let all=PresetToeicContent.publishedQuestions();
    let result:ToeicQuestion[]=[];
    for (let id of ids) {
      for (let group of groups) {
        if (group.groupId!==id) continue;
        // Fail closed: never expose an incomplete five-question passage as a daily exercise.
        let ordered:ToeicQuestion[]=[];
        for (let questionId of group.questionIds) {
          for (let question of all) {
            if (question.id===questionId) { ordered.push(question); break; }
          }
        }
        if (ordered.length===group.questionIds.length) {
          for (let question of ordered) result.push(question);
        }
        break;
      }
    }
    return result;
  }

  static supplementaryReadingQuestions():ToeicQuestion[] {
    let all=PresetToeicContent.publishedQuestions();
    let ids:string[]=[];
    for (let group of PresetToeicContent.publishedReadingGroups()) {
      for (let id of group.questionIds) ids.push(id);
    }
    let result:ToeicQuestion[]=[];
    for (let id of ids) {
      for (let question of all) if (question.id===id) { result.push(question); break; }
    }
    return result;
  }

  /** Includes unpublished candidates strictly for validation and editorial review. */
  static vocabularyForReview():ToeicVocabularyItem[] {
    let base:ToeicVocabularyItem[]=[
      new ToeicVocabularyItem('V-001','applicant','n.','申请人；求职者',ToeicVocabularyLevel.L1,'招聘',['job applicant'],['candidate']),
      new ToeicVocabularyItem('V-002','candidate','n.','候选人；应聘者',ToeicVocabularyLevel.L1,'招聘',['qualified candidate'],['applicant']),
      new ToeicVocabularyItem('V-003','qualification','n.','资格；资历',ToeicVocabularyLevel.L1,'招聘',['meet the qualifications'],['requirement']),
      new ToeicVocabularyItem('V-004','eligible','adj.','符合资格的',ToeicVocabularyLevel.L2,'人事/福利',['be eligible for'],['qualify for']),
      new ToeicVocabularyItem('V-005','appointment','n.','预约；约定',ToeicVocabularyLevel.L1,'办公/服务',['make an appointment'],['scheduled meeting']),
      new ToeicVocabularyItem('V-006','available','adj.','可用的；有空的',ToeicVocabularyLevel.L1,'办公',['be available for'],['free','in stock']),
      new ToeicVocabularyItem('V-007','postpone','v.','推迟',ToeicVocabularyLevel.L2,'会议/日程',['postpone a meeting'],['delay']),
      new ToeicVocabularyItem('V-008','reschedule','v.','重新安排时间',ToeicVocabularyLevel.L2,'会议/日程',['reschedule an appointment'],['move to another time']),
      new ToeicVocabularyItem('V-009','deadline','n.','截止日期',ToeicVocabularyLevel.L1,'项目',['meet a deadline'],['due date']),
      new ToeicVocabularyItem('V-010','submit','v.','提交',ToeicVocabularyLevel.L1,'办公',['submit a form','submit a report'],['send for review']),
      new ToeicVocabularyItem('V-011','purchase','v./n.','购买；采购',ToeicVocabularyLevel.L1,'采购',['purchase equipment'],['buy']),
      new ToeicVocabularyItem('V-012','invoice','n.','发票；账单',ToeicVocabularyLevel.L1,'财务',['issue an invoice'],['bill']),
      new ToeicVocabularyItem('V-013','reimbursement','n.','报销；偿还',ToeicVocabularyLevel.L2,'财务',['receive reimbursement'],['repayment']),
      new ToeicVocabularyItem('V-014','refund','n./v.','退款；退还',ToeicVocabularyLevel.L1,'客户服务',['issue a refund'],['repayment']),
      new ToeicVocabularyItem('V-015','shipment','n.','货运；一批货物',ToeicVocabularyLevel.L1,'物流',['track a shipment'],['delivery']),
      new ToeicVocabularyItem('V-016','dispatch','v.','派送；发出',ToeicVocabularyLevel.L2,'物流',['dispatch an order'],['send']),
      new ToeicVocabularyItem('V-017','warehouse','n.','仓库',ToeicVocabularyLevel.L1,'物流',['warehouse staff'],['storage facility']),
      new ToeicVocabularyItem('V-018','inventory','n.','库存',ToeicVocabularyLevel.L2,'物流/零售',['check inventory'],['stock']),
      new ToeicVocabularyItem('V-019','complimentary','adj.','免费的；赠送的',ToeicVocabularyLevel.L2,'酒店/服务',['complimentary breakfast'],['free','at no charge']),
      new ToeicVocabularyItem('V-020','reservation','n.','预订',ToeicVocabularyLevel.L1,'酒店/旅行',['make a reservation'],['booking']),
      new ToeicVocabularyItem('V-021','accommodation','n.','住宿；住处',ToeicVocabularyLevel.L2,'旅行',['hotel accommodation'],['lodging']),
      new ToeicVocabularyItem('V-022','itinerary','n.','行程安排',ToeicVocabularyLevel.L2,'旅行',['travel itinerary'],['travel schedule']),
      new ToeicVocabularyItem('V-023','branch','n.','分店；分支机构',ToeicVocabularyLevel.L1,'公司运营',['downtown branch'],['local office']),
      new ToeicVocabularyItem('V-024','facility','n.','设施；场所',ToeicVocabularyLevel.L1,'公司运营',['office facility'],['site']),
      new ToeicVocabularyItem('V-025','renovation','n.','翻修；装修',ToeicVocabularyLevel.L2,'设施',['under renovation'],['improvement work']),
      new ToeicVocabularyItem('V-026','maintenance','n.','维护；保养',ToeicVocabularyLevel.L1,'设施',['scheduled maintenance'],['upkeep']),
      new ToeicVocabularyItem('V-027','approximately','adv.','大约',ToeicVocabularyLevel.L2,'通用',['approximately 20 minutes'],['about','roughly']),
      new ToeicVocabularyItem('V-028','notify','v.','通知',ToeicVocabularyLevel.L2,'办公',['notify employees'],['inform']),
      new ToeicVocabularyItem('V-029','retain','v.','保留；保持',ToeicVocabularyLevel.L2,'办公/人事',['retain records'],['keep']),
      new ToeicVocabularyItem('V-030','supplier','n.','供应商',ToeicVocabularyLevel.L1,'采购',['contact a supplier'],['vendor'])
    ];
    return ToeicPronunciationCatalog.apply(base.concat(ToeicWeekOneContent.vocabulary()).concat(ToeicVocabularyExpansion.items()).concat(ToeicVocabularyBatchTwo.items()).concat(ToeicVocabularyBatchThree.items()).concat(ToeicVocabularyBatchFour.items()).concat(ToeicVocabularyBatchFive.items()).concat(ToeicVocabularyBatchSix.items()).concat(ToeicVocabularyBatchSeven.items()));
  }

  static vocabulary():ToeicVocabularyItem[] {
    let all=PresetToeicContent.vocabularyForReview();
    let published:ToeicVocabularyItem[]=[];
    for (let item of all) {
      if (item.reviewStatus===ToeicReviewStatus.PUBLISHED) published.push(item);
    }
    return published;
  }

  static studyDays():ToeicStudyDay[] {
    let plans=ToeicWeekOneContent.studyDays().concat(ToeicWeekTwoContent.studyDays()).concat(ToeicWeekThreeContent.studyDays());
    // Keep the published v1 100-question bank unchanged for historical drafts.
    // Only *new* Day14 sessions use the structurally corrected v2 Part7.
    for (let plan of plans) {
      if (plan.day===1) {
        plan.questionIds=plan.questionIds.map((id:string):string =>
          id==='R-DX-P5-05' ? 'R-FP1-DX-P5-05' : id);
      } else if (plan.day===3) {
        plan.questionIds=plan.questionIds.map((id:string):string => id==='R-P5-VERB-0206' ? 'R-FP5-VERB-0206' : id);
      } else if (plan.day===15) {
        plan.questionIds=plan.questionIds.map((id:string):string => {
          if (id==='R-P5-SPRINT-1517') return 'R-FP5-SPRINT-1517';
          if (id==='R-P5-SPRINT-1528') return 'R-FP1-P5-1528';
          return id;
        });
      } else if (plan.day===16) {
        plan.questionIds=plan.questionIds.map((id:string):string => {
          if (id==='R-P6-SPRINT-1606') return 'R-FP1-P6-1606';
          if (id==='R-P6-SPRINT-1610') return 'R-FP6-SPRINT-1610';
          return id;
        });
      } else if (plan.day===14) {
        let ids=ToeicWeekTwoContent.mockQuestionIds().slice(0,46);
        ids[21]=ToeicMockDay14Part5V2Content.questions()[0].id;
        ids[32]=ToeicMockPart6V2RepairContent.day14().id;
        for (let question of ToeicMockDay14V2Content.questions()) ids.push(ToeicMockPart7EvidenceRevisionContent.activeId(question.id));
        plan.questionIds=ids;
      } else if (plan.day===19) {
        let ids=ToeicWeekThreeContent.mockQuestionIds().slice(0,46);
        // Archive old mock question R-M2-P5-007; v2 paper uses a distinct ID.
        ids[6]=ToeicMockDay19Part5V2Content.questions()[0].id;
        ids[38]=ToeicMockPart6V2RepairContent.day19().id;
        // Keep the old four published questions for historic drafts and reports;
        // only new Day19 sessions use the independent sentence-completion IDs.
        let revisedPart6=ToeicMockDay19Part6V2Content.questions();
        for (let i=0;i<revisedPart6.length;i++) ids[30+i]=revisedPart6[i].id;
        // Reapply editorial replacements AFTER the initial P6 group override.
        ids[33]=ToeicMockDay19Part6CompletionContent.inventory().id;
        ids[37]=ToeicMockDay19Part6CompletionContent.library().id;
        for (let question of ToeicMockDay19V2Content.questions()) ids.push(ToeicMockPart7EvidenceRevisionContent.activeId(question.id));
        plan.questionIds=ids;
      }
      // P3 is a release-state overlay: preserve the prior replacement IDs for
      // history, then route only current sessions to blind-review revisions.
      plan.questionIds=plan.questionIds.map((id:string):string => {
        if (id==='R-FP1-P5-1528') return 'R-FP3-P5-1528';
        return ToeicP3FinalCorrections.activePart7Id(id);
      });
    }
    return plans;
  }

  static sentenceDrills():ToeicSentenceDrill[] {
    return ToeicWeekOneContent.sentenceDrills().concat(ToeicWeekTwoContent.sentenceDrills()).concat(ToeicWeekThreeContent.sentenceDrills());
  }

  static studyDay(day:number):ToeicStudyDay {
    let plans=PresetToeicContent.studyDays();
    for (let plan of plans) if (plan.day===day) return plan;
    return plans[plans.length-1];
  }

  static isMockDay(day:number):boolean {
    return day===14 || day===19;
  }

  static isWeaknessDay(day:number):boolean { return day===18; }

  static isHighErrorReviewDay(day:number):boolean { return day===20; }

  static questionsThroughDay(maxDay:number):ToeicQuestion[] {
    let all=PresetToeicContent.liveTrainingQuestions();
    let plans=PresetToeicContent.studyDays();
    let result:ToeicQuestion[]=[];
    for (let plan of plans) {
      if (plan.day>maxDay) continue;
      for (let id of plan.questionIds) {
        for (let question of all) {
          if (question.id===id && !PresetToeicContent.containsQuestionId(result,question.id)) {
            result.push(question);
            break;
          }
        }
      }
    }
    // A v2 paper replaces only new Day14/19 sessions, never the archived
    // Part 7 answers stored in existing learners' error and slow-item queues.
    // Include published v1 P7 IDs as review candidates only after their day.
    // Do NOT re-add them to studyDays()/questionsForDay() for fresh mock runs.
    for (let question of all) {
      let oldDay14=maxDay>=14 && question.id.startsWith('R-M1-P7-');
      let oldDay19=maxDay>=19 && question.id.startsWith('R-M2-P7-');
      // Day19 v2 also replaces the first archived Part6 passage with four
      // independent sentence-completion IDs. Preserve historic P6 mistakes.
      let oldDay19Part6=maxDay>=19 && question.id.startsWith('R-M2-P6-');
      if ((oldDay14 || oldDay19 || oldDay19Part6) &&
          !PresetToeicContent.containsQuestionId(result,question.id)) result.push(question);
    }
    return result;
  }

  static questionsForDay(day:number):ToeicQuestion[] {
    let plan=PresetToeicContent.studyDay(day);
    let all=PresetToeicContent.liveTrainingQuestions();
    let result:ToeicQuestion[]=[];
    for (let id of plan.questionIds) {
      for (let question of all) if (question.id===id) { result.push(question); break; }
    }
    // Daily extra passages are genuine planned exercises, not a separate bonus session.
    // Historical Day14/19 items remain unchanged; new sessions use the two v2 banks.
    for (let question of PresetToeicContent.supplementaryReadingQuestionsForDay(day)) {
      if (!PresetToeicContent.containsQuestionId(result,question.id)) result.push(question);
    }
    return result;
  }

  static questionsRequiringTranslation():ToeicQuestion[] {
    let result:ToeicQuestion[]=[];
    for (let day=1; day<=21; day++) {
      if (PresetToeicContent.isMockDay(day)) continue;
      let dayQuestions=PresetToeicContent.questionsForDay(day);
      for (let question of dayQuestions) result.push(question);
    }
    return result;
  }

  static vocabularyForDay(day:number):ToeicVocabularyItem[] {
    let plan=PresetToeicContent.studyDay(day);
    let all=PresetToeicContent.vocabulary();
    let result:ToeicVocabularyItem[]=[];
    let assigned=plan.vocabularyIds.concat(ToeicVocabularyExpansion.idsForDay(day)).concat(ToeicVocabularyBatchTwo.idsForDay(day)).concat(ToeicVocabularyBatchThree.idsForDay(day)).concat(ToeicVocabularyBatchFour.idsForDay(day)).concat(ToeicVocabularyBatchFive.idsForDay(day)).concat(ToeicVocabularyBatchSix.idsForDay(day)).concat(ToeicVocabularyBatchSeven.idsForDay(day));
    for (let id of assigned) {
      for (let item of all) if (item.id===id) { result.push(item); break; }
    }
    return result;
  }

  static sentenceDrillsForDay(day:number):ToeicSentenceDrill[] {
    let plan=PresetToeicContent.studyDay(day);
    let all=PresetToeicContent.sentenceDrills();
    let result:ToeicSentenceDrill[]=[];
    for (let id of plan.sentenceDrillIds) {
      for (let item of all) if (item.id===id) { result.push(item); break; }
    }
    return result;
  }
  private static containsQuestionId(items:ToeicQuestion[],questionId:string):boolean {
    for (let item of items) if (item.id===questionId) return true;
    return false;
  }

}
