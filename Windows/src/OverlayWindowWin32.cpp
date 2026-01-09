#include "OverlayWindowWin32.h"
#include "BackgroundSettingsWin32.h"
#include "DpiUtilsWin32.h"

#include <iostream>
#include <gdiplus.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfplay.h>
#include <mfreadwrite.h>
#include <propvarutil.h>
#include <windowsx.h>

#pragma comment(lib, "gdiplus.lib")

namespace {

    const wchar_t* kOverlayWindowClassName = L"PomodoroOverlayWindowClass";
    const wchar_t* kOverlayUiWindowClassName = L"PomodoroOverlayUiWindowClass";
    const wchar_t* kOverlayPosterShieldWindowClassName = L"PomodoroOverlayPosterShieldWindowClass";

    constexpr UINT_PTR kTimerStartFadeText = 1;
    constexpr UINT_PTR kTimerHidePoster = 2;
    constexpr UINT_PTR kTimerEnsureTopmost = 3;
    constexpr UINT_PTR kTimerRevealUiAfterPoster = 4;
    constexpr int kIdCancelButton = 3001;

    // Posted from MFPlay callback thread to UI thread: show poster shield to cover loop gap.
    constexpr UINT kMsgShowPosterForLoop = WM_APP + 10;

    // 全局 GDI+ 初始化
    ULONG_PTR g_gdiplusToken = 0;

    void EnsureGdiplusStarted() {
        if (g_gdiplusToken != 0) {
            return;
        }
        Gdiplus::GdiplusStartupInput input;
        if (Gdiplus::GdiplusStartup(&g_gdiplusToken, &input, nullptr) != Gdiplus::Ok) {
            g_gdiplusToken = 0;
        }
    }

    enum class PreparedKind {
        None,
        Image,
        Video
    };

    // Prepared once per rest cycle; reused across monitors.
    PreparedKind g_preparedKind = PreparedKind::None;
    std::unique_ptr<Gdiplus::Image> g_backgroundImage;
    std::unique_ptr<Gdiplus::Bitmap> g_videoPoster;
    std::wstring g_preparedVideoPath;
    double g_preparedVideoPlaybackRate = 1.0;
    // Round-robin cursor for mixed image/video rotation. In-memory only (resets on app restart).
    std::size_t g_backgroundRotateCursor = 0;
    std::wstring g_overlayMessage;

    std::unique_ptr<Gdiplus::Image> TryLoadBackgroundImage(const std::wstring& path) {
        if (path.empty()) return nullptr;
        auto img = std::make_unique<Gdiplus::Image>(path.c_str());
        if (!img || img->GetLastStatus() != Gdiplus::Ok) {
            return nullptr;
        }
        return img;
    }

    std::unique_ptr<Gdiplus::Bitmap> TryDecodeVideoPosterFrame(const std::wstring& path) {
        if (path.empty()) return nullptr;
        EnsureGdiplusStarted();
        if (g_gdiplusToken == 0) return nullptr;

        if (FAILED(MFStartup(MF_VERSION))) {
            return nullptr;
        }

        IMFAttributes* attrs = nullptr;
        HRESULT hr = MFCreateAttributes(&attrs, 2);
        if (SUCCEEDED(hr) && attrs) {
            attrs->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
            attrs->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);
        }

        IMFSourceReader* reader = nullptr;
        hr = MFCreateSourceReaderFromURL(path.c_str(), attrs, &reader);
        if (attrs) {
            attrs->Release();
            attrs = nullptr;
        }
        if (FAILED(hr) || !reader) {
            MFShutdown();
            return nullptr;
        }

        reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
        reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), TRUE);

        IMFMediaType* type = nullptr;
        hr = MFCreateMediaType(&type);
        if (SUCCEEDED(hr) && type) {
            type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
            type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
            reader->SetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), nullptr, type);
            type->Release();
        }

        // Seek to ~0.5s to avoid black intro frames.
        {
            PROPVARIANT pv{};
            PropVariantInit(&pv);
            pv.vt = VT_I8;
            pv.hVal.QuadPart = 5'000'000; // 0.5s in 100ns
            reader->SetCurrentPosition(GUID_NULL, pv);
            PropVariantClear(&pv);
        }

        IMFSample* sample = nullptr;
        DWORD streamIndex = 0;
        DWORD flags = 0;
        LONGLONG ts = 0;
        for (int i = 0; i < 40 && !sample; ++i) {
            hr = reader->ReadSample(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), 0, &streamIndex, &flags, &ts, &sample);
            if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) {
                break;
            }
        }

        if (!sample) {
            reader->Release();
            MFShutdown();
            return nullptr;
        }

        IMFMediaBuffer* buffer = nullptr;
        hr = sample->ConvertToContiguousBuffer(&buffer);
        if (FAILED(hr) || !buffer) {
            sample->Release();
            reader->Release();
            MFShutdown();
            return nullptr;
        }

        IMFMediaType* curType = nullptr;
        UINT32 w = 0, h = 0;
        if (SUCCEEDED(reader->GetCurrentMediaType(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), &curType)) && curType) {
            MFGetAttributeSize(curType, MF_MT_FRAME_SIZE, &w, &h);
            curType->Release();
        }

        BYTE* data = nullptr;
        DWORD maxLen = 0;
        DWORD curLen = 0;
        hr = buffer->Lock(&data, &maxLen, &curLen);
        if (FAILED(hr) || !data || w == 0 || h == 0 || curLen < w * h * 4) {
            if (SUCCEEDED(hr) && data) buffer->Unlock();
            buffer->Release();
            sample->Release();
            reader->Release();
            MFShutdown();
            return nullptr;
        }

        auto bmp = std::make_unique<Gdiplus::Bitmap>(w, h, PixelFormat32bppARGB);
        if (bmp && bmp->GetLastStatus() == Gdiplus::Ok) {
            Gdiplus::Rect r(0, 0, static_cast<INT>(w), static_cast<INT>(h));
            Gdiplus::BitmapData bd{};
            if (bmp->LockBits(&r, Gdiplus::ImageLockModeWrite, PixelFormat32bppARGB, &bd) == Gdiplus::Ok) {
                const int srcStride = static_cast<int>(w) * 4;
                const int dstStride = bd.Stride;
                for (UINT32 y = 0; y < h; ++y) {
                    BYTE* dstRow = static_cast<BYTE*>(bd.Scan0) + y * dstStride;
                    const BYTE* srcRow = data + y * srcStride;
                    memcpy(dstRow, srcRow, srcStride);
                    // Ensure opaque alpha (RGB32 from MF is typically BGRX with undefined alpha).
                    for (UINT32 x = 0; x < w; ++x) {
                        dstRow[x * 4 + 3] = 0xFF;
                    }
                }
                bmp->UnlockBits(&bd);
            }
        }

        buffer->Unlock();
        buffer->Release();
        sample->Release();
        reader->Release();
        MFShutdown();
        return bmp;
    }

    // 注册窗口类（进程内只需一次）
    ATOM RegisterOverlayWindowClass(HINSTANCE hInstance) {
        static ATOM s_atom = 0;
        if (s_atom != 0) {
            return s_atom;
        }

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = pomodoro::OverlayWindowWin32::WndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = sizeof(LONG_PTR);
        wc.hInstance = hInstance;
        wc.hIcon = nullptr;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = nullptr; // 手动绘制背景
        wc.lpszMenuName = nullptr;
        wc.lpszClassName = kOverlayWindowClassName;
        wc.hIconSm = nullptr;

        s_atom = RegisterClassExW(&wc);
        return s_atom;
    }

    ATOM RegisterOverlayUiWindowClass(HINSTANCE hInstance) {
        static ATOM s_atom = 0;
        if (s_atom != 0) {
            return s_atom;
        }

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = pomodoro::OverlayUiWndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = sizeof(LONG_PTR);
        wc.hInstance = hInstance;
        wc.hIcon = nullptr;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = nullptr; // layered window draws everything
        wc.lpszMenuName = nullptr;
        wc.lpszClassName = kOverlayUiWindowClassName;
        wc.hIconSm = nullptr;

        s_atom = RegisterClassExW(&wc);
        return s_atom;
    }

    ATOM RegisterOverlayPosterShieldWindowClass(HINSTANCE hInstance) {
        static ATOM s_atom = 0;
        if (s_atom != 0) {
            return s_atom;
        }

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = pomodoro::OverlayPosterShieldWndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = sizeof(LONG_PTR);
        wc.hInstance = hInstance;
        wc.hIcon = nullptr;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
        wc.lpszMenuName = nullptr;
        wc.lpszClassName = kOverlayPosterShieldWindowClassName;
        wc.hIconSm = nullptr;

        s_atom = RegisterClassExW(&wc);
        return s_atom;
    }

} // namespace

