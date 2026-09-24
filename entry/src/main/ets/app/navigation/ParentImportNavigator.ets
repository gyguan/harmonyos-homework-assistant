import {
  AppRoute,
  ParentImportBatchRouteParam,
  ParentImportConfirmationRouteParam,
  ParentImportInboxRouteParam,
  ParentImportRouteParam
} from './AppRoutes';

export class ParentImportNavigator {
  static openImport(stack: NavPathStack): void {
    stack.pushPathByName(AppRoute.PARENT_IMPORT, new ParentImportRouteParam());
  }

  static openInbox(stack: NavPathStack): void {
    stack.pushPathByName(AppRoute.PARENT_IMPORT_INBOX, new ParentImportInboxRouteParam());
  }

  static openBatch(stack: NavPathStack, batchId: string): void {
    stack.pushPathByName(
      AppRoute.PARENT_IMPORT_BATCH_DETAIL, new ParentImportBatchRouteParam(batchId));
  }

  static openConfirmation(stack: NavPathStack): void {
    stack.pushPathByName(
      AppRoute.PARENT_IMPORT_CONFIRMATION, new ParentImportConfirmationRouteParam());
  }

  static batchId(param: Object): string {
    return (param as ParentImportBatchRouteParam).batchId;
  }
}
