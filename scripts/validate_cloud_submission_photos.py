#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(path: str) -> str:
    file = ROOT / path
    if not file.exists():
        errors.append(f"missing required file: {path}")
        return ""
    return file.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


api = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
strip = read("entry/src/main/ets/components/submission/CloudSubmissionPhotoStrip.ets")
review = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
preview = read("entry/src/main/ets/components/submission/PhotoPreviewDialog.ets")
controller = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionController.java")

require("HttpDataType.ARRAY_BUFFER" in api,
        "cloud submission photos must use binary NetworkKit responses")
require("Authorization" in api and "Bearer ${BackendSession.instance.getToken()}" in api,
        "cloud photo download must carry the authenticated family session")
require("/api/v1/submission-photos/${encodeURIComponent(photo.id)}" in api,
        "client must use the authenticated submission-photo endpoint")
require("context.cacheDir" in api and "fileUri.getUriFromPath" in api,
        "downloaded cloud photos must be written to app cache")
require("photoCache" in api and "cachedPhotoUri" in api,
        "downloaded photos must be reused by photo id")
require("downloadPhoto(photo)" in strip and "aboutToAppear" in strip,
        "photo strip must lazy-load missing photos when shown")
require("sys.symbol.photo" not in strip,
        "photo strip must not use unsupported sys.symbol.photo on the current HarmonyOS SDK")
require("作业照片" in strip and "暂不可用" in strip,
        "photo strip must retain a resource-free unavailable-photo placeholder")
require("PhotoPreviewDialog" in strip and "previewController.open()" in strip and
        "查看作业照片大图" in strip,
        "cloud submission thumbnails must open a large photo preview")
require("@CustomDialog" in preview and "Image(this.uri)" in preview and
        "ImageFit.Contain" in preview and "关闭照片预览" in preview,
        "shared photo preview must render the full image with an explicit close action")
# Slice 4 moved submission evidence out of the old all-in-one Progress page and into the
# dedicated Parent Review surface. Keep the photo gate bound to the surface that now owns
# review evidence instead of forcing Progress to duplicate the same cloud-photo rendering.
require("CloudSubmissionPhotoStrip" in review,
        "parent review surface must render cloud photo thumbnails")
require("PhotoPreviewDialog" in review and ".onClick(() => this.openPreview(uri))" in review,
        "local submission thumbnails must open the same large photo preview")
require("@GetMapping(\"/submission-photos/{photoId}\")" in controller,
        "backend must retain the authenticated photo endpoint")
require("?token=" not in api.lower() and "access_token" not in api.lower(),
        "authentication token must never be placed in the photo URL")

if errors:
    print("CLOUD_SUBMISSION_PHOTOS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("CLOUD_SUBMISSION_PHOTOS_GATE_PASS")
