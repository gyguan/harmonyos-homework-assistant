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
  static homeFocusSummaryRequirement(): LayoutRequirement {
    return new LayoutRequirement(
      AppTheme.HOME_PRIMARY_MIN_WIDTH,
      AppTheme.HOME_SECONDARY_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP,
      AppTheme.PAGE_PADDING_WIDE
    );
  }

  static assignmentMasterDetailRequirement(): LayoutRequirement {
    return new LayoutRequirement(
      AppTheme.SPLIT_PRIMARY_MIN_WIDTH,
      AppTheme.SPLIT_SECONDARY_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP,
      AppTheme.PAGE_PADDING_WIDE
    );
  }

  static studyTutorRequirement(): LayoutRequirement {
    return new LayoutRequirement(
      AppTheme.STUDY_PRIMARY_MIN_WIDTH,
      AppTheme.STUDY_TUTOR_MIN_WIDTH,
      AppTheme.SPLIT_PANE_GAP,
      AppTheme.PAGE_PADDING_WIDE
    );
  }

  static requiredWidth(requirement: LayoutRequirement): number {
    return requirement.primaryMinWidth +
      requirement.secondaryMinWidth +
      requirement.gap +
      requirement.horizontalPadding * 2;
  }

  static canSplit(availableWidthVp: number, requirement: LayoutRequirement): boolean {
    return Number.isFinite(availableWidthVp) &&
      availableWidthVp >= LayoutPolicy.requiredWidth(requirement);
  }
}
