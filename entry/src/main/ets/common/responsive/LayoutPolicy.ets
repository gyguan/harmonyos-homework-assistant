import { AppTheme } from '../theme/AppTheme';

export class LayoutRequirement {
  primaryMinWidth: number;
  secondaryMinWidth: number;
  gap: number;
  horizontalPadding: number;

  constructor(primaryMinWidth: number, secondaryMinWidth: number, gap: number, horizontalPadding: number) {
    this.primaryMinWidth = primaryMinWidth;
    this.secondaryMinWidth = secondaryMinWidth;
    this.gap = gap;
    this.horizontalPadding = horizontalPadding;
  }
}

export class LayoutPolicy {
  static areaLengthToVp(value: Length, fallbackVp: number): number {
    if (typeof value === 'number') return Number.isFinite(value) && value > 0 ? value : fallbackVp;
    let parsed = Number.parseFloat(String(value));
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackVp;
  }

  // Shared responsive page inset. Feature code should not infer Phone/Pad from a device model.
  static pagePaddingForWidth(availableWidthVp: number): number {
    if (!Number.isFinite(availableWidthVp) || availableWidthVp <= 600) {
      return AppTheme.PAGE_PADDING_COMPACT;
    }
    if (availableWidthVp <= 840) return AppTheme.PAGE_PADDING_MEDIUM;
    return AppTheme.PAGE_PADDING_EXPANDED;
  }

  static homeFocusSummaryRequirement(): LayoutRequirement {
    return new LayoutRequirement(AppTheme.HOME_PRIMARY_MIN_WIDTH, AppTheme.HOME_SECONDARY_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP, AppTheme.PAGE_PADDING_WIDE);
  }

  static parentHomeRequirement(): LayoutRequirement {
    return new LayoutRequirement(AppTheme.PARENT_HOME_PRIMARY_MIN_WIDTH, AppTheme.PARENT_HOME_SECONDARY_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP, AppTheme.PAGE_PADDING_WIDE);
  }

  static assignmentMasterDetailRequirement(): LayoutRequirement {
    return new LayoutRequirement(AppTheme.SPLIT_PRIMARY_MIN_WIDTH, AppTheme.SPLIT_SECONDARY_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP, AppTheme.PAGE_PADDING_WIDE);
  }

  static parentProgressReviewRequirement(): LayoutRequirement {
    return new LayoutRequirement(AppTheme.PARENT_PROGRESS_LIST_MIN_WIDTH, AppTheme.PARENT_REVIEW_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP, AppTheme.PAGE_PADDING_WIDE);
  }

  static importOrganizeRequirement(): LayoutRequirement {
    return new LayoutRequirement(AppTheme.IMPORT_SOURCE_MIN_WIDTH, AppTheme.IMPORT_CANDIDATE_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP, AppTheme.PAGE_PADDING_WIDE);
  }

  static studyTutorRequirement(): LayoutRequirement {
    return new LayoutRequirement(AppTheme.STUDY_PRIMARY_MIN_WIDTH, AppTheme.STUDY_TUTOR_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP, AppTheme.PAGE_PADDING_WIDE);
  }

  static settingsInlineFieldsRequirement(): LayoutRequirement {
    return new LayoutRequirement(AppTheme.SETTINGS_INLINE_FIELD_MIN_WIDTH, AppTheme.SETTINGS_INLINE_FIELD_MIN_WIDTH,
      8, AppTheme.PAGE_PADDING);
  }

  static requiredWidth(requirement: LayoutRequirement): number {
    return requirement.primaryMinWidth + requirement.secondaryMinWidth + requirement.gap +
      requirement.horizontalPadding * 2;
  }

  static canSplit(availableWidthVp: number, requirement: LayoutRequirement): boolean {
    return Number.isFinite(availableWidthVp) && availableWidthVp >= LayoutPolicy.requiredWidth(requirement);
  }
}
