#include "flutter_window.h"

#include <map>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

// Accent ids from lib/theme/app_accent.dart.
const std::map<std::string, int> kAccentIcons = {
    {"teal", IDI_APP_ICON},       {"blue", IDI_ICON_BLUE},
    {"indigo", IDI_ICON_INDIGO},  {"purple", IDI_ICON_PURPLE},
    {"pink", IDI_ICON_PINK},      {"red", IDI_ICON_RED},
    {"orange", IDI_ICON_ORANGE},  {"green", IDI_ICON_GREEN},
};

HICON LoadIconSized(int id, int size) {
  return static_cast<HICON>(LoadImage(GetModuleHandle(nullptr),
                                      MAKEINTRESOURCE(id), IMAGE_ICON, size,
                                      size, LR_DEFAULTCOLOR));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  if (big_icon_) DestroyIcon(big_icon_);
  if (small_icon_) DestroyIcon(small_icon_);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  icon_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "file_vault/app_icon",
          &flutter::StandardMethodCodec::GetInstance());
  icon_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto* accent = std::get_if<std::string>(call.arguments());
        if (call.method_name() != "setAccent" || accent == nullptr) {
          result->NotImplemented();
          return;
        }
        SetAccentIcon(*accent);
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetAccentIcon(const std::string& accent) {
  const auto it = kAccentIcons.find(accent);
  if (it == kAccentIcons.end()) return;
  HWND hwnd = GetHandle();
  const UINT dpi = GetDpiForWindow(hwnd);
  HICON big_icon =
      LoadIconSized(it->second, GetSystemMetricsForDpi(SM_CXICON, dpi));
  // (`small` is a macro in the Windows headers.)
  HICON small_icon =
      LoadIconSized(it->second, GetSystemMetricsForDpi(SM_CXSMICON, dpi));
  if (big_icon == nullptr || small_icon == nullptr) {
    if (big_icon) DestroyIcon(big_icon);
    if (small_icon) DestroyIcon(small_icon);
    return;
  }
  SendMessage(hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(big_icon));
  SendMessage(hwnd, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(small_icon));
  // The window no longer uses the previous icons.
  if (big_icon_) DestroyIcon(big_icon_);
  if (small_icon_) DestroyIcon(small_icon_);
  big_icon_ = big_icon;
  small_icon_ = small_icon;
}

void FlutterWindow::OnDestroy() {
  icon_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
