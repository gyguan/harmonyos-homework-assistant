export class AppTheme {
  static readonly PRIMARY: string = '#0A59F7';
  static readonly PRIMARY_PRESSED: string = '#0847C7';
  static readonly PRIMARY_SOFT: string = '#EAF2FF';
  static readonly PRIMARY_FAINT: string = '#F4F7FF';
  static readonly BACKGROUND: string = '#F5F5F7';
  static readonly SURFACE: string = '#FFFFFF';
  // All ordinary content cards use one surface. Selection/emphasis is expressed by borders, icons or badges.
  static readonly CARD_SURFACE: string = '#FFFFFF';
  static readonly SURFACE_SUBTLE: string = '#F7F7F8';
  static readonly SURFACE_EMPHASIS: string = '#F0F1F4';
  static readonly DIVIDER: string = '#D9DADE';
  static readonly BORDER: string = '#D3D5DA';
  static readonly TEXT: string = '#1D1D1F';
  static readonly SUBTEXT: string = '#5F6268';
  static readonly TERTIARY_TEXT: string = '#6F7278';
  static readonly TEXT_ON_PRIMARY: string = '#FFFFFF';
  static readonly SUCCESS: string = '#0A7047';
  static readonly SUCCESS_SOFT: string = '#EAF8F1';
  static readonly WARNING: string = '#8C4800';
  static readonly WARNING_SOFT: string = '#FFF5E6';
  static readonly DANGER: string = '#A8233D';
  static readonly DANGER_SOFT: string = '#FDECEF';
  static readonly DISABLED: string = '#7D818A';

  static readonly PAGE_PADDING: number = 20;
  static readonly PAGE_PADDING_WIDE: number = 32;
  static readonly SECTION_GAP: number = 20;
  static readonly ITEM_GAP: number = 12;
  static readonly CARD_PADDING: number = 18;
  static readonly CARD_RADIUS: number = 20;
  static readonly CONTROL_RADIUS: number = 14;
  static readonly CHIP_RADIUS: number = 12;

  // Readable-width tokens are upper bounds: compact layouts still size to the actual container.
  // Issue #266 widens only large-container ceilings so Phone composition remains unchanged.
  static readonly HOME_READABLE_MAX_WIDTH: number = 760;
  static readonly HOME_PAD_CONTENT_MAX_WIDTH: number = 1360;
  static readonly HOME_PAD_PRIMARY_ACTION_MAX_WIDTH: number = 320;
  static readonly ASSIGNMENT_LIST_READABLE_MAX_WIDTH: number = 760;
  static readonly ASSIGNMENT_DETAIL_READABLE_MAX_WIDTH: number = 1040;
  static readonly ASSIGNMENT_MASTER_DETAIL_MAX_WIDTH: number = 1360;
  static readonly STUDY_READABLE_MAX_WIDTH: number = 1040;
  static readonly STUDY_SPLIT_MAX_WIDTH: number = 1400;
  static readonly FILTER_DIALOG_MAX_WIDTH: number = 640;
  static readonly STUDY_TITLE_SIZE: number = 26;
  static readonly PARENT_HOME_READABLE_MAX_WIDTH: number = 1040;
  static readonly PARENT_HOME_PAD_CONTENT_MAX_WIDTH: number = 1360;
  static readonly PARENT_HOME_ACTION_CARD_MIN_HEIGHT: number = 132;
  static readonly PARENT_HOME_ACTION_ICON_SIZE: number = 44;
  static readonly PARENT_HOME_ACTION_CARD_PADDING: number = 16;
  static readonly PARENT_PROGRESS_READABLE_MAX_WIDTH: number = 1040;
  static readonly PARENT_PROGRESS_REVIEW_MAX_WIDTH: number = 1400;
  // Shared readable width for parent deep pages such as create, review and confirmation flows.
  static readonly PARENT_DEEP_READABLE_MAX_WIDTH: number = 1040;
  static readonly IMPORT_READABLE_MAX_WIDTH: number = 1080;
  static readonly CAPTURE_HOME_READABLE_MAX_WIDTH: number = 720;
  static readonly IMPORT_SPLIT_MAX_WIDTH: number = 1280;
  static readonly PROFILE_READABLE_MAX_WIDTH: number = 900;
  static readonly PRACTICE_READABLE_MAX_WIDTH: number = 1120;
  static readonly PRACTICE_ATTEMPT_READABLE_MAX_WIDTH: number = 1120;
  static readonly PRACTICE_ATTEMPT_SCALE_REFERENCE_WIDTH: number = 640;
  static readonly PRACTICE_ATTEMPT_MAX_SCALE: number = 1.35;
  static readonly SETTINGS_READABLE_MAX_WIDTH: number = 1000;

  static readonly DEEP_PAGE_TOP_PADDING: number = 8;
  static readonly DEEP_PAGE_BOTTOM_PADDING: number = 24;
  static readonly DEEP_PAGE_HEADER_HEIGHT: number = 48;
  static readonly DEEP_PAGE_HEADER_GAP: number = 10;
  static readonly DEEP_PAGE_HEADER_META_SIZE: number = 13;
  static readonly DEEP_PAGE_BACK_GLYPH_SIZE: number = 22;
  static readonly DEEP_PAGE_CONTENT_GAP: number = 12;

  static readonly HOME_PRIMARY_MIN_WIDTH: number = 520;
  static readonly HOME_SECONDARY_MIN_WIDTH: number = 320;
  static readonly SPLIT_PRIMARY_MIN_WIDTH: number = 400;
  static readonly SPLIT_SECONDARY_MIN_WIDTH: number = 420;
  static readonly STUDY_PRIMARY_MIN_WIDTH: number = 480;
  static readonly STUDY_TUTOR_MIN_WIDTH: number = 340;
  static readonly PARENT_HOME_PRIMARY_MIN_WIDTH: number = 500;
  static readonly PARENT_HOME_SECONDARY_MIN_WIDTH: number = 340;
  static readonly PARENT_PROGRESS_LIST_MIN_WIDTH: number = 400;
  static readonly PARENT_REVIEW_MIN_WIDTH: number = 440;
  static readonly IMPORT_SOURCE_MIN_WIDTH: number = 400;
  static readonly IMPORT_CANDIDATE_MIN_WIDTH: number = 420;
  static readonly SETTINGS_INLINE_FIELD_MIN_WIDTH: number = 220;
  static readonly SPLIT_PANE_GAP: number = 18;

  static readonly PHONE_PAGE_PADDING: number = 16;
  static readonly PHONE_SECTION_GAP: number = 14;
  static readonly PHONE_CARD_PADDING: number = 14;
  static readonly PHONE_CARD_RADIUS: number = 16;

  // PAD-only non-title visual scale. Title semantics stay shared across Phone and PAD.
  static readonly PAD_BODY_SIZE: number = 16;
  static readonly PAD_META_SIZE: number = 13;
  static readonly PAD_MIN_TOUCH_TARGET: number = 48;

  // Shared title hierarchy. Responsive layout may scale presentation, but semantic levels stay stable.
  // PAGE_TITLE is reserved for the current business object; PAGE_NAV is for page/dialog/sheet headers.
  static readonly PAGE_TITLE_SIZE: number = 26;
  static readonly PAGE_NAV_TITLE_SIZE: number = 20;
  static readonly SECTION_TITLE_SIZE: number = 17;
  static readonly CARD_TITLE_SIZE: number = 16;
  static readonly LABEL_TITLE_SIZE: number = 14;
  static readonly BODY_SIZE: number = 14;
  static readonly CAPTION_SIZE: number = 12;

  static readonly MIN_TOUCH_TARGET: number = 40;
  static readonly BUTTON_HEIGHT: number = 48;
  static readonly SECONDARY_BUTTON_HEIGHT: number = 44;
  static readonly INPUT_HEIGHT: number = 48;
  static readonly CONTEXT_BAR_HEIGHT: number = 56;
  static readonly BOTTOM_NAV_HEIGHT: number = 68;
  static readonly SIDE_NAV_WIDTH: number = 96;
}
