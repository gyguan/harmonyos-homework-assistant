import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from '../../application/remote/BackendHttpClient';
import { ToeicVocabularyRecall } from '../domain/ToeicModels';

export interface RemoteToeicVocabularyRecall {
  vocabularyId:string;
  remembered:boolean;
  streak:number;
  totalReviews:number;
  nextDueAtEpochMs:number;
  lastReviewedAtEpochMs:number;
  updatedAtEpochMs:number;
}

interface ToeicVocabularyRecallUpsertBody {
  remembered:boolean;
  streak:number;
  totalReviews:number;
  nextDueAtEpochMs:number;
  lastReviewedAtEpochMs:number;
}

export class ToeicVocabularyRemoteApi {
  static readonly instance:ToeicVocabularyRemoteApi=new ToeicVocabularyRemoteApi();
  private constructor() {}

  async list(studentId:string):Promise<RemoteToeicVocabularyRecall[]> {
    let response=await BackendHttpClient.instance.requestFor(
      'toeic.vocabularyRecall.list',
      `/api/v1/students/${encodeURIComponent(studentId)}/toeic/vocabulary-recalls`,
      http.RequestMethod.GET);
    if (response.statusCode<200 || response.statusCode>=300) {
      throw new Error(`读取 TOEIC 单词云端进度失败: ${response.statusCode}`);
    }
    return JSON.parse(response.body) as RemoteToeicVocabularyRecall[];
  }

  async save(studentId:string, recall:ToeicVocabularyRecall,
    remembered:boolean):Promise<RemoteToeicVocabularyRecall> {
    let body:ToeicVocabularyRecallUpsertBody={
      remembered:remembered,
      streak:recall.streak,
      totalReviews:recall.totalReviews,
      nextDueAtEpochMs:recall.nextDueAtMs,
      lastReviewedAtEpochMs:recall.lastReviewedAtMs
    };
    let response=await BackendHttpClient.instance.requestFor(
      'toeic.vocabularyRecall.save',
      `/api/v1/students/${encodeURIComponent(studentId)}/toeic/vocabulary-recalls/${encodeURIComponent(recall.vocabularyId)}`,
      http.RequestMethod.PUT,body);
    if (response.statusCode<200 || response.statusCode>=300) {
      throw new Error(`保存 TOEIC 单词云端进度失败: ${response.statusCode}`);
    }
    return JSON.parse(response.body) as RemoteToeicVocabularyRecall;
  }
}
