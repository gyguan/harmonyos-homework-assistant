package com.xiaoban.homework.ai;

/** Image request failures carry only locally generated metadata, never provider payloads. */
public final class ImageAiRequestException extends RuntimeException {
  public enum Reason {
    IMAGE_UNSUPPORTED, IMAGE_INVALID, MODEL_NOT_FOUND, AUTHENTICATION, RATE_LIMIT,
    REQUEST_TOO_LARGE, REQUEST_REJECTED, UPSTREAM_UNAVAILABLE, HTTP_ERROR
  }

  private final int status;
  private final Reason reason;

  public ImageAiRequestException(int status, Reason reason) {
    super("AI图片请求失败：上游HTTP " + status + "，" + description(reason) + "；可点击识别图片文字");
    this.status = status;
    this.reason = reason;
  }

  public int status() { return status; }
  public Reason reason() { return reason; }

  private static String description(Reason reason) {
    return switch (reason) {
      case IMAGE_UNSUPPORTED -> "服务报告不支持图片输入，请配置支持图片的 image-organizer-model";
      case IMAGE_INVALID -> "服务报告图片无效，请重新选择图片";
      case MODEL_NOT_FOUND -> "服务报告模型不存在，请检查 image-organizer-model";
      case AUTHENTICATION -> "请检查后端模型服务密钥及访问权限";
      case RATE_LIMIT -> "模型服务限流或额度不足，请稍后重试或检查额度";
      case REQUEST_TOO_LARGE -> "图片请求超过服务限制，请裁剪图片后重试";
      case REQUEST_REJECTED -> "模型服务或网关拒绝此请求，请核对模型图片能力、data URL支持及接口协议";
      case UPSTREAM_UNAVAILABLE -> "模型服务暂时不可用，请稍后重试";
      case HTTP_ERROR -> "请核对模型服务配置与图片输入协议";
    };
  }
}
