export enum HomeworkImportInboxSourceFilter {
  ALL = 'ALL',
  CLIPBOARD = 'CLIPBOARD',
  SCREENSHOT = 'SCREENSHOT',
  SHARE = 'SHARE',
  SCREEN_CAPTURE = 'SCREEN_CAPTURE'
}

export enum HomeworkImportInboxStatusFilter {
  ALL = 'ALL',
  RECEIVED = 'RECEIVED',
  READY = 'READY',
  PUBLISHED = 'PUBLISHED',
  EMPTY = 'EMPTY',
  ABANDONED = 'ABANDONED'
}

export enum HomeworkImportInboxTimeFilter {
  ALL = 'ALL',
  TODAY = 'TODAY',
  LAST_7_DAYS = 'LAST_7_DAYS',
  LAST_30_DAYS = 'LAST_30_DAYS'
}

export class HomeworkImportInboxFilterLabels {
  static source(filter: HomeworkImportInboxSourceFilter): string {
    if (filter === HomeworkImportInboxSourceFilter.CLIPBOARD) return '文字';
    if (filter === HomeworkImportInboxSourceFilter.SCREENSHOT) return '截图';
    if (filter === HomeworkImportInboxSourceFilter.SHARE) return '系统分享';
    if (filter === HomeworkImportInboxSourceFilter.SCREEN_CAPTURE) return '智能采集';
    return '全部';
  }

  static status(filter: HomeworkImportInboxStatusFilter): string {
    if (filter === HomeworkImportInboxStatusFilter.RECEIVED) return '已接收';
    if (filter === HomeworkImportInboxStatusFilter.READY) return '待确认';
    if (filter === HomeworkImportInboxStatusFilter.PUBLISHED) return '已发布';
    if (filter === HomeworkImportInboxStatusFilter.EMPTY) return '未识别';
    if (filter === HomeworkImportInboxStatusFilter.ABANDONED) return '已放弃';
    return '全部';
  }

  static time(filter: HomeworkImportInboxTimeFilter): string {
    if (filter === HomeworkImportInboxTimeFilter.TODAY) return '今天';
    if (filter === HomeworkImportInboxTimeFilter.LAST_7_DAYS) return '近7天';
    if (filter === HomeworkImportInboxTimeFilter.LAST_30_DAYS) return '近30天';
    return '全部';
  }
}
