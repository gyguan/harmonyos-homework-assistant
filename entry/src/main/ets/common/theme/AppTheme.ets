export class AppTheme {
  // HarmonyOS-inspired blue/white visual language.
  static readonly PRIMARY: string = '#0A59F7';
  static readonly PRIMARY_PRESSED: string = '#0847C7';
  static readonly PRIMARY_SOFT: string = '#EAF2FF';
  static readonly PRIMARY_FAINT: string = '#F4F7FF';

  // Layered surfaces.
  static readonly BACKGROUND: string = '#F5F5F7';
  static readonly SURFACE: string = '#FFFFFF';
  static readonly SURFACE_SUBTLE: string = '#F7F7F8';
  static readonly SURFACE_EMPHASIS: string = '#F0F1F4';
  static readonly DIVIDER: string = '#D9DADE';
  static readonly BORDER: string = '#D3D5DA';

  // Typography. Values keep normal-size text at >= 4.5:1 contrast on the surfaces used by the app.
  static readonly TEXT: string = '#1D1D1F';
  static readonly SUBTEXT: string = '#5F6268';
  static readonly TERTIARY_TEXT: string = '#6F7278';
  static readonly TEXT_ON_PRIMARY: string = '#FFFFFF';

  // Semantic colors. Darker foreground tones preserve readable contrast on their soft semantic surfaces.
  static readonly SUCCESS: string = '#0A7047';
  static readonly SUCCESS_SOFT: string = '#EAF8F1';
  static readonly WARNING: string = '#8C4800';
  static readonly WARNING_SOFT: string = '#FFF5E6';
  static readonly DANGER: string = '#A8233D';
  static readonly DANGER_SOFT: string = '#FDECEF';
  static readonly DISABLED: string = '#7D818A';

  // Shared layout tokens.
  static readonly PAGE_PADDING: number = 20;
  static readonly PAGE_PADDING_WIDE: number = 28;
  static readonly SECTION_GAP: number = 20;
  static readonly ITEM_GAP: number = 12;
  static readonly CARD_PADDING: number = 18;
  static readonly CARD_RADIUS: number = 20;
  static readonly CONTROL_RADIUS: number = 14;
  static readonly CHIP_RADIUS: number = 12;

  // Deep-page chrome. Assignment detail, study, Tutor, submission and future secondary pages
  // share one compact top chrome instead of implementing page-private back/title layouts.
  static readonly DEEP_PAGE_TOP_PADDING: number = 8;
  static readonly DEEP_PAGE_BOTTOM_PADDING: number = 24;
  static readonly DEEP_PAGE_HEADER_HEIGHT: number = 44;
  static readonly DEEP_PAGE_HEADER_GAP: number = 10;
  static readonly DEEP_PAGE_HEADER_TITLE_SIZE: number = 17;
  static readonly DEEP_PAGE_HEADER_META_SIZE: number = 12;
  static readonly DEEP_PAGE_BACK_GLYPH_SIZE: number = 27;
  static readonly DEEP_PAGE_CONTENT_GAP: number = 12;

  // Two-pane is a content capability, not a device breakpoint. These are minimum
  // readable pane constraints; the actual switch width is calculated from them.
  static readonly SPLIT_PRIMARY_MIN_WIDTH: number = 320;
  static readonly SPLIT_SECONDARY_MIN_WIDTH: number = 380;
  static readonly SPLIT_PANE_GAP: number = 18;

  // Compact Phone follows the Focus Journey composition instead of shrinking the Pad workspace.
  static readonly PHONE_PAGE_PADDING: number = 16;
  static readonly PHONE_SECTION_GAP: number = 14;
  static readonly PHONE_CARD_PADDING: number = 14;
  static readonly PHONE_CARD_RADIUS: number = 16;
  static readonly PHONE_PAGE_TITLE_SIZE: number = 23;
  static readonly PHONE_SECTION_TITLE_SIZE: number = 17;

  // Type scale for Medium / Expanded layouts.
  static readonly PAGE_TITLE_SIZE: number = 26;
  static readonly SECTION_TITLE_SIZE: number = 20;
  static readonly CARD_TITLE_SIZE: number = 17;
  static readonly BODY_SIZE: number = 14;
  static readonly CAPTION_SIZE: number = 12;

  // Control sizing. 44vp+ keeps touch targets above the HarmonyOS 40vp minimum.
  static readonly MIN_TOUCH_TARGET: number = 40;
  static readonly BUTTON_HEIGHT: number = 48;
  static readonly SECONDARY_BUTTON_HEIGHT: number = 44;
  static readonly INPUT_HEIGHT: number = 48;
  static readonly CONTEXT_BAR_HEIGHT: number = 56;
  static readonly BOTTOM_NAV_HEIGHT: number = 68;
  static readonly SIDE_NAV_WIDTH: number = 96;
}
