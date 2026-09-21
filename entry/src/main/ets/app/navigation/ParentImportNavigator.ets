import {
  AppRoute,
  ParentCaptureHomeRouteParam,
  ParentCaptureRouteParam,
  ParentCaptureDiagnosticRouteParam,
  ParentImportBatchRouteParam,
  ParentImportConfirmationRouteParam,
  ParentImportInboxRouteParam,
  ParentImportRouteParam,
  ParentSourceProfileRouteParam
} from './AppRoutes';

export class ParentImportNavigator {
  static openImport(stack: NavPathStack): void {
    stack.pushPathByName(AppRoute.PARENT_IMPORT, new ParentImportRouteParam());
  }

  static openCaptureHome(stack: NavPathStack): void {
    stack.pushPathByName(AppRoute.PARENT_CAPTURE_HOME, new ParentCaptureHomeRouteParam());
  }

  static openInbox(stack: NavPathStack): void {
    stack.pushPathByName(AppRoute.PARENT_IMPORT_INBOX, new ParentImportInboxRouteParam());
  }

  static openBatch(stack: NavPathStack, batchId: string): void {
    stack.pushPathByName(
      AppRoute.PARENT_IMPORT_BATCH_DETAIL, new ParentImportBatchRouteParam(batchId));
  }

  static openCapture(stack: NavPathStack): void {
    stack.pushPathByName(AppRoute.PARENT_CAPTURE, new ParentCaptureRouteParam());
  }

  static openSourceProfile(stack: NavPathStack, startCaptureAfterSave: boolean): void {
    stack.pushPathByName(
      AppRoute.PARENT_SOURCE_PROFILE, new ParentSourceProfileRouteParam(startCaptureAfterSave));
  }

  static openCaptureDiagnostics(stack: NavPathStack): void {
    stack.pushPathByName(
      AppRoute.PARENT_CAPTURE_DIAGNOSTIC, new ParentCaptureDiagnosticRouteParam());
  }

  static openConfirmation(stack: NavPathStack): void {
    stack.pushPathByName(
      AppRoute.PARENT_IMPORT_CONFIRMATION, new ParentImportConfirmationRouteParam());
  }

  static batchId(param: Object): string {
    return (param as ParentImportBatchRouteParam).batchId;
  }

  static sourceProfileStartCapture(param: Object): boolean {
    return (param as ParentSourceProfileRouteParam).startCaptureAfterSave;
  }

  static finishSourceProfile(stack: NavPathStack, startCaptureAfterSave: boolean): void {
    if (stack.size() > 0) stack.pop();
    if (startCaptureAfterSave) ParentImportNavigator.openCapture(stack);
  }
}
