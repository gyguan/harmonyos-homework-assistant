import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';

export interface AssignmentAudioPlayerCallbacks {
  onPrepared: (durationMs: number) => void;
  onState: (state: media.AVPlayerState) => void;
  onTime: (timeMs: number) => void;
  onError: (message: string) => void;
}

/**
 * AVPlayer is required in production while Media.Core remains optional for broader device coverage.
 * Both capabilities are guarded directly at runtime before the MediaKit creation path.
 */
export class AssignmentAudioPlayerService {
  private player: media.AVPlayer | null = null;
  private sourceFile: fileIo.File | null = null;
  private callbacks: AssignmentAudioPlayerCallbacks | null = null;
  /** 每次 prepare 自增：快速换源时旧请求的 catch 不能误释放新请求的 player。 */
  private prepareSeq: number = 0;

  async prepare(sourceUri: string, callbacks: AssignmentAudioPlayerCallbacks): Promise<void> {
    let seq = ++this.prepareSeq;
    await this.release();
    // release() 期间又有一次 prepare 进来：本次已经过时，连 callbacks 都不要挂。
    if (seq !== this.prepareSeq) return;
    this.callbacks = callbacks;
    let player: media.AVPlayer | null = null;
    let source: fileIo.File | null = null;
    try {
      if (canIUse('SystemCapability.Multimedia.Media.AVPlayer')) {
        if (canIUse('SystemCapability.Multimedia.Media.Core')) {
          // Runtime SysCap guards above are intentional; API 26 compiler cannot narrow canIUse() for MediaKit.
          // @SuppressWarnings syscap
          player = await media.createAVPlayer();
          if (seq !== this.prepareSeq) {
            await this.discardUnused(player, source);
            return;
          }
          this.player = player;
          let owned = player;
          player.on('stateChange', (state: media.AVPlayerState) => {
            if (this.player !== owned || seq !== this.prepareSeq) return;
            callbacks.onState(state);
            if (state === 'initialized') {
              void owned.prepare();
            } else if (state === 'prepared') {
              callbacks.onPrepared(owned.duration > 0 ? owned.duration : 0);
            } else if (state === 'completed') {
              callbacks.onTime(owned.duration > 0 ? owned.duration : 0);
            }
          });
          player.on('timeUpdate', (timeMs: number) => {
            if (this.player === owned && seq === this.prepareSeq) callbacks.onTime(timeMs);
          });
          player.on('error', (error: BusinessError) => {
            if (this.player === owned && seq === this.prepareSeq) callbacks.onError(error.message);
          });

          source = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
          if (seq !== this.prepareSeq) {
            await this.discardUnused(player, source);
            return;
          }
          this.sourceFile = source;
          let descriptor: media.AVFileDescriptor = { fd: source.fd, offset: 0, length: -1 };
          player.fdSrc = descriptor;
          return;
        }
      }
    } catch {
      if (seq !== this.prepareSeq) {
        // A 的失败只清理 A 自己创建的资源；绝不能调 release() 把 B 的 player 一起带走。
        await this.discardUnused(player, source);
        return;
      }
      callbacks.onError('语音准备失败');
      await this.release();
      return;
    }
    if (seq !== this.prepareSeq) return;
    callbacks.onError('当前设备不支持语音播放');
    this.callbacks = null;
  }

  /** 释放「还没挂到实例上」或已被更新请求取代的资源。 */
  private async discardUnused(player: media.AVPlayer | null, source: fileIo.File | null): Promise<void> {
    if (player !== null) {
      if (this.player === player) this.player = null;
      try {
        if (player.state !== 'released') await player.release();
      } catch {
        // 更新的一次 prepare 可能已经释放过，重复释放忽略即可。
      }
    }
    if (source !== null) {
      if (this.sourceFile === source) this.sourceFile = null;
      try {
        await fileIo.close(source);
      } catch {
        // 同上，fd 可能已被关闭。
      }
    }
  }

  async play(): Promise<void> {
    let player = this.player;
    if (player === null) return;
    if (player.state !== 'prepared' && player.state !== 'paused' && player.state !== 'completed') return;
    try {
      await player.play();
    } catch {
      if (this.callbacks !== null) this.callbacks.onError('语音播放失败');
    }
  }

  async pause(): Promise<void> {
    let player = this.player;
    if (player === null || player.state !== 'playing') return;
    try {
      await player.pause();
    } catch {
      if (this.callbacks !== null) this.callbacks.onError('语音暂停失败');
    }
  }

  seek(timeMs: number): void {
    if (canIUse('SystemCapability.Multimedia.Media.AVPlayer')) {
      let player = this.player;
      if (player === null) return;
      if (player.state !== 'prepared' && player.state !== 'playing' &&
        player.state !== 'paused' && player.state !== 'completed') return;
      let duration = player.duration > 0 ? player.duration : 0;
      let target = Math.floor(Math.max(0, duration > 0 ? Math.min(timeMs, duration) : timeMs));
      try {
        player.seek(target);
      } catch {
        if (this.callbacks !== null) this.callbacks.onError('无法跳转到该播放位置');
      }
      return;
    }
    if (this.callbacks !== null) this.callbacks.onError('当前设备不支持语音播放');
  }

  async release(): Promise<void> {
    let player = this.player;
    this.player = null;
    this.callbacks = null;
    if (player !== null && player.state !== 'released') {
      try {
        await player.release();
      } catch {
        // Release is best-effort during page teardown.
      }
    }
    if (this.sourceFile !== null) {
      try {
        await fileIo.close(this.sourceFile);
      } catch {
        // Closing is best-effort after the player has released the descriptor.
      }
      this.sourceFile = null;
    }
  }
}
