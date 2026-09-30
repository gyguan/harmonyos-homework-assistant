# Issue #401：图片文字识别与任务编辑调整

选择图片后，图片预览下的“识别图片文字”走本机 CoreVision OCR；“整理并继续”仍沿用图片和补充文字的 AI 解析。此次没有设备错误码或真机复现，不能断言用户报错的唯一根因。

代码排查确认 OCR 解码没有显式指定像素格式，图片资源未释放，且读取、解码、识别和空文本错误被外层 catch 覆盖。适配器现在显式解码为 RGBA_8888、SDR，保留原始尺寸，成功和失败均释放 PixelMap、ImageSource、文件。初始化、读取、解码和识别分别给出提示及数值错误码。日志只包含阶段、数值错误码或固定清理提示，不记录路径、文件名、图片或识别正文。OCR 服务异常时下次操作重新初始化。

接口依据：

- [CoreVision 文字识别 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/core-vision-text-recognition-api)：VisionInfo 只支持 RGBA_8888；init 返回 Promise<boolean>；识别错误码包括 200、401、1001400001、1001400002。
- [Image Kit 图片解码](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/image-decoding-V14)：通过 DecodingOptions 设置输出像素格式和动态范围。

拍照和选图片沿用统一次级按钮的 SURFACE_EMPHASIS、TEXT、Medium、CONTROL_RADIUS 和最小点击高度；主操作仍为底部“整理并继续”。共享任务编辑表单移除教材/页码输入和清空动作，待确认和已发布任务保存时继续保留已有 textbookRef。

自动验证：`node scripts/test_core_vision_ocr.mjs` 使用 SDK doubles 执行实际适配器的输入与错误处理控制流，覆盖正常识别、纯文本、初始化、读取、解码、识别、空文本、资源释放、设备能力及重试。不替代 HarmonyOS SDK 编译或真实识别效果验证。

真机验收：

1. 选择普通截图及 HDR 相册照片，点击“识别图片文字”，确认文字进入可编辑输入框，原补充文字保留。
2. 连续选择和识别多张图片，检查没有资源持续增长；失败提示区分阶段，并在原图上可以继续 AI 解析。
3. 拍照、选图片按钮在 Phone 和 Pad 保持等宽、统一样式和忙碌态禁用。
4. 在待确认和已发布任务的编辑弹层中确认没有教材/页码；修改标题保存，核对已有 textbookRef 未丢失。
