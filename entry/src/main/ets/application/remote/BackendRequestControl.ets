/** One caller-owned cancellation scope. Does not promise cancellation of server-side work. */
export class BackendRequestControl {
  private stoppedReason: string = '';
  private listeners: (() => void)[] = [];

  isStopped(): boolean { return this.stoppedReason.length > 0; }

  ensureActive(): void {
    if (this.isStopped()) throw new Error(this.stoppedReason);
  }

  stop(reason: string): void {
    if (this.isStopped()) return;
    this.stoppedReason = reason;
    let listeners = this.listeners.slice();
    this.listeners = [];
    for (let listener of listeners) listener();
  }

  onStop(listener: () => void): () => void {
    if (this.isStopped()) listener();
    else this.listeners.push(listener);
    return () => { this.listeners = this.listeners.filter(item => item !== listener); };
  }
}
