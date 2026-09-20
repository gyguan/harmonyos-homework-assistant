import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';

export interface AssignmentAudioPlayerCallbacks {
  onPrepared: (durationMs: number) => void;
  onState: (state: media.AVPlayerState) => void;
  onTime: (timeMs: number) => void;
  onError: (message: string) => void;
}

export class AssignmentAudioPlayerService {
  private player: media.AVPlayer | null = null;
  private sourceFile: fileIo.File | null = null;
  private callbacks: AssignmentAudioPlayerCallbacks | null = null;

  async prepare(sourceUri: string, callbacks: AssignmentAudioPlayerCallbacks): Promise<void> {
    await this.release();
    this.callbacks = callbacks;
    if (!canIUse('SystemCapability.Multimedia.Media.AVPlayer')) {
      callbacks.onError('当前设备不支持语音播放');
      this.callbacks = null;
      return;
    }
    try {
      let player = await media.createAVPlayer();
      this.player = player;
      player.on('stateChange', (state: media.AVPlayerState) => {
        if (this.player !== player) return;
        callbacks.onState(state);
        if (state === 'initialized') {
          void player.prepare();
        } else if (state === 'prepared') {
          callbacks.onPrepared(player.duration > 0 ? player.duration : 0);
        } else if (state === 'completed') {
          callbacks.onTime(player.duration > 0 ? player.duration : 0);
        }
      });
      player.on('timeUpdate', (timeMs: number) => {
        if (this.player === player) callbacks.onTime(timeMs);
      });
      player.on('error', (error: BusinessError) => {
        if (this.player === player) callbacks.onError(error.message);
      });

      let source = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      this.sourceFile = source;
      let descriptor: media.AVFileDescriptor = { fd: source.fd, offset: 0, length: -1 };
      player.fdSrc = descriptor;
    } catch {
      callbacks.onError('语音准备失败');
      await this.release();
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
    if (!canIUse('SystemCapability.Multimedia.Media.AVPlayer')) {
      if (this.callbacks !== null) this.callbacks.onError('当前设备不支持语音播放');
      return;
    }
    let player = this.player;
    if (player === null) return;
    if (player.state !== 'prepared' && player.state !== 'playing' &&
      player.state !== 'paused' && player.state !== 'completed') return;
    let duration = player.duration > 0 ? player.duration : 0;
    let target = Math.floor(Math.max(0, duration > 0 ? Math.min(timeMs, duration) : timeMs));
    try {
      player.seek(target, media.SeekMode.SEEK_PREV_SYNC);
    } catch {
      if (this.callbacks !== null) this.callbacks.onError('无法跳转到该播放位置');
    }
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
