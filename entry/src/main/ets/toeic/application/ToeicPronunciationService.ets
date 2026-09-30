import { BusinessError } from '@kit.BasicServicesKit';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { ToeicVocabularyItem } from '../domain/ToeicModels';

export enum ToeicPronunciationStatus {
  PLAYED='PLAYED',
  DOWNLOAD_STARTED='DOWNLOAD_STARTED',
  UNSUPPORTED='UNSUPPORTED',
  FAILED='FAILED'
}

export class ToeicPronunciationService {
  static readonly instance:ToeicPronunciationService=new ToeicPronunciationService();

  private engine:textToSpeech.TextToSpeechEngine|null=null;
  private requestSequence:number=0;
  private downloadInProgress:boolean=false;

  private constructor() {}

  async speak(item:ToeicVocabularyItem):Promise<ToeicPronunciationStatus> {
    if (!canIUse('SystemCapability.AI.TextToSpeech')) return ToeicPronunciationStatus.UNSUPPORTED;

    let engine=await this.ensureEngine(item.pronunciationLocale);
    if (engine===null) {
      if (this.downloadInProgress) return ToeicPronunciationStatus.DOWNLOAD_STARTED;
      return await this.requestEnglishVoiceDownload();
    }

    let extraParams:Record<string,Object>={
      'speed': 0.9,
      'volume': 2,
      'pitch': 1,
      'languageContext': item.pronunciationLocale,
      'audioType': 'pcm',
      'playType': 1,
      'queueMode': 1
    };
    let params:textToSpeech.SpeakParams={
      requestId: this.nextRequestId('speak'),
      extraParams: extraParams
    };

    try {
      engine.speak(item.pronunciationText,params);
      return ToeicPronunciationStatus.PLAYED;
    } catch {
      return ToeicPronunciationStatus.FAILED;
    }
  }

  private async ensureEngine(locale:string):Promise<textToSpeech.TextToSpeechEngine|null> {
    if (this.engine!==null) return this.engine;

    let extraParams:Record<string,Object>={
      'style': 'interaction-broadcast',
      'locate': 'CN',
      'name': 'ToeicEnglishPronunciation'
    };
    let params:textToSpeech.CreateEngineParams={
      language: locale,
      person: 8,
      online: 1,
      extraParams: extraParams
    };

    try {
      this.engine=await textToSpeech.createEngine(params);
      return this.engine;
    } catch {
      this.engine=null;
      return null;
    }
  }

  private requestEnglishVoiceDownload():Promise<ToeicPronunciationStatus> {
    return new Promise<ToeicPronunciationStatus>((resolve)=>{
      let params:textToSpeech.VoiceDownload={
        requestId: this.nextRequestId('voice'),
        language: 'en-US',
        person: 8,
        style: 'interaction-broadcast'
      };
      try {
        this.downloadInProgress=true;
        textToSpeech.downloadVoice(params,(error:BusinessError,response:textToSpeech.DownloadResponse)=>{
          if (error) {
            this.downloadInProgress=false;
            resolve(ToeicPronunciationStatus.FAILED);
            return;
          }
          response.on('complete',(_voiceInfo:textToSpeech.VoiceInfo)=>{
            this.downloadInProgress=false;
            this.engine=null;
          });
          response.on('cancel',(_info:string)=>{
            this.downloadInProgress=false;
          });
          response.on('error',(_downloadError:BusinessError)=>{
            this.downloadInProgress=false;
          });
          resolve(ToeicPronunciationStatus.DOWNLOAD_STARTED);
        });
      } catch {
        this.downloadInProgress=false;
        resolve(ToeicPronunciationStatus.FAILED);
      }
    });
  }

  private nextRequestId(prefix:string):string {
    this.requestSequence++;
    return prefix+'-'+Date.now()+'-'+this.requestSequence;
  }
}
