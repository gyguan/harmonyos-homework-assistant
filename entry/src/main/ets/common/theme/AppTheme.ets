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
  static readonly DIVIDER: string = '#ECECF0';
  static readonly BORDER: string = '#E4E5E9';

  // Typography.
  static readonly TEXT: string = '#1D1D1F';
  static readonly SUBTEXT: string = '#6E6E73';
  static readonly TERTIARY_TEXT: string = '#92949A';
  static readonly TEXT_ON_PRIMARY: string = '#FFFFFF';

  // Semantic colors.
  static readonly SUCCESS: string = '#159B66';
  static readonly SUCCESS_SOFT: string = '#EAF8F1';
  static readonly WARNING: string = '#C96A08';
  static readonly WARNING_SOFT: string = '#FFF5E6';
  static readonly DANGER: string = '#D9485F';
  static readonly DANGER_SOFT: string = '#FDECEF';
  static readonly DISABLED: string = '#B8BCC6';

  // Layout tokens. The base page edge follows HarmonyOS 20vp-level spacing guidance.
  static readonly PAGE_PADDING: number = 20;
  static readonly PAGE_PADDING_WIDE: number = 28;
  static readonly SECTION_GAP: number = 20;
  static readonly ITEM_GAP: number = 12;
  static readonly CARD_PADDING: number = 18;
  static readonly CARD_RADIUS: number = 20;
  static readonly CONTROL_RADIUS: number = 14;
  static readonly CHIP_RADIUS: number = 12;

  // Type scale.
  static readonly PAGE_TITLE_SIZE: number = 26;
  static readonly SECTION_TITLE_SIZE: number = 20;
  static readonly CARD_TITLE_SIZE: number = 17;
  static readonly BODY_SIZE: number = 14;
  static readonly CAPTION_SIZE: number = 12;

  // Control sizing.
  static readonly BUTTON_HEIGHT: number = 48;
  static readonly SECONDARY_BUTTON_HEIGHT: number = 44;
  static readonly INPUT_HEIGHT: number = 48;
  static readonly CONTEXT_BAR_HEIGHT: number = 56;
  static readonly BOTTOM_NAV_HEIGHT: number = 68;
  static readonly SIDE_NAV_WIDTH: number = 96;
}
