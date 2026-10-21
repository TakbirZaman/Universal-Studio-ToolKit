#include "saved_documents.h"
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <algorithm>
#include <cwctype>
#include <filesystem>
#include <exception>
#include <string>
#include <variant>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
bool SavedPath(const Value* arguments, std::wstring& out,
               std::wstring& extension) {
  const auto* map = arguments ? std::get_if<Map>(arguments) : nullptr;
  if (!map) return false;
  auto item = map->find(Value("location"));
  if (item == map->end()) return false;
  const auto* text = std::get_if<std::string>(&item->second);
  if (!text || text->empty() || text->size() > 131072 ||
      text->find('\0') != std::string::npos) return false;
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      text->data(), static_cast<int>(text->size()), nullptr, 0);
  if (count < 1 || count > 32768) return false;
  out.resize(count);
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
      static_cast<int>(text->size()), out.data(), count) != count) return false;
  std::filesystem::path path(out);
  std::error_code error;
  if (!path.is_absolute() || std::filesystem::is_symlink(path, error) || error ||
      !std::filesystem::is_regular_file(path, error) || error) return false;
  extension = path.extension().wstring();
  std::transform(extension.begin(), extension.end(), extension.begin(),
      [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return extension == L".jpg" || extension == L".jpeg" || extension == L".png" ||
      extension == L".pdf" || extension == L".zip" || extension == L".txt" ||
      extension == L".json";
}
bool HasViewer(const std::wstring& extension) {
  DWORD count = 0;
  const HRESULT status = AssocQueryStringW(ASSOCF_NONE, ASSOCSTR_EXECUTABLE,
      extension.c_str(), L"open", nullptr, &count);
  return status == S_FALSE && count > 1;
}
}

std::unique_ptr<flutter::MethodChannel<Value>> CreateSavedDocumentsChannel(
    flutter::BinaryMessenger* messenger, HWND window) {
  auto channel = std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "dev.universalstudio/saved",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([window](const flutter::MethodCall<Value>& call,
      std::unique_ptr<flutter::MethodResult<Value>> result) {
    try {
      std::wstring path, extension;
      const bool valid = SavedPath(call.arguments(), path, extension);
      if (call.method_name() == "capabilities") {
        result->Success(Value(Map{{Value("open"), Value(valid && HasViewer(extension))},
            {Value("share"), Value(false)}, {Value("reveal"), Value(valid)}}));
        return;
      }
      if (!valid) { result->Error("invalid", "The saved copy is no longer available."); return; }
      if (call.method_name() == "open") {
        if (!HasViewer(extension) || reinterpret_cast<INT_PTR>(ShellExecuteW(
            window, L"open", path.c_str(), nullptr, nullptr, SW_SHOWNORMAL)) <= 32) {
          result->Error("open_failed", "No viewer could open the saved copy.");
        } else { result->Success(); }
      } else if (call.method_name() == "reveal") {
        PIDLIST_ABSOLUTE item = nullptr;
        HRESULT status = SHParseDisplayName(path.c_str(), nullptr, &item, 0, nullptr);
        if (SUCCEEDED(status)) status = SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
        if (item) CoTaskMemFree(item);
        if (FAILED(status)) result->Error("reveal_failed", "Could not show the saved location.");
        else result->Success();
      } else { result->NotImplemented(); }
    } catch (const std::exception&) {
      result->Error("unavailable", "The saved document action is unavailable.");
    }
  });
  return channel;
}
