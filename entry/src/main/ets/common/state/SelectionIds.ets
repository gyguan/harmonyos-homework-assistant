export class SelectionIds {
  static contains(selectedIds: string[], id: string): boolean {
    for (let selectedId of selectedIds) if (selectedId === id) return true;
    return false;
  }

  static toggle(selectedIds: string[], id: string): string[] {
    let next: string[] = [];
    let removed = false;
    for (let selectedId of selectedIds) {
      if (selectedId === id) removed = true;
      else next.push(selectedId);
    }
    if (!removed) next.push(id);
    return next;
  }

  static without(selectedIds: string[], id: string): string[] {
    let next: string[] = [];
    for (let selectedId of selectedIds) if (selectedId !== id) next.push(selectedId);
    return next;
  }

  static copy(ids: string[]): string[] {
    return ids.slice();
  }
}