namespace pomodoro {

    LRESULT CALLBACK OverlayUiWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        auto* self = reinterpret_cast<OverlayWindowWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        switch (msg) {
        case WM_NCCREATE: {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs ? cs->lpCreateParams : nullptr));
            return TRUE;
        }
        case WM_NCHITTEST: {
            if (!self) return HTTRANSPARENT;
            POINT pt{ GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
            RECT rc{};
            GetWindowRect(hwnd, &rc);
            pt.x -= rc.left;
            pt.y -= rc.top;
            return PtInRect(&self->uiCancelButtonRect_, pt) ? HTCLIENT : HTTRANSPARENT;
        }
        case WM_LBUTTONDOWN:
            if (self) {
                POINT pt{ GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
                if (PtInRect(&self->uiCancelButtonRect_, pt)) {
                    self->uiCancelPressed_ = true;
                    self->renderUiOverlay();
                }
            }
            return 0;
        case WM_LBUTTONUP:
            if (self) {
                POINT pt{ GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
                const bool wasPressed = self->uiCancelPressed_;
                self->uiCancelPressed_ = false;
                self->renderUiOverlay();
                if (wasPressed && PtInRect(&self->uiCancelButtonRect_, pt)) {
                    if (self->onDismiss_) self->onDismiss_();
                }
            }
            return 0;
        case WM_PAINT:
            if (self) {
                self->renderUiOverlay();
                ValidateRect(hwnd, nullptr);
                return 0;
            }
            break;
        default:
            break;
        }
        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    LRESULT CALLBACK OverlayPosterShieldWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        auto* self = reinterpret_cast<OverlayWindowWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        switch (msg) {
        case WM_NCCREATE: {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs ? cs->lpCreateParams : nullptr));
            return TRUE;
        }
        case WM_ERASEBKGND:
            return 1;
        case WM_PAINT: {
            if (self) {
                self->renderPosterShield();
                ValidateRect(hwnd, nullptr);
                return 0;
            }
            break;
        }
        default:
            break;
        }
        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    class MfPlayCallback final : public IMFPMediaPlayerCallback {
    public:
        explicit MfPlayCallback(std::function<void(MFP_EVENT_HEADER*)> handler)
            : handler_(std::move(handler)) {}

        STDMETHODIMP QueryInterface(REFIID riid, void** ppv) {
            if (!ppv) return E_POINTER;
            if (riid == __uuidof(IUnknown) || riid == __uuidof(IMFPMediaPlayerCallback)) {
                *ppv = static_cast<IMFPMediaPlayerCallback*>(this);
                AddRef();
                return S_OK;
            }
            *ppv = nullptr;
            return E_NOINTERFACE;
        }

        STDMETHODIMP_(ULONG) AddRef() {
            return InterlockedIncrement(&refCount_);
        }

        STDMETHODIMP_(ULONG) Release() {
            const ULONG v = InterlockedDecrement(&refCount_);
            if (v == 0) delete this;
            return v;
        }

        void STDMETHODCALLTYPE OnMediaPlayerEvent(MFP_EVENT_HEADER* pEventHeader) {
            if (handler_) handler_(pEventHeader);
        }

    private:
        ~MfPlayCallback() = default;
        LONG refCount_{ 1 };
        std::function<void(MFP_EVENT_HEADER*)> handler_{};
    };

    struct OverlayVideoPlayerWin32 {
        ~OverlayVideoPlayerWin32() { stop(); }

        void start(HWND hwnd, const std::wstring& path, double playbackRate) {
            stop();
            if (!hwnd || path.empty()) return;

            if (FAILED(MFStartup(MF_VERSION))) {
                return;
            }
            mfStarted_ = true;

            hwnd_ = hwnd;
            playbackRate_ = (playbackRate > 0.0) ? playbackRate : 1.0;

            callback_ = new (std::nothrow) MfPlayCallback([this](MFP_EVENT_HEADER* e) { onEvent(e); });
            if (!callback_) return;

            IMFPMediaPlayer* player = nullptr;
            const HRESULT hr = MFPCreateMediaPlayer(
                path.c_str(),
                FALSE,
                MFP_OPTION_NONE,
                callback_,
                hwnd_,
                &player
            );
            if (FAILED(hr) || !player) {
                return;
            }
            player_ = player;

            player_->SetAspectRatioMode(MFVideoARMode_PreservePicture);
            updateVideoWindowLayout();
            player_->Play();
            player_->SetRate(static_cast<float>(playbackRate_));
        }

        void stop() {
            if (player_) {
                player_->Stop();
                player_->Shutdown();
                player_->Release();
                player_ = nullptr;
            }
            if (callback_) {
                callback_->Release();
                callback_ = nullptr;
            }
            hwnd_ = nullptr;
            playbackRate_ = 1.0;
            if (mfStarted_) {
                MFShutdown();
                mfStarted_ = false;
            }
        }

        void onResize() { updateVideoWindowLayout(); }

        LONGLONG currentPosition100ns() const {
            if (!player_) return 0;
            PROPVARIANT pv{};
            PropVariantInit(&pv);
            const HRESULT hr = player_->GetPosition(MFP_POSITIONTYPE_100NS, &pv);
            LONGLONG v = 0;
            if (SUCCEEDED(hr) && pv.vt == VT_I8) v = pv.hVal.QuadPart;
            PropVariantClear(&pv);
            return v;
        }

    private:
        void onEvent(MFP_EVENT_HEADER* e) {
            // Keep layout in sync (MFPlay may recreate the internal video window).
            updateVideoWindowLayout();

            // Loop playback: when playback ends, seek to 0 and play again.
            if (!e || !player_) return;
            if (e->eEventType != MFP_EVENT_TYPE_PLAYBACK_ENDED) return;

            // Some decoders briefly tear down the video surface at loop boundary; show poster to cover.
            // Must post to UI thread; MFPlay callback may come from a non-UI thread.
            if (hwnd_) {
                PostMessageW(hwnd_, kMsgShowPosterForLoop, 0, 0);
            }

            PROPVARIANT pv{};
            PropVariantInit(&pv);
            pv.vt = VT_I8;
            pv.hVal.QuadPart = 0; // 0s in 100ns
            player_->SetPosition(MFP_POSITIONTYPE_100NS, &pv);
            PropVariantClear(&pv);

            player_->Play();
            player_->SetRate(static_cast<float>(playbackRate_));
        }

        void updateVideoWindowLayout() {
            if (!player_ || !hwnd_) return;
            RECT rc{};
            GetClientRect(hwnd_, &rc);

            // Make the video "cover" the window (no letterbox) by cropping the source to match the
            // destination aspect ratio, while keeping MFPlay in PreservePicture mode (no distortion).
            //
            // We use the decoded poster's dimensions as the video's aspect ratio reference.
            if ((rc.right - rc.left) > 0 && (rc.bottom - rc.top) > 0 && g_videoPoster) {
                const double dstW = static_cast<double>(rc.right - rc.left);
                const double dstH = static_cast<double>(rc.bottom - rc.top);
                const double dstAR = dstW / dstH;

                const double srcW = static_cast<double>(g_videoPoster->GetWidth());
                const double srcH = static_cast<double>(g_videoPoster->GetHeight());
                const double srcAR = (srcH > 0.0) ? (srcW / srcH) : 0.0;

                if (srcAR > 0.0) {
                    MFVideoNormalizedRect nrc{};
                    nrc.left = 0.0f;
                    nrc.top = 0.0f;
                    nrc.right = 1.0f;
                    nrc.bottom = 1.0f;

                    if (dstAR > srcAR) {
                        // Window is wider => crop vertically.
                        const double normH = srcAR / dstAR; // < 1
                        const double top = (1.0 - normH) * 0.5;
                        nrc.top = static_cast<float>(top);
                        nrc.bottom = static_cast<float>(top + normH);
                    } else if (dstAR < srcAR) {
                        // Window is taller => crop horizontally.
                        const double normW = dstAR / srcAR; // < 1
                        const double left = (1.0 - normW) * 0.5;
                        nrc.left = static_cast<float>(left);
                        nrc.right = static_cast<float>(left + normW);
                    }

                    // Best-effort: on some SDKs this API may not exist; compile will tell us.
                    player_->SetVideoSourceRect(&nrc);
                }
            } else {
                // Reset crop to full frame.
                MFVideoNormalizedRect nrc{};
                nrc.left = 0.0f;
                nrc.top = 0.0f;
                nrc.right = 1.0f;
                nrc.bottom = 1.0f;
                player_->SetVideoSourceRect(&nrc);
            }

            HWND videoHwnd = nullptr;
            if (SUCCEEDED(player_->GetVideoWindow(&videoHwnd)) && videoHwnd) {
                if (GetParent(videoHwnd) != hwnd_) {
                    SetParent(videoHwnd, hwnd_);
                }
                LONG_PTR style = GetWindowLongPtrW(videoHwnd, GWL_STYLE);
                style &= ~static_cast<LONG_PTR>(WS_POPUP);
                style |= static_cast<LONG_PTR>(WS_CHILD);
                SetWindowLongPtrW(videoHwnd, GWL_STYLE, style);

                SetWindowPos(
                    videoHwnd,
                    HWND_BOTTOM,
                    rc.left,
                    rc.top,
                    rc.right - rc.left,
                    rc.bottom - rc.top,
                    SWP_NOACTIVATE | SWP_SHOWWINDOW
                );
            }

            player_->UpdateVideo();
        }

        HWND hwnd_{ nullptr };
        double playbackRate_{ 1.0 };
        IMFPMediaPlayer* player_{ nullptr };
        MfPlayCallback* callback_{ nullptr };
        bool mfStarted_{ false };
    };

    void OverlayWindowWin32::PrepareNextBackgroundForRest() {
        g_preparedKind = PreparedKind::None;
        g_backgroundImage.reset();
        g_videoPoster.reset();
        g_preparedVideoPath.clear();
        g_preparedVideoPlaybackRate = 1.0;
        g_overlayMessage.clear();

        BackgroundSettingsWin32 settings;
        const std::wstring settingsPath = BackgroundSettingsWin32::DefaultConfigPath();
        if (!settings.loadFromFile(settingsPath)) {
            return;
        }

        g_overlayMessage = settings.overlayMessage();

        const auto& files = settings.files();
        if (files.empty()) return;

        // Mixed rotation across image/video list.
        // Each rest cycle advances to the next entry; invalid entries are skipped.
        const std::size_t n = files.size();
        std::size_t start = (g_backgroundRotateCursor >= n) ? 0 : g_backgroundRotateCursor;

        for (std::size_t attempt = 0; attempt < n; ++attempt) {
            const std::size_t idx = (start + attempt) % n;
            const auto& f = files[idx];
            if (f.path.empty()) continue;

            // Advance cursor so next rest cycle tries the following item first.
            g_backgroundRotateCursor = (idx + 1) % n;

            if (f.type == BackgroundType::Image) {
                auto img = TryLoadBackgroundImage(f.path);
                if (img) {
                    g_backgroundImage = std::move(img);
                    g_preparedKind = PreparedKind::Image;
                    return;
                }
            } else {
                g_preparedKind = PreparedKind::Video;
                g_preparedVideoPath = f.path;
                g_preparedVideoPlaybackRate = (f.playbackRate > 0.0) ? f.playbackRate : 1.0;
                g_videoPoster = TryDecodeVideoPosterFrame(f.path);
                return;
            }
        }
    }

    OverlayWindowWin32::OverlayWindowWin32() = default;

    OverlayWindowWin32::~OverlayWindowWin32() {
        if (posterTimerId_ != 0 && hwnd_) {
            KillTimer(hwnd_, posterTimerId_);
            posterTimerId_ = 0;
        }
        if (fadeTimerId_ != 0 && hwnd_) {
            KillTimer(hwnd_, fadeTimerId_);
            fadeTimerId_ = 0;
        }
        if (startFadeTimerId_ != 0 && hwnd_) {
            KillTimer(hwnd_, startFadeTimerId_);
            startFadeTimerId_ = 0;
        }
        if (revealUiAfterPosterTimerId_ != 0 && hwnd_) {
            KillTimer(hwnd_, revealUiAfterPosterTimerId_);
            revealUiAfterPosterTimerId_ = 0;
        }
        if (ensureTopmostTimerId_ != 0 && hwnd_) {
            KillTimer(hwnd_, ensureTopmostTimerId_);
            ensureTopmostTimerId_ = 0;
        }
        if (buttonFont_) {
            DeleteObject(buttonFont_);
            buttonFont_ = nullptr;
        }
        if (videoPlayer_) {
            videoPlayer_->stop();
            videoPlayer_.reset();
        }
        if (uiOverlayWindow_) {
            DestroyWindow(uiOverlayWindow_);
            uiOverlayWindow_ = nullptr;
        }
        if (posterShieldWindow_) {
            DestroyWindow(posterShieldWindow_);
            posterShieldWindow_ = nullptr;
        }
        if (hwnd_) {
            DestroyWindow(hwnd_);
            hwnd_ = nullptr;
        }
    }

    bool OverlayWindowWin32::create(HINSTANCE hInstance, const RECT& bounds, DismissCallback onDismiss) {
        hInstance_ = hInstance;
        bounds_ = bounds;
        onDismiss_ = std::move(onDismiss);

        if (!RegisterOverlayWindowClass(hInstance_)) {
            return false;
        }
        RegisterOverlayUiWindowClass(hInstance_);
        RegisterOverlayPosterShieldWindowClass(hInstance_);

        const DWORD exStyle = WS_EX_TOPMOST | WS_EX_TOOLWINDOW;
        const DWORD style = WS_POPUP;

        hwnd_ = CreateWindowExW(
            exStyle,
            kOverlayWindowClassName,
            L"Pomodoro Overlay",
            style,
            bounds_.left,
            bounds_.top,
            bounds_.right - bounds_.left,
            bounds_.bottom - bounds_.top,
            nullptr,
            nullptr,
            hInstance_,
            this // lpParam -> WM_NCCREATE
        );

        if (!hwnd_) {
            DWORD err = GetLastError();
            std::cerr << "[OverlayWindow] CreateWindowExW failed, error=" << err << "\n";
            return false;
        }

        EnsureGdiplusStarted();

        // Create separate topmost UI overlay (layered) so the message/button are always above video.
        if (!uiOverlayWindow_) {
            const DWORD uiEx = WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_NOACTIVATE;
            const DWORD uiStyle = WS_POPUP;
            uiOverlayWindow_ = CreateWindowExW(
                uiEx,
                kOverlayUiWindowClassName,
                L"",
                uiStyle,
                bounds_.left,
                bounds_.top,
                bounds_.right - bounds_.left,
                bounds_.bottom - bounds_.top,
                nullptr,
                nullptr,
                hInstance_,
                this
            );
            if (uiOverlayWindow_) {
                layoutUiOverlay();
                renderUiOverlay();
                ShowWindow(uiOverlayWindow_, SW_HIDE);
            }
        }

        // Create non-layered poster shield window (kept hidden by default).
        if (!posterShieldWindow_) {
            // Use a layered window so the poster shield can be truly transparent (no black background flash).
            const DWORD ex = WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_LAYERED;
            const DWORD st = WS_POPUP;
            posterShieldWindow_ = CreateWindowExW(
                ex,
                kOverlayPosterShieldWindowClassName,
                L"",
                st,
                bounds_.left,
                bounds_.top,
                bounds_.right - bounds_.left,
                bounds_.bottom - bounds_.top,
                nullptr,
                nullptr,
                hInstance_,
                this
            );
            if (posterShieldWindow_) {
                ShowWindow(posterShieldWindow_, SW_HIDE);
            }
        }

        return true;
    }

    void OverlayWindowWin32::show() {
        if (!hwnd_) {
            return;
        }
        const bool isVideo = (g_preparedKind == PreparedKind::Video && !g_preparedVideoPath.empty());
        const bool willShowPoster = isVideo && (g_videoPoster != nullptr);

        // For video + poster mode, avoid showing the main window until the poster shield is visible.
        // This prevents a brief black paint of the main window before the poster appears.
        if (willShowPoster) {
            ShowWindow(hwnd_, SW_HIDE);
        } else {
            ShowWindow(hwnd_, SW_SHOW);
            UpdateWindow(hwnd_);
        }
        isVisible_ = true;

        SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

        // MFPlay (and system focus/z-order changes) can cause the main video window to slip behind.
        // Keep a small timer that periodically reasserts: video (base) -> poster (optional) -> UI (top).
        if (ensureTopmostTimerId_ == 0) {
            ensureTopmostTimerId_ = SetTimer(hwnd_, kTimerEnsureTopmost, 250, nullptr);
        }

        // Use a separate UI overlay window for message + cancel button.
        textAlpha_ = 255;
        if (cancelButton_) {
            ShowWindow(cancelButton_, SW_HIDE);
        }
        // For video mode, we will reveal the UI overlay only after the poster shield has been shown,
        // to avoid showing text/button on top of a blank/black frame.
        if (uiOverlayWindow_) {
            ShowWindow(uiOverlayWindow_, SW_HIDE);
        }

        if (isVideo) {
            if (!videoPlayer_) {
                videoPlayer_ = std::make_unique<OverlayVideoPlayerWin32>();
            }
            videoPlayer_->start(hwnd_, g_preparedVideoPath, g_preparedVideoPlaybackRate);

            posterVisible_ = (g_videoPoster != nullptr);
            posterShownTick_ = GetTickCount64();

            if (posterShieldWindow_) {
                if (posterVisible_) {
                    SetWindowPos(
                        posterShieldWindow_,
                        HWND_TOPMOST,
                        bounds_.left,
                        bounds_.top,
                        bounds_.right - bounds_.left,
                        bounds_.bottom - bounds_.top,
                        SWP_NOACTIVATE | SWP_SHOWWINDOW
                    );
                    // Render after the window is shown to avoid a one-frame blank layered surface.
                    renderPosterShield();
                } else {
                    ShowWindow(posterShieldWindow_, SW_HIDE);
                }
            }

            // Now that the poster is visible (covering the screen), show the video host window behind it.
            if (willShowPoster) {
                ShowWindow(hwnd_, SW_SHOW);
                UpdateWindow(hwnd_);
            }

            if (uiOverlayWindow_) {
                // Reveal UI overlay after poster is visible (next tick).
                if (revealUiAfterPosterTimerId_ != 0) {
                    KillTimer(hwnd_, revealUiAfterPosterTimerId_);
                    revealUiAfterPosterTimerId_ = 0;
                }
                if (posterVisible_) {
                    revealUiAfterPosterTimerId_ = SetTimer(hwnd_, kTimerRevealUiAfterPoster, 16, nullptr);
                } else {
                    // No poster available -> show UI immediately.
                    layoutUiOverlay();
                    renderUiOverlay();
                    ShowWindow(uiOverlayWindow_, SW_SHOWNOACTIVATE);
                    SetWindowPos(uiOverlayWindow_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
                }
            }

            if (posterTimerId_ != 0) {
                KillTimer(hwnd_, posterTimerId_);
            }
            posterTimerId_ = SetTimer(hwnd_, kTimerHidePoster, 50, nullptr);
        } else {
            // Non-video: show UI overlay immediately.
            if (uiOverlayWindow_) {
                layoutUiOverlay();
                renderUiOverlay();
                ShowWindow(uiOverlayWindow_, SW_SHOWNOACTIVATE);
                SetWindowPos(uiOverlayWindow_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
            }

            // Non-video: stop any existing video player and poster.
            if (videoPlayer_) {
                videoPlayer_->stop();
                videoPlayer_.reset();
            }
            posterVisible_ = false;
            if (posterShieldWindow_) {
                ShowWindow(posterShieldWindow_, SW_HIDE);
            }
            if (posterTimerId_ != 0) {
                KillTimer(hwnd_, posterTimerId_);
                posterTimerId_ = 0;
            }
        }
    }

    void OverlayWindowWin32::hide() {
        if (!hwnd_) {
            return;
        }
        if (revealUiAfterPosterTimerId_ != 0) {
            KillTimer(hwnd_, revealUiAfterPosterTimerId_);
            revealUiAfterPosterTimerId_ = 0;
        }
        if (ensureTopmostTimerId_ != 0) {
            KillTimer(hwnd_, ensureTopmostTimerId_);
            ensureTopmostTimerId_ = 0;
        }
        if (posterTimerId_ != 0) {
            KillTimer(hwnd_, posterTimerId_);
            posterTimerId_ = 0;
        }
        posterVisible_ = false;
        posterShownTick_ = 0;
        if (videoPlayer_) {
            videoPlayer_->stop();
            videoPlayer_.reset();
        }
        ShowWindow(hwnd_, SW_HIDE);
        isVisible_ = false;
        if (uiOverlayWindow_) {
            ShowWindow(uiOverlayWindow_, SW_HIDE);
        }
        if (posterShieldWindow_) {
            ShowWindow(posterShieldWindow_, SW_HIDE);
        }
    }

    bool OverlayWindowWin32::isVisible() const {
        return isVisible_;
    }

    LRESULT CALLBACK OverlayWindowWin32::WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        OverlayWindowWin32* self = nullptr;

        if (msg == WM_NCCREATE) {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            self = static_cast<OverlayWindowWin32*>(cs->lpCreateParams);
            // Important: WM_CREATE is dispatched before CreateWindowExW returns, so members set after
            // CreateWindowExW (like hwnd_) are not available yet. Store hwnd now so DPI/layout code
            // in WM_CREATE can use it safely.
            if (self) {
                self->hwnd_ = hwnd;
            }
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        } else {
            self = reinterpret_cast<OverlayWindowWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        }

        if (self) {
            switch (msg) {
            case WM_DESTROY:
                return 0;
            default:
                return self->handleMessage(hwnd, msg, wParam, lParam);
            }
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    LRESULT OverlayWindowWin32::handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        switch (msg) {
        case kMsgShowPosterForLoop: {
            // Re-show poster shield to mask any transient frame gap during loop restart.
            if (posterShieldWindow_ && g_videoPoster) {
                posterVisible_ = true;
                posterShownTick_ = GetTickCount64();

                SetWindowPos(
                    posterShieldWindow_,
                    HWND_TOPMOST,
                    bounds_.left,
                    bounds_.top,
                    bounds_.right - bounds_.left,
                    bounds_.bottom - bounds_.top,
                    SWP_NOACTIVATE | SWP_SHOWWINDOW
                );
                renderPosterShield();

                // Ensure z-order: poster below UI overlay.
                if (uiOverlayWindow_) {
                    SetWindowPos(uiOverlayWindow_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
                }

                // Ensure hide timer is running to remove poster once video is rolling again.
                if (posterTimerId_ == 0) {
                    posterTimerId_ = SetTimer(hwnd_, kTimerHidePoster, 50, nullptr);
                }
            }
            return 0;
        }
        case WM_CREATE: {
            dpi_ = pomodoro::win32::GetDpiForHwnd(hwnd);
            // 创建“取消休息”按钮，位于窗口底部中间
            cancelButton_ = CreateWindowExW(
                0,
                L"BUTTON",
                L"\u53d6\u6d88\u4f11\u606f", // "取消休息"
                WS_CHILD | WS_VISIBLE | BS_OWNERDRAW | WS_TABSTOP,
                0, 0, 10, 10, // 真实位置/大小在 layoutCancelButton 中按 DPI 计算
                hwnd,
                reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdCancelButton)),
                hInstance_,
                nullptr
            );

            // 设置按钮字体，使其更接近 macOS 的粗体样式
            if (!buttonFont_) {
                buttonFont_ = pomodoro::win32::CreateUiFontPx(18, FW_SEMIBOLD, L"Segoe UI", dpi_);
            }
            if (cancelButton_ && buttonFont_) {
                SendMessageW(cancelButton_, WM_SETFONT, reinterpret_cast<WPARAM>(buttonFont_), TRUE);
            }

            layoutCancelButton();
            if (cancelButton_) {
                // UI is rendered by a separate topmost window to stay above video.
                ShowWindow(cancelButton_, SW_HIDE);
            }
            layoutUiOverlay();
            renderUiOverlay();
            return 0;
        }
        case WM_DPICHANGED: {
            const UINT newDpi = HIWORD(wParam);
            auto* suggested = reinterpret_cast<RECT*>(lParam);
            applyDpiLayout(newDpi, suggested);
            return 0;
        }
        case WM_SIZE:
            if (videoPlayer_) {
                videoPlayer_->onResize();
            }
            layoutCancelButton();
            layoutUiOverlay();
            renderUiOverlay();
            return 0;
        case WM_PAINT:
            paint();
            return 0;

        case WM_LBUTTONDOWN:
        case WM_RBUTTONDOWN:
        case WM_MBUTTONDOWN:
            // 点击遮罩其他区域不再隐藏遮罩层，保持遮罩存在
            return 0;

        case WM_KEYDOWN:
            // 仅在按 ESC 时关闭遮罩，与 macOS 行为保持一致
            if (wParam == VK_ESCAPE) {
                if (onDismiss_) {
                    onDismiss_();
                }
                return 0;
            }
            break;

        case WM_COMMAND: {
            const int id = LOWORD(wParam);
            const int code = HIWORD(wParam);
            if (id == kIdCancelButton && code == BN_CLICKED) {
                // 点击“取消休息”按钮：关闭遮罩层
                if (onDismiss_) {
                    onDismiss_();
                }
                return 0;
            }
            break;
        }

        case WM_DRAWITEM: {
            const int id = static_cast<int>(wParam);
            if (id == kIdCancelButton) {
                auto* dis = reinterpret_cast<LPDRAWITEMSTRUCT>(lParam);
                if (!dis) break;

                HDC hdc = dis->hDC;

                // 简化为矩形按钮样式：深色背景 + 白色描边 + 白色文字
                const bool isPressed = (dis->itemState & ODS_SELECTED) != 0;
                const COLORREF borderColor = RGB(255, 255, 255);
                const COLORREF fillColor = isPressed
                    ? RGB(255, 255, 255)
                    : RGB(0, 0, 0);

                HBRUSH bgBrush = CreateSolidBrush(fillColor);
                HPEN borderPen = CreatePen(PS_SOLID, 1, borderColor);

                HGDIOBJ oldBrush = SelectObject(hdc, bgBrush);
                HGDIOBJ oldPen = SelectObject(hdc, borderPen);

                RECT r = dis->rcItem;
                // 留一点内边距，避免贴边
                const UINT dpi = dpi_ ? dpi_ : pomodoro::win32::GetDpiForHwnd(hwnd_);
                InflateRect(&r, -pomodoro::win32::Scale(2, dpi), -pomodoro::win32::Scale(2, dpi));
                Rectangle(hdc, r.left, r.top, r.right, r.bottom);

                SelectObject(hdc, oldBrush);
                SelectObject(hdc, oldPen);
                DeleteObject(bgBrush);
                DeleteObject(borderPen);

                // 绘制文字（使用 GDI+ 提升抗锯齿效果）
                if (g_gdiplusToken != 0) {
                    Gdiplus::Graphics graphics(hdc);
                    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
                    graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

                    Gdiplus::FontFamily family(L"Segoe UI");
                    // 使用粗体近似 macOS 的半粗体效果
                    const float fontPx = static_cast<float>(pomodoro::win32::Scale(14, dpi));
                    Gdiplus::Font font(&family, fontPx, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);

                    Gdiplus::Color color(
                        255,
                        isPressed ? 0 : 255,
                        isPressed ? 0 : 255,
                        isPressed ? 0 : 255
                    );
                    Gdiplus::SolidBrush brush(color);

                    Gdiplus::StringFormat format;
                    format.SetAlignment(Gdiplus::StringAlignmentCenter);
                    format.SetLineAlignment(Gdiplus::StringAlignmentCenter);

                    const wchar_t* text = L"\u53d6\u6d88\u4f11\u606f"; // "取消休息"

                    Gdiplus::RectF rect(
                        static_cast<Gdiplus::REAL>(dis->rcItem.left),
                        static_cast<Gdiplus::REAL>(dis->rcItem.top),
                        static_cast<Gdiplus::REAL>(dis->rcItem.right - dis->rcItem.left),
                        static_cast<Gdiplus::REAL>(dis->rcItem.bottom - dis->rcItem.top)
                    );

                    graphics.DrawString(text, -1, &font, rect, &format, &brush);
                } else {
                    // 回退到 GDI 文本绘制
                    SetBkMode(hdc, TRANSPARENT);
                    SetTextColor(hdc, isPressed ? RGB(0, 0, 0) : RGB(255, 255, 255));

                    const wchar_t* text = L"\u53d6\u6d88\u4f11\u606f"; // "取消休息"

                    DrawTextW(
                        hdc,
                        text,
                        -1,
                        &dis->rcItem,
                        DT_CENTER | DT_VCENTER | DT_SINGLELINE
                    );
                }

                return TRUE;
            }
            break;
        }

        case WM_TIMER:
            if (wParam == kTimerStartFadeText) {
                KillTimer(hwnd, kTimerStartFadeText);
                startFadeTimerId_ = 0;
                // 直接隐藏文本，避免频繁重绘导致的闪烁
                textAlpha_ = 0;
                renderUiOverlay();
                return 0;
            }
            if (wParam == kTimerEnsureTopmost) {
                if (!isVisible_ || !hwnd_) {
                    return 0;
                }

                // Ensure the video host window stays topmost (above normal windows).
                SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

                // If the poster shield is currently visible, keep it above the video.
                if (posterShieldWindow_ && posterVisible_) {
                    SetWindowPos(posterShieldWindow_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
                }

                // Always keep UI overlay above everything else.
                if (uiOverlayWindow_) {
                    SetWindowPos(uiOverlayWindow_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
                }
                return 0;
            }
            if (wParam == kTimerRevealUiAfterPoster) {
                if (revealUiAfterPosterTimerId_ != 0) {
                    KillTimer(hwnd_, revealUiAfterPosterTimerId_);
                    revealUiAfterPosterTimerId_ = 0;
                }
                if (uiOverlayWindow_) {
                    layoutUiOverlay();
                    renderUiOverlay();
                    ShowWindow(uiOverlayWindow_, SW_SHOWNOACTIVATE);
                    SetWindowPos(uiOverlayWindow_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
                }
                return 0;
            }
            if (wParam == kTimerHidePoster) {
                if (!posterVisible_) {
                    if (posterTimerId_ != 0) {
                        KillTimer(hwnd_, posterTimerId_);
                        posterTimerId_ = 0;
                    }
                    return 0;
                }
                const ULONGLONG now = GetTickCount64();
                const ULONGLONG elapsed = (posterShownTick_ > 0) ? (now - posterShownTick_) : 0;
                const LONGLONG pos100ns = videoPlayer_ ? videoPlayer_->currentPosition100ns() : 0;

                const bool shouldHide = ((pos100ns > 5'000'000) && (elapsed > 300)) || (elapsed > 3000);
                if (shouldHide) {
                    posterVisible_ = false;
                    posterShownTick_ = 0;
                    if (posterShieldWindow_) {
                        ShowWindow(posterShieldWindow_, SW_HIDE);
                    }
                    if (posterTimerId_ != 0) {
                        KillTimer(hwnd_, posterTimerId_);
                        posterTimerId_ = 0;
                    }
                }
                return 0;
            }
            break;

        case WM_ERASEBKGND:
            // 由 WM_PAINT 完成背景绘制
            return 1;

        default:
            break;
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    void OverlayWindowWin32::paint() {
        if (!hwnd_) {
            return;
        }

        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd_, &ps);
        if (!hdc) {
            std::cerr << "[OverlayWindow] BeginPaint returned null HDC\n";
            return;
        }

        RECT client{};
        GetClientRect(hwnd_, &client);

        // 优先绘制用户配置的背景图片（填充模式，保持宽高比）
        if (g_preparedKind == PreparedKind::Image && g_backgroundImage && g_gdiplusToken != 0) {
            Gdiplus::Graphics graphics(hdc);
            graphics.SetCompositingQuality(Gdiplus::CompositingQualityHighQuality);
            graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
            graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);

            const auto imgWidth = static_cast<float>(g_backgroundImage->GetWidth());
            const auto imgHeight = static_cast<float>(g_backgroundImage->GetHeight());

            if (imgWidth > 0.0f && imgHeight > 0.0f) {
                const float clientWidth = static_cast<float>(client.right - client.left);
                const float clientHeight = static_cast<float>(client.bottom - client.top);

                const float scaleX = clientWidth / imgWidth;
                const float scaleY = clientHeight / imgHeight;
                const float scale = (scaleX > scaleY) ? scaleX : scaleY; // 等价于 max(scaleX, scaleY)

                const float scaledWidth = imgWidth * scale;
                const float scaledHeight = imgHeight * scale;

                const float offsetX = (clientWidth - scaledWidth) * 0.5f;
                const float offsetY = (clientHeight - scaledHeight) * 0.5f;

                Gdiplus::RectF destRect(
                    static_cast<Gdiplus::REAL>(client.left + offsetX),
                    static_cast<Gdiplus::REAL>(client.top + offsetY),
                    static_cast<Gdiplus::REAL>(scaledWidth),
                    static_cast<Gdiplus::REAL>(scaledHeight));

                graphics.DrawImage(g_backgroundImage.get(), destRect);
            }
        } else {
            // 没有背景图时，退回到纯黑背景
            HBRUSH brush = CreateSolidBrush(RGB(0, 0, 0));
            FillRect(hdc, &client, brush);
            DeleteObject(brush);
        }

        // 绘制提示文本：初始全亮，随后通过 textAlpha_ 渐变消失
        // Fallback: if the topmost UI overlay window failed to create, draw text on the main window.
        if (uiOverlayWindow_ == nullptr && textAlpha_ > 0 && g_gdiplusToken != 0) {
            Gdiplus::Graphics graphics(hdc);
            graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);
            Gdiplus::FontFamily family(L"Segoe UI");
            const UINT dpi = dpi_ ? dpi_ : pomodoro::win32::GetDpiForHwnd(hwnd_);
            const float fontPx = static_cast<float>(pomodoro::win32::Scale(32, dpi));
            Gdiplus::Font font(&family, fontPx, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);

            Gdiplus::Color color(textAlpha_, 255, 255, 255);
            Gdiplus::SolidBrush brush(color);

            Gdiplus::StringFormat format;
            format.SetAlignment(Gdiplus::StringAlignmentCenter);
            format.SetLineAlignment(Gdiplus::StringAlignmentCenter);

            const wchar_t* text = (!g_overlayMessage.empty()) ? g_overlayMessage.c_str() : L"Rest Time - PomodoroScreen";
            Gdiplus::RectF rect(
                static_cast<Gdiplus::REAL>(client.left),
                static_cast<Gdiplus::REAL>(client.top - pomodoro::win32::Scale(80, dpi)), // 稍微上移，避免挡住按钮
                static_cast<Gdiplus::REAL>(client.right - client.left),
                static_cast<Gdiplus::REAL>(client.bottom - client.top)
            );

            graphics.DrawString(text, -1, &font, rect, &format, &brush);
        }

        EndPaint(hwnd_, &ps);
    }

    void OverlayWindowWin32::applyDpiLayout(UINT dpi, const RECT* suggestedWindowRect) {
        dpi_ = dpi ? dpi : 96;

        if (suggestedWindowRect && hwnd_) {
            // Per-monitor DPI change: accept system suggested rect for this top-level window
            SetWindowPos(
                hwnd_,
                nullptr,
                suggestedWindowRect->left,
                suggestedWindowRect->top,
                suggestedWindowRect->right - suggestedWindowRect->left,
                suggestedWindowRect->bottom - suggestedWindowRect->top,
                SWP_NOZORDER | SWP_NOACTIVATE
            );
        }

        // Refresh button font at new DPI
        if (buttonFont_) {
            DeleteObject(buttonFont_);
            buttonFont_ = nullptr;
        }
        buttonFont_ = pomodoro::win32::CreateUiFontPx(18, FW_SEMIBOLD, L"Segoe UI", dpi_);
        if (cancelButton_ && buttonFont_) {
            SendMessageW(cancelButton_, WM_SETFONT, reinterpret_cast<WPARAM>(buttonFont_), TRUE);
        }

        layoutCancelButton();
        layoutUiOverlay();
        renderUiOverlay();
        InvalidateRect(hwnd_, nullptr, TRUE);
        renderPosterShield();
    }

    void OverlayWindowWin32::layoutCancelButton() {
        if (!hwnd_ || !cancelButton_) return;

        RECT client{};
        GetClientRect(hwnd_, &client);

        const UINT dpi = dpi_ ? dpi_ : pomodoro::win32::GetDpiForHwnd(hwnd_);
        const int btnWidth = pomodoro::win32::Scale(140, dpi);
        const int btnHeight = pomodoro::win32::Scale(44, dpi);
        const int centerX = (client.right - client.left) / 2;
        const int bottom = client.bottom - pomodoro::win32::Scale(70, dpi);

        SetWindowPos(
            cancelButton_,
            nullptr,
            centerX - btnWidth / 2,
            bottom - btnHeight / 2,
            btnWidth,
            btnHeight,
            SWP_NOZORDER | SWP_NOACTIVATE
        );
    }

    void OverlayWindowWin32::layoutUiOverlay() {
        const UINT dpi = dpi_ ? dpi_ : 96;
        const int w = bounds_.right - bounds_.left;
        const int h = bounds_.bottom - bounds_.top;

        const int btnWidth = pomodoro::win32::Scale(140, dpi);
        const int btnHeight = pomodoro::win32::Scale(44, dpi);
        const int centerX = w / 2;
        const int bottom = h - pomodoro::win32::Scale(70, dpi);

        uiCancelButtonRect_.left = centerX - btnWidth / 2;
        uiCancelButtonRect_.right = uiCancelButtonRect_.left + btnWidth;
        uiCancelButtonRect_.top = bottom - btnHeight / 2;
        uiCancelButtonRect_.bottom = uiCancelButtonRect_.top + btnHeight;

        if (uiOverlayWindow_) {
            SetWindowPos(
                uiOverlayWindow_,
                HWND_TOPMOST,
                bounds_.left,
                bounds_.top,
                w,
                h,
                SWP_NOACTIVATE | SWP_NOSENDCHANGING
            );
        }
        if (posterShieldWindow_) {
            SetWindowPos(
                posterShieldWindow_,
                HWND_TOPMOST,
                bounds_.left,
                bounds_.top,
                w,
                h,
                SWP_NOACTIVATE | SWP_NOSENDCHANGING
            );
        }
    }

    void OverlayWindowWin32::renderUiOverlay() {
        if (!uiOverlayWindow_) return;
        EnsureGdiplusStarted();
        if (g_gdiplusToken == 0) return;

        const int w = bounds_.right - bounds_.left;
        const int h = bounds_.bottom - bounds_.top;
        if (w <= 0 || h <= 0) return;

        HDC screen = GetDC(nullptr);
        HDC mem = CreateCompatibleDC(screen);

        BITMAPINFO bi{};
        bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth = w;
        bi.bmiHeader.biHeight = -h; // top-down
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;

        void* bits = nullptr;
        HBITMAP dib = CreateDIBSection(mem, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
        HGDIOBJ oldBmp = SelectObject(mem, dib);

        if (bits) {
            memset(bits, 0, static_cast<size_t>(w) * static_cast<size_t>(h) * 4); // fully transparent
        }

        {
            Gdiplus::Graphics g(mem);
            g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
            g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

            const UINT dpi = dpi_ ? dpi_ : 96;
            Gdiplus::FontFamily family(L"Segoe UI");
            const float titlePx = static_cast<float>(pomodoro::win32::Scale(32, dpi));
            Gdiplus::Font titleFont(&family, titlePx, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);

            Gdiplus::StringFormat fmt;
            fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
            fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);

            const wchar_t* title = (!g_overlayMessage.empty()) ? g_overlayMessage.c_str() : L"Rest Time - PomodoroScreen";
            Gdiplus::SolidBrush titleBrush(Gdiplus::Color(textAlpha_, 255, 255, 255));
            Gdiplus::RectF titleRect(
                0.0f,
                static_cast<Gdiplus::REAL>(-pomodoro::win32::Scale(80, dpi)),
                static_cast<Gdiplus::REAL>(w),
                static_cast<Gdiplus::REAL>(h)
            );
            g.DrawString(title, -1, &titleFont, titleRect, &fmt, &titleBrush);

            // Cancel button
            const bool pressed = uiCancelPressed_;
            const Gdiplus::Color border(255, 255, 255, 255);
            const Gdiplus::Color fill(255, pressed ? 255 : 0, pressed ? 255 : 0, pressed ? 255 : 0);
            const Gdiplus::Color textC(255, pressed ? 0 : 255, pressed ? 0 : 255, pressed ? 0 : 255);

            Gdiplus::Rect btn(
                uiCancelButtonRect_.left,
                uiCancelButtonRect_.top,
                uiCancelButtonRect_.right - uiCancelButtonRect_.left,
                uiCancelButtonRect_.bottom - uiCancelButtonRect_.top
            );
            Gdiplus::SolidBrush fillBrush(fill);
            Gdiplus::Pen borderPen(border, 1.0f);
            g.FillRectangle(&fillBrush, btn);
            g.DrawRectangle(&borderPen, btn);

            const float btnPx = static_cast<float>(pomodoro::win32::Scale(14, dpi));
            Gdiplus::Font btnFont(&family, btnPx, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
            Gdiplus::SolidBrush btnTextBrush(textC);
            Gdiplus::RectF btnRect(
                static_cast<Gdiplus::REAL>(btn.X),
                static_cast<Gdiplus::REAL>(btn.Y),
                static_cast<Gdiplus::REAL>(btn.Width),
                static_cast<Gdiplus::REAL>(btn.Height)
            );
            g.DrawString(L"\u53d6\u6d88\u4f11\u606f", -1, &btnFont, btnRect, &fmt, &btnTextBrush);
        }

        POINT ptPos{ bounds_.left, bounds_.top };
        SIZE size{ w, h };
        POINT ptSrc{ 0, 0 };
        BLENDFUNCTION bf{};
        bf.BlendOp = AC_SRC_OVER;
        bf.SourceConstantAlpha = 255;
        bf.AlphaFormat = AC_SRC_ALPHA;

        UpdateLayeredWindow(uiOverlayWindow_, screen, &ptPos, &size, mem, &ptSrc, 0, &bf, ULW_ALPHA);

        SelectObject(mem, oldBmp);
        DeleteObject(dib);
        DeleteDC(mem);
        ReleaseDC(nullptr, screen);
    }

    void OverlayWindowWin32::renderPosterShield() {
        if (!posterShieldWindow_) return;
        EnsureGdiplusStarted();
        if (g_gdiplusToken == 0) return;

        const int w = bounds_.right - bounds_.left;
        const int h = bounds_.bottom - bounds_.top;
        if (w <= 0 || h <= 0) return;

        HDC screen = GetDC(nullptr);
        HDC mem = CreateCompatibleDC(screen);

        BITMAPINFO bi{};
        bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth = w;
        bi.bmiHeader.biHeight = -h; // top-down
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;

        void* bits = nullptr;
        HBITMAP dib = CreateDIBSection(mem, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
        HGDIOBJ oldBmp = SelectObject(mem, dib);

        // Default fully transparent.
        if (bits) {
            memset(bits, 0, static_cast<size_t>(w) * static_cast<size_t>(h) * 4);
        }

        if (posterVisible_ && g_videoPoster) {
            Gdiplus::Graphics g(mem);
            g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
            g.SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);

            const int srcW = static_cast<int>(g_videoPoster->GetWidth());
            const int srcH = static_cast<int>(g_videoPoster->GetHeight());
            if (srcW > 0 && srcH > 0) {
                const double scaleX = static_cast<double>(w) / static_cast<double>(srcW);
                const double scaleY = static_cast<double>(h) / static_cast<double>(srcH);
                const double scale = (scaleX > scaleY) ? scaleX : scaleY; // cover

                const int drawW = static_cast<int>(srcW * scale);
                const int drawH = static_cast<int>(srcH * scale);
                const int drawX = (w - drawW) / 2;
                const int drawY = (h - drawH) / 2;

                g.DrawImage(g_videoPoster.get(), Gdiplus::Rect(drawX, drawY, drawW, drawH));
            }
        }

        POINT ptPos{ bounds_.left, bounds_.top };
        SIZE size{ w, h };
        POINT ptSrc{ 0, 0 };
        BLENDFUNCTION bf{};
        bf.BlendOp = AC_SRC_OVER;
        bf.SourceConstantAlpha = 255;
        bf.AlphaFormat = AC_SRC_ALPHA;

        UpdateLayeredWindow(posterShieldWindow_, screen, &ptPos, &size, mem, &ptSrc, 0, &bf, ULW_ALPHA);

        SelectObject(mem, oldBmp);
        DeleteObject(dib);
        DeleteDC(mem);
        ReleaseDC(nullptr, screen);
    }

} // namespace pomodoro


