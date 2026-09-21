import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import {
  HomeworkShareRecordKind,
  PendingHomeworkShareImport,
  PendingHomeworkShareRecord
} from '../../domain/model/HomeworkShareModels';
import { PreferencesHomeworkShareHandoffPersistence } from '../../infrastructure/persistence/PreferencesHomeworkShareHandoffPersistence';

const SHARE_DIR_NAME: string = 'homework_share_import';

export class HomeworkShareReceiveService {
  private readonly context: common.Context;
  private readonly persistence: PreferencesHomeworkShareHandoffPersistence;

  constructor(context: common.Context) {
    this.context = context;
    this.persistence = new PreferencesHomeworkShareHandoffPersistence(context);
  }

  async receive(records: systemShare.SharedRecord[]): Promise<PendingHomeworkShareImport> {
    if (records.length === 0) throw new Error('没有收到可导入的分享内容');
    let token = `share-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    let accepted: PendingHomeworkShareRecord[] = [];

    try {
      for (let i = 0; i < records.length; i++) {
        let record = records[i];
        let content = record.content === undefined ? '' : record.content.trim();
        let uri = record.uri === undefined ? '' : record.uri.trim();
        if (uri.length > 0) {
          let sandboxUri = this.copyImageToSandbox(uri, token, i + 1, record.utd);
          accepted.push({
            id: `${token}-record-${i + 1}`,
            kind: HomeworkShareRecordKind.IMAGE,
            utd: record.utd,
            content: content,
            sandboxUri: sandboxUri,
            title: record.title === undefined ? '' : record.title
          });
          continue;
        }
        if (content.length > 0) {
          accepted.push({
            id: `${token}-record-${i + 1}`,
            kind: HomeworkShareRecordKind.TEXT,
            utd: record.utd,
            content: content,
            sandboxUri: '',
            title: record.title === undefined ? '' : record.title
          });
        }
      }

      if (accepted.length === 0) throw new Error('分享内容中没有可识别的文字或图片');
      let pending: PendingHomeworkShareImport = {
        token: token,
        createdAtEpochMs: Date.now(),
        records: accepted
      };
      await this.persistence.save(pending);
      return pending;
    } catch {
      this.cleanupRecords(accepted);
      throw new Error('系统分享接收失败');
    }
  }

  private copyImageToSandbox(sourceUri: string, token: string, sequence: number, utd: string): string {
    let directory = `${this.context.filesDir}/${SHARE_DIR_NAME}`;
    try {
      fileIo.mkdirSync(directory);
    } catch {
      // Directory already exists or cannot be recreated; opening the destination below is authoritative.
    }

    let suffix = this.imageSuffix(utd);
    let destination = `${directory}/${token}-${sequence}${suffix}`;
    try {
      let sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      try {
        let destinationFile = fileIo.openSync(
          destination,
          fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          let bufferSize = 64 * 1024;
          let buffer = new ArrayBuffer(bufferSize);
          let readOffset = 0;
          while (true) {
            let readLength = fileIo.readSync(sourceFile.fd, buffer, {
              offset: readOffset,
              length: bufferSize
            });
            if (readLength <= 0) break;
            fileIo.writeSync(destinationFile.fd, buffer, { length: readLength });
            readOffset += readLength;
            if (readLength < bufferSize) break;
          }
        } finally {
          fileIo.closeSync(destinationFile);
        }
      } finally {
        fileIo.closeSync(sourceFile);
      }
      return destination;
    } catch {
      try {
        fileIo.unlinkSync(destination);
      } catch {
        // The destination may not have been created yet.
      }
      throw new Error('复制分享图片失败');
    }
  }

  private imageSuffix(utd: string): string {
    let normalized = utd.toLowerCase();
    if (normalized.indexOf('png') >= 0) return '.png';
    if (normalized.indexOf('jpeg') >= 0 || normalized.indexOf('jpg') >= 0) return '.jpg';
    if (normalized.indexOf('webp') >= 0) return '.webp';
    return '.img';
  }

  private cleanupRecords(records: PendingHomeworkShareRecord[]): void {
    for (let record of records) {
      if (record.sandboxUri.length === 0) continue;
      try {
        fileIo.unlinkSync(record.sandboxUri);
      } catch {
        // Best-effort cleanup for a receive operation that never became a persisted handoff.
      }
    }
  }
}
