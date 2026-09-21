import { SourceGroupValidationStatus } from '../../domain/model/HomeworkSourceProfileModels';

export interface GroupTitleResolution {
  title: string;
  conflict: boolean;
}

export class DeterministicGroupTitlePolicy {
  normalize(value: string): string {
    let normalized = value.trim()
      .replace(/\s+/g, '')
      .replace(/（/g, '(')
      .replace(/）/g, ')')
      .toLowerCase();
    let memberCount = normalized.match(/\(\d{1,4}\)$/);
    if (memberCount !== null) {
      normalized = normalized.substring(0, normalized.length - memberCount[0].length);
    }
    return normalized;
  }

  validate(expected: string, detected: string): SourceGroupValidationStatus {
    let normalizedDetected = this.normalize(detected);
    if (normalizedDetected.length === 0) return SourceGroupValidationStatus.UNRECOGNIZED;
    return normalizedDetected === this.normalize(expected) ?
      SourceGroupValidationStatus.MATCHED : SourceGroupValidationStatus.MISMATCH;
  }

  resolve(values: string[]): GroupTitleResolution {
    let normalizedValues: string[] = [];
    let originals: string[] = [];
    let counts: number[] = [];

    for (let value of values) {
      let normalized = this.normalize(value);
      if (normalized.length === 0) continue;
      let index = normalizedValues.indexOf(normalized);
      if (index < 0) {
        normalizedValues.push(normalized);
        originals.push(value);
        counts.push(1);
      } else {
        counts[index]++;
      }
    }

    if (normalizedValues.length === 0) return { title: '', conflict: false };

    let bestIndex = 0;
    for (let i = 1; i < counts.length; i++) {
      if (counts[i] > counts[bestIndex]) bestIndex = i;
    }
    return {
      title: originals[bestIndex],
      conflict: normalizedValues.length > 1
    };
  }
}
