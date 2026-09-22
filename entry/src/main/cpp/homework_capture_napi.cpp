#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <mutex>
#include <utility>
#include <vector>

#include <hilog/log.h>
#include <napi/native_api.h>
#include <native_buffer/native_buffer.h>
#include <multimedia/player_framework/native_avbuffer.h>
#include <multimedia/player_framework/native_avscreen_capture.h>
#include <multimedia/player_framework/native_avscreen_capture_base.h>
#include <multimedia/player_framework/native_avscreen_capture_errors.h>
#include <window_manager/oh_display_info.h>
#include <window_manager/oh_display_manager.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x3200
#define LOG_TAG "HomeworkCaptureSpike"

namespace {
constexpr uint64_t SAMPLE_EVERY_CALLBACKS = 30;
constexpr size_t MAX_PENDING_FRAMES = 6;
constexpr size_t FRAME_SIGNATURE_SAMPLES = 96;
constexpr double FRAME_DIFF_THRESHOLD = 10.0;

std::mutex g_captureMutex;
std::mutex g_frameMutex;
OH_AVScreenCapture *g_capture = nullptr;
std::atomic<bool> g_isCapturing(false);
std::atomic<int32_t> g_lastError(0);
std::atomic<int32_t> g_state(-1);
std::atomic<uint64_t> g_callbackCount(0);
std::atomic<uint64_t> g_sampledFrameCount(0);
std::atomic<uint64_t> g_sequence(0);

struct BufferedFrame {
    std::vector<uint8_t> rgba;
    int32_t width = 0;
    int32_t height = 0;
    int64_t timestamp = 0;
    uint64_t sequence = 0;
};

std::deque<BufferedFrame> g_pendingFrames;
std::vector<uint8_t> g_lastQueuedSignature;

std::vector<uint8_t> FrameSignature(const std::vector<uint8_t> &rgba)
{
    std::vector<uint8_t> signature;
    if (rgba.empty()) {
        return signature;
    }
    signature.reserve(FRAME_SIGNATURE_SAMPLES);
    size_t stride = rgba.size() / FRAME_SIGNATURE_SAMPLES;
    if (stride < 1) {
        stride = 1;
    }
    for (size_t i = 0; i < rgba.size() && signature.size() < FRAME_SIGNATURE_SAMPLES; i += stride) {
        signature.push_back(rgba[i]);
    }
    return signature;
}

bool IsMeaningfulFrame(const std::vector<uint8_t> &signature)
{
    if (signature.empty()) {
        return false;
    }
    if (g_lastQueuedSignature.size() != signature.size()) {
        return true;
    }
    double total = 0.0;
    for (size_t i = 0; i < signature.size(); ++i) {
        total += static_cast<double>(
            std::abs(static_cast<int>(signature[i]) - static_cast<int>(g_lastQueuedSignature[i])));
    }
    return total / static_cast<double>(signature.size()) >= FRAME_DIFF_THRESHOLD;
}

void OnError(OH_AVScreenCapture *capture, int32_t errorCode, void *userData)
{
    (void)capture;
    (void)userData;
    g_lastError.store(errorCode);
    OH_LOG_ERROR(LOG_APP, "capture error: %{public}d", errorCode);
}

void OnStateChange(OH_AVScreenCapture *capture, OH_AVScreenCaptureStateCode stateCode, void *userData)
{
    (void)capture;
    (void)userData;
    g_state.store(static_cast<int32_t>(stateCode));
    if (stateCode == OH_SCREEN_CAPTURE_STATE_STARTED) {
        g_isCapturing.store(true);
    } else if (stateCode == OH_SCREEN_CAPTURE_STATE_CANCELED ||
               stateCode == OH_SCREEN_CAPTURE_STATE_STOPPED_BY_USER ||
               stateCode == OH_SCREEN_CAPTURE_STATE_INTERRUPTED_BY_OTHER ||
               stateCode == OH_SCREEN_CAPTURE_STATE_STOPPED_BY_CALL ||
               stateCode == OH_SCREEN_CAPTURE_STATE_STOPPED_BY_USER_SWITCHES) {
        g_isCapturing.store(false);
    }
    OH_LOG_INFO(LOG_APP, "capture state: %{public}d", static_cast<int32_t>(stateCode));
}

void CopyLatestFrame(OH_AVBuffer *buffer, int64_t timestamp)
{
    OH_NativeBuffer *nativeBuffer = OH_AVBuffer_GetNativeBuffer(buffer);
    if (nativeBuffer == nullptr) {
        return;
    }

    OH_NativeBuffer_Config config {};
    OH_NativeBuffer_GetConfig(nativeBuffer, &config);
    uint8_t *source = OH_AVBuffer_GetAddr(buffer);
    int32_t capacity = OH_AVBuffer_GetCapacity(buffer);

    if (source == nullptr || capacity <= 0 ||
        config.width <= 0 || config.height <= 0 || config.stride <= 0) {
        OH_NativeBuffer_Unreference(nativeBuffer);
        return;
    }

    constexpr size_t bytesPerPixel = 4;
    const size_t compactRowBytes = static_cast<size_t>(config.width) * bytesPerPixel;
    const size_t sourceStride = static_cast<size_t>(config.stride);
    const size_t requiredSourceBytes = sourceStride * static_cast<size_t>(config.height);
    const size_t sourceCapacity = static_cast<size_t>(capacity);

    if (sourceStride < compactRowBytes || sourceCapacity < requiredSourceBytes) {
        OH_NativeBuffer_Unreference(nativeBuffer);
        return;
    }

    std::vector<uint8_t> compact(
        compactRowBytes * static_cast<size_t>(config.height));
    for (int32_t row = 0; row < config.height; ++row) {
        std::memcpy(
            compact.data() + static_cast<size_t>(row) * compactRowBytes,
            source + static_cast<size_t>(row) * sourceStride,
            compactRowBytes);
    }

    g_sampledFrameCount.fetch_add(1);
    std::vector<uint8_t> signature = FrameSignature(compact);

    {
        std::lock_guard<std::mutex> frameLock(g_frameMutex);
        if (IsMeaningfulFrame(signature)) {
            BufferedFrame frame;
            frame.rgba = std::move(compact);
            frame.width = config.width;
            frame.height = config.height;
            frame.timestamp = timestamp;
            frame.sequence = g_sequence.fetch_add(1) + 1;
            g_pendingFrames.push_back(std::move(frame));
            g_lastQueuedSignature = std::move(signature);
            while (g_pendingFrames.size() > MAX_PENDING_FRAMES) {
                g_pendingFrames.pop_front();
            }
        }
    }

    OH_NativeBuffer_Unreference(nativeBuffer);
}

void OnBufferAvailable(OH_AVScreenCapture *capture, OH_AVBuffer *buffer,
    OH_AVScreenCaptureBufferType bufferType, int64_t timestamp, void *userData)
{
    (void)capture;
    (void)userData;
    if (!g_isCapturing.load() || buffer == nullptr ||
        bufferType != OH_SCREEN_CAPTURE_BUFFERTYPE_VIDEO) {
        return;
    }

    uint64_t count = g_callbackCount.fetch_add(1) + 1;
    if (count == 1 || count % SAMPLE_EVERY_CALLBACKS == 0) {
        CopyLatestFrame(buffer, timestamp);
    }
}

void StopAndReleaseLocked()
{
    if (g_capture == nullptr) {
        g_isCapturing.store(false);
        return;
    }

    g_isCapturing.store(false);
    (void)OH_AVScreenCapture_StopScreenCapture(g_capture);
    (void)OH_AVScreenCapture_Release(g_capture);
    g_capture = nullptr;
}

napi_value JsNumber(napi_env env, int32_t value)
{
    napi_value result = nullptr;
    napi_create_int32(env, value, &result);
    return result;
}

napi_value JsInt64(napi_env env, int64_t value)
{
    napi_value result = nullptr;
    napi_create_int64(env, value, &result);
    return result;
}

napi_value JsBool(napi_env env, bool value)
{
    napi_value result = nullptr;
    napi_get_boolean(env, value, &result);
    return result;
}

napi_value StartCapture(napi_env env, napi_callback_info info)
{
    (void)info;
    std::lock_guard<std::mutex> lock(g_captureMutex);
    StopAndReleaseLocked();

    g_lastError.store(0);
    g_state.store(-1);
    g_callbackCount.store(0);
    g_sampledFrameCount.store(0);

    g_capture = OH_AVScreenCapture_Create();
    if (g_capture == nullptr) {
        g_lastError.store(-1001);
        return JsNumber(env, -1001);
    }

    uint64_t displayId = 0;
    NativeDisplayManager_ErrorCode displayIdResult =
        OH_NativeDisplayManager_GetDefaultDisplayId(&displayId);
    if (displayIdResult != DISPLAY_MANAGER_OK) {
        StopAndReleaseLocked();
        g_lastError.store(-1002);
        return JsNumber(env, -1002);
    }

    NativeDisplayManager_DisplayInfo *displayInfo = nullptr;
    NativeDisplayManager_ErrorCode displayResult =
        OH_NativeDisplayManager_CreateDisplayById(displayId, &displayInfo);
    if (displayResult != DISPLAY_MANAGER_OK || displayInfo == nullptr) {
        StopAndReleaseLocked();
        g_lastError.store(-1003);
        return JsNumber(env, -1003);
    }

    int32_t screenWidth = displayInfo->width;
    int32_t screenHeight = displayInfo->height;
    OH_NativeDisplayManager_DestroyDisplay(displayInfo);

    OH_AVScreenCaptureConfig config {};
    config.captureMode = OH_CAPTURE_HOME_SCREEN;
    config.dataType = OH_ORIGINAL_STREAM;
    config.videoInfo.videoCapInfo.videoFrameWidth = screenWidth;
    config.videoInfo.videoCapInfo.videoFrameHeight = screenHeight;
    config.videoInfo.videoCapInfo.videoSource = OH_VIDEO_SOURCE_SURFACE_RGBA;
    config.videoInfo.videoEncInfo.videoCodec = OH_H264;
    config.videoInfo.videoEncInfo.videoBitrate = 2000000;
    config.videoInfo.videoEncInfo.videoFrameRate = 30;

    OH_AVSCREEN_CAPTURE_ErrCode initResult = OH_AVScreenCapture_Init(g_capture, config);
    if (initResult != AV_SCREEN_CAPTURE_ERR_OK) {
        int32_t code = static_cast<int32_t>(initResult);
        g_lastError.store(code);
        StopAndReleaseLocked();
        return JsNumber(env, code);
    }

    OH_AVSCREEN_CAPTURE_ErrCode microphoneResult =
        OH_AVScreenCapture_SetMicrophoneEnabled(g_capture, false);
    if (microphoneResult != AV_SCREEN_CAPTURE_ERR_OK) {
        int32_t code = static_cast<int32_t>(microphoneResult);
        g_lastError.store(code);
        StopAndReleaseLocked();
        return JsNumber(env, code);
    }

    OH_AVSCREEN_CAPTURE_ErrCode errorCallbackResult =
        OH_AVScreenCapture_SetErrorCallback(g_capture, OnError, nullptr);
    if (errorCallbackResult != AV_SCREEN_CAPTURE_ERR_OK) {
        int32_t code = static_cast<int32_t>(errorCallbackResult);
        g_lastError.store(code);
        StopAndReleaseLocked();
        return JsNumber(env, code);
    }

    OH_AVSCREEN_CAPTURE_ErrCode stateCallbackResult =
        OH_AVScreenCapture_SetStateCallback(g_capture, OnStateChange, nullptr);
    if (stateCallbackResult != AV_SCREEN_CAPTURE_ERR_OK) {
        int32_t code = static_cast<int32_t>(stateCallbackResult);
        g_lastError.store(code);
        StopAndReleaseLocked();
        return JsNumber(env, code);
    }

    OH_AVSCREEN_CAPTURE_ErrCode dataCallbackResult =
        OH_AVScreenCapture_SetDataCallback(g_capture, OnBufferAvailable, nullptr);
    if (dataCallbackResult != AV_SCREEN_CAPTURE_ERR_OK) {
        int32_t code = static_cast<int32_t>(dataCallbackResult);
        g_lastError.store(code);
        StopAndReleaseLocked();
        return JsNumber(env, code);
    }

    OH_AVSCREEN_CAPTURE_ErrCode startResult = OH_AVScreenCapture_StartScreenCapture(g_capture);
    if (startResult != AV_SCREEN_CAPTURE_ERR_OK) {
        int32_t code = static_cast<int32_t>(startResult);
        g_lastError.store(code);
        StopAndReleaseLocked();
        return JsNumber(env, code);
    }

    return JsNumber(env, static_cast<int32_t>(startResult));
}

napi_value StopCapture(napi_env env, napi_callback_info info)
{
    (void)info;
    std::lock_guard<std::mutex> lock(g_captureMutex);
    int32_t resultCode = static_cast<int32_t>(AV_SCREEN_CAPTURE_ERR_OK);
    if (g_capture != nullptr) {
        g_isCapturing.store(false);
        resultCode = static_cast<int32_t>(OH_AVScreenCapture_StopScreenCapture(g_capture));
        (void)OH_AVScreenCapture_Release(g_capture);
        g_capture = nullptr;
    }
    return JsNumber(env, resultCode);
}

napi_value ClearLatestFrame(napi_env env, napi_callback_info info)
{
    (void)info;
    std::lock_guard<std::mutex> frameLock(g_frameMutex);
    g_pendingFrames.clear();
    g_lastQueuedSignature.clear();
    g_sequence.store(0);

    napi_value undefinedValue = nullptr;
    napi_get_undefined(env, &undefinedValue);
    return undefinedValue;
}

napi_value ToJsFrame(napi_env env, const BufferedFrame &frame)
{
    void *arrayBufferData = nullptr;
    napi_value arrayBuffer = nullptr;
    napi_create_arraybuffer(env, frame.rgba.size(), &arrayBufferData, &arrayBuffer);
    if (arrayBufferData == nullptr) {
        napi_value undefinedValue = nullptr;
        napi_get_undefined(env, &undefinedValue);
        return undefinedValue;
    }
    std::memcpy(arrayBufferData, frame.rgba.data(), frame.rgba.size());

    napi_value result = nullptr;
    napi_create_object(env, &result);
    napi_set_named_property(env, result, "data", arrayBuffer);
    napi_set_named_property(env, result, "width", JsNumber(env, frame.width));
    napi_set_named_property(env, result, "height", JsNumber(env, frame.height));
    napi_set_named_property(env, result, "timestamp", JsInt64(env, frame.timestamp));
    napi_set_named_property(env, result, "sequence",
        JsInt64(env, static_cast<int64_t>(frame.sequence)));
    return result;
}

napi_value GetLatestFrame(napi_env env, napi_callback_info info)
{
    (void)info;
    std::lock_guard<std::mutex> frameLock(g_frameMutex);
    if (g_pendingFrames.empty()) {
        napi_value undefinedValue = nullptr;
        napi_get_undefined(env, &undefinedValue);
        return undefinedValue;
    }
    return ToJsFrame(env, g_pendingFrames.back());
}

napi_value GetPendingFrame(napi_env env, napi_callback_info info)
{
    (void)info;
    BufferedFrame frame;
    {
        std::lock_guard<std::mutex> frameLock(g_frameMutex);
        if (g_pendingFrames.empty()) {
            napi_value undefinedValue = nullptr;
            napi_get_undefined(env, &undefinedValue);
            return undefinedValue;
        }
        frame = std::move(g_pendingFrames.front());
        g_pendingFrames.pop_front();
    }
    return ToJsFrame(env, frame);
}

napi_value GetStats(napi_env env, napi_callback_info info)
{
    (void)info;
    napi_value result = nullptr;
    napi_create_object(env, &result);
    napi_set_named_property(env, result, "isCapturing", JsBool(env, g_isCapturing.load()));
    napi_set_named_property(env, result, "lastError", JsNumber(env, g_lastError.load()));
    napi_set_named_property(env, result, "state", JsNumber(env, g_state.load()));
    napi_set_named_property(env, result, "callbackCount",
        JsInt64(env, static_cast<int64_t>(g_callbackCount.load())));
    napi_set_named_property(env, result, "sampledFrameCount",
        JsInt64(env, static_cast<int64_t>(g_sampledFrameCount.load())));
    napi_set_named_property(env, result, "latestSequence",
        JsInt64(env, static_cast<int64_t>(g_sequence.load())));

    {
        std::lock_guard<std::mutex> frameLock(g_frameMutex);
        int32_t latestWidth = g_pendingFrames.empty() ? 0 : g_pendingFrames.back().width;
        int32_t latestHeight = g_pendingFrames.empty() ? 0 : g_pendingFrames.back().height;
        napi_set_named_property(env, result, "latestWidth", JsNumber(env, latestWidth));
        napi_set_named_property(env, result, "latestHeight", JsNumber(env, latestHeight));
        napi_set_named_property(env, result, "pendingFrameCount",
            JsInt64(env, static_cast<int64_t>(g_pendingFrames.size())));
    }
    return result;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor descriptors[] = {
        {"startCapture", nullptr, StartCapture, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stopCapture", nullptr, StopCapture, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getLatestFrame", nullptr, GetLatestFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getPendingFrame", nullptr, GetPendingFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getStats", nullptr, GetStats, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"clearLatestFrame", nullptr, ClearLatestFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports,
        sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
    return exports;
}
} // namespace

static napi_module homeworkCaptureModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "homeworkcapture",
    .nm_priv = nullptr,
    .reserved = {0}
};

extern "C" __attribute__((constructor)) void RegisterHomeworkCaptureModule()
{
    napi_module_register(&homeworkCaptureModule);
}
