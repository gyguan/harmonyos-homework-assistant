export enum ToeicSection { LISTENING = 'LISTENING', READING = 'READING' }
export enum ToeicPart { PART_1='PART_1', PART_2='PART_2', PART_3='PART_3', PART_4='PART_4', PART_5='PART_5', PART_6='PART_6', PART_7='PART_7' }
export enum ToeicDifficulty { EASY='EASY', MEDIUM='MEDIUM', HARD='HARD' }
export enum ToeicScoreValue { MUST_GET='MUST_GET', NORMAL='NORMAL', OPTIONAL='OPTIONAL' }
export enum ToeicReviewStatus { DRAFT='DRAFT', VALIDATED='VALIDATED', REVIEWED='REVIEWED', PUBLISHED='PUBLISHED', RETIRED='RETIRED' }
export enum ToeicVocabularyLevel { L1='L1', L2='L2', L3='L3' }
export enum ToeicSkill {
  CORE_WORD='CORE_WORD', COLLOCATION='COLLOCATION', WORD_FORM='WORD_FORM', PARAPHRASE='PARAPHRASE',
  MAIN_STRUCTURE='MAIN_STRUCTURE', MODIFIER='MODIFIER', CLAUSE='CLAUSE', LOGIC='LOGIC',
  VERB='VERB', AGREEMENT='AGREEMENT', VOICE='VOICE', PREPOSITION='PREPOSITION',
  CONJUNCTION='CONJUNCTION', PRONOUN='PRONOUN', RELATIVE='RELATIVE', VOCABULARY='VOCABULARY',
  CONTEXT='CONTEXT', REFERENCE='REFERENCE', SENTENCE_INSERTION='SENTENCE_INSERTION',
  PURPOSE='PURPOSE', MAIN_IDEA='MAIN_IDEA', DETAIL='DETAIL', VOCAB_IN_CONTEXT='VOCAB_IN_CONTEXT',
  INFERENCE='INFERENCE', SENTENCE_LOCATION='SENTENCE_LOCATION', CROSS_DOCUMENT='CROSS_DOCUMENT',
  SOUND_RECOGNITION='SOUND_RECOGNITION', PERSON_ACTION='PERSON_ACTION', OBJECT_STATE='OBJECT_STATE',
  LOCATION='LOCATION', WH_QUESTION='WH_QUESTION', YES_NO='YES_NO', INDIRECT_RESPONSE='INDIRECT_RESPONSE',
  INTENT='INTENT', SCENE='SCENE', NEXT_ACTION='NEXT_ACTION', TALK_TYPE='TALK_TYPE'
}
export enum ToeicPerformance { FAST_CORRECT='FAST_CORRECT', SLOW_CORRECT='SLOW_CORRECT', FAST_WRONG='FAST_WRONG', SLOW_WRONG='SLOW_WRONG' }

export class ToeicQuestion {
  id:string; section:ToeicSection; part:ToeicPart; skill:ToeicSkill; passage:string; stem:string; options:string[];
  correctIndex:number; explanation:string; evidence:string; paraphrase:string; recommendedSeconds:number;
  difficulty:ToeicDifficulty; scoreValue:ToeicScoreValue; reviewStatus:ToeicReviewStatus; version:number;
  audioAssetId:string; transcript:string; evidenceStartMs:number; evidenceEndMs:number;
  constructor(id:string, section:ToeicSection, part:ToeicPart, skill:ToeicSkill, passage:string, stem:string,
    options:string[], correctIndex:number, explanation:string, evidence:string, paraphrase:string,
    recommendedSeconds:number, difficulty:ToeicDifficulty, scoreValue:ToeicScoreValue,
    reviewStatus:ToeicReviewStatus=ToeicReviewStatus.PUBLISHED, version:number=1,
    audioAssetId:string='', transcript:string='', evidenceStartMs:number=0, evidenceEndMs:number=0) {
    this.id=id; this.section=section; this.part=part; this.skill=skill; this.passage=passage; this.stem=stem;
    this.options=options; this.correctIndex=correctIndex; this.explanation=explanation; this.evidence=evidence;
    this.paraphrase=paraphrase; this.recommendedSeconds=recommendedSeconds; this.difficulty=difficulty;
    this.scoreValue=scoreValue; this.reviewStatus=reviewStatus; this.version=version; this.audioAssetId=audioAssetId;
    this.transcript=transcript; this.evidenceStartMs=evidenceStartMs; this.evidenceEndMs=evidenceEndMs;
  }
}

