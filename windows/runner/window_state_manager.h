#ifndef RUNNER_WINDOW_STATE_MANAGER_H_
#define RUNNER_WINDOW_STATE_MANAGER_H_

#include <windows.h>
#include <string>

struct WindowState {
  int x = CW_USEDEFAULT;
  int y = CW_USEDEFAULT;
  int width = 1280;
  int height = 720;
  bool is_maximized = false;
  bool is_first_launch = true;
};

class WindowStateManager {
 public:
  WindowStateManager();
  ~WindowStateManager();

  // Load window state from registry
  WindowState LoadWindowState();

  // Save window state to registry
  void SaveWindowState(const WindowState& state);

  // Get current window state from HWND
  WindowState GetCurrentWindowState(HWND hwnd);

 private:
  static const std::wstring kRegistryKey;
  static const std::wstring kXValueName;
  static const std::wstring kYValueName;
  static const std::wstring kWidthValueName;
  static const std::wstring kHeightValueName;
  static const std::wstring kMaximizedValueName;
  static const std::wstring kFirstLaunchValueName;

  // Helper methods for registry operations
  DWORD ReadDWORDFromRegistry(const std::wstring& value_name, DWORD default_value);
  void WriteDWORDToRegistry(const std::wstring& value_name, DWORD value);
};

#endif  // RUNNER_WINDOW_STATE_MANAGER_H_
