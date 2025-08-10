#include "window_state_manager.h"
#include <iostream>

const std::wstring WindowStateManager::kRegistryKey = L"SOFTWARE\\FileVault";
const std::wstring WindowStateManager::kXValueName = L"WindowX";
const std::wstring WindowStateManager::kYValueName = L"WindowY";
const std::wstring WindowStateManager::kWidthValueName = L"WindowWidth";
const std::wstring WindowStateManager::kHeightValueName = L"WindowHeight";
const std::wstring WindowStateManager::kMaximizedValueName = L"WindowMaximized";
const std::wstring WindowStateManager::kFirstLaunchValueName = L"FirstLaunch";

WindowStateManager::WindowStateManager() {}

WindowStateManager::~WindowStateManager() {}

WindowState WindowStateManager::LoadWindowState() {
  WindowState state;
  
  // Check if this is the first launch
  state.is_first_launch = ReadDWORDFromRegistry(kFirstLaunchValueName, 1) != 0;
  
  if (state.is_first_launch) {
    // First launch: start maximized
    state.is_maximized = true;
    // Mark as no longer first launch
    WriteDWORDToRegistry(kFirstLaunchValueName, 0);
  } else {
    // Load saved state
    state.x = static_cast<int>(ReadDWORDFromRegistry(kXValueName, 100));
    state.y = static_cast<int>(ReadDWORDFromRegistry(kYValueName, 100));
    state.width = static_cast<int>(ReadDWORDFromRegistry(kWidthValueName, 1280));
    state.height = static_cast<int>(ReadDWORDFromRegistry(kHeightValueName, 720));
    state.is_maximized = ReadDWORDFromRegistry(kMaximizedValueName, 0) != 0;
  }
  
  return state;
}

void WindowStateManager::SaveWindowState(const WindowState& state) {
  WriteDWORDToRegistry(kXValueName, static_cast<DWORD>(state.x));
  WriteDWORDToRegistry(kYValueName, static_cast<DWORD>(state.y));
  WriteDWORDToRegistry(kWidthValueName, static_cast<DWORD>(state.width));
  WriteDWORDToRegistry(kHeightValueName, static_cast<DWORD>(state.height));
  WriteDWORDToRegistry(kMaximizedValueName, state.is_maximized ? 1 : 0);
}

WindowState WindowStateManager::GetCurrentWindowState(HWND hwnd) {
  WindowState state;
  
  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(WINDOWPLACEMENT);
  
  if (GetWindowPlacement(hwnd, &placement)) {
    state.is_maximized = (placement.showCmd == SW_SHOWMAXIMIZED);
    
    // Use normal position even if maximized (for restore)
    RECT& rect = placement.rcNormalPosition;
    state.x = rect.left;
    state.y = rect.top;
    state.width = rect.right - rect.left;
    state.height = rect.bottom - rect.top;
  }
  
  return state;
}

DWORD WindowStateManager::ReadDWORDFromRegistry(const std::wstring& value_name, DWORD default_value) {
  HKEY key;
  DWORD value = default_value;
  DWORD value_size = sizeof(value);
  
  LSTATUS result = RegOpenKeyEx(HKEY_CURRENT_USER, kRegistryKey.c_str(), 0, KEY_READ, &key);
  if (result == ERROR_SUCCESS) {
    RegQueryValueEx(key, value_name.c_str(), nullptr, nullptr, 
                    reinterpret_cast<LPBYTE>(&value), &value_size);
    RegCloseKey(key);
  }
  
  return value;
}

void WindowStateManager::WriteDWORDToRegistry(const std::wstring& value_name, DWORD value) {
  HKEY key;
  
  // Create the key if it doesn't exist
  LSTATUS result = RegCreateKeyEx(HKEY_CURRENT_USER, kRegistryKey.c_str(), 0, nullptr,
                                  REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &key, nullptr);
  
  if (result == ERROR_SUCCESS) {
    RegSetValueEx(key, value_name.c_str(), 0, REG_DWORD, 
                  reinterpret_cast<const BYTE*>(&value), sizeof(value));
    RegCloseKey(key);
  }
}