export class ToeicVocabularyItem {
  id:string; word:string; partOfSpeech:string; meaning:string; level:ToeicVocabularyLevel; scenario:string;
  collocations:string[]; paraphrases:string[];
  constructor(id:string, word:string, partOfSpeech:string, meaning:string, level:ToeicVocabularyLevel,
    scenario:string, collocations:string[], paraphrases:string[]) {
    this.id=id; this.word=word; this.partOfSpeech=partOfSpeech; this.meaning=meaning; this.level=level;
    this.scenario=scenario; this.collocations=collocations; this.paraphrases=paraphrases;
  }
}

export class ToeicQuestionAttempt {
  questionId:string; part:ToeicPart; skill:ToeicSkill; selectedIndex:number; correct:boolean; elapsedSeconds:number;
  performance:ToeicPerformance;
  constructor(questionId:string, part:ToeicPart, skill:ToeicSkill, selectedIndex:number, correct:boolean,
    elapsedSeconds:number, performance:ToeicPerformance) {
    this.questionId=questionId; this.part=part; this.skill=skill; this.selectedIndex=selectedIndex;
    this.correct=correct; this.elapsedSeconds=elapsedSeconds; this.performance=performance;
  }
}

export class ToeicDiagnosticSummary {
  correctCount:number=0; totalCount:number=0; slowCount:number=0; weakSkill:ToeicSkill=ToeicSkill.PARAPHRASE;
  part5Correct:number=0; part5Total:number=0; part6Correct:number=0; part6Total:number=0;
  part7Correct:number=0; part7Total:number=0;
}

export class ToeicLearningSnapshot {
  schemaVersion:number=1; diagnosticCompleted:boolean=false; currentDay:number=1; completedTrainingSessions:number=0;
  totalAnswered:number=0; totalCorrect:number=0; weakSkill:string=ToeicSkill.PARAPHRASE;
  reviewQuestionIds:string[]=[]; slowQuestionIds:string[]=[];
}

export class ToeicStudyPlan {
  targetReadingScore:number=350; durationDays:number=21; dailyMinutes:number=90;
}

export class ToeicTrainingSession {
  attempts:ToeicQuestionAttempt[];
  constructor(attempts:ToeicQuestionAttempt[]) { this.attempts=attempts; }
}


export class ToeicSentenceDrill {
  id:string;
  sentence:string;
  core:string;
  focus:string;
  explanation:string;

  constructor(id:string, sentence:string, core:string, focus:string, explanation:string) {
    this.id=id;
    this.sentence=sentence;
    this.core=core;
    this.focus=focus;
    this.explanation=explanation;
  }
}

export class ToeicStudyDay {
  day:number;
  title:string;
  focus:string;
  estimatedMinutes:number;
  vocabularyIds:string[];
  sentenceDrillIds:string[];
  questionIds:string[];

  constructor(day:number, title:string, focus:string, estimatedMinutes:number,
    vocabularyIds:string[], sentenceDrillIds:string[], questionIds:string[]) {
    this.day=day;
    this.title=title;
    this.focus=focus;
    this.estimatedMinutes=estimatedMinutes;
    this.vocabularyIds=vocabularyIds;
    this.sentenceDrillIds=sentenceDrillIds;
    this.questionIds=questionIds;
  }
}
