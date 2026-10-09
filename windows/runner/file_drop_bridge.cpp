#include "file_drop_bridge.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <cstdio>
#include <iterator>
#include <string>
#include <vector>

#include "utils.h"

namespace {

constexpr char kFileDropChannelName[] = "field_notes/file_drop";
constexpr char kHoverMethod[] = "hover";
constexpr char kLeaveMethod[] = "leave";
constexpr char kDropMethod[] = "drop";

FORMATETC FileDropFormat() {
  return FORMATETC{static_cast<CLIPFORMAT>(CF_HDROP), nullptr,
                   DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
}

bool OffersFiles(IDataObject* data) {
  FORMATETC format = FileDropFormat();
  return data != nullptr && data->QueryGetData(&format) == S_OK;
}

flutter::EncodableList DroppedPaths(IDataObject* data) {
  flutter::EncodableList paths;
  FORMATETC format = FileDropFormat();
  STGMEDIUM medium{};
  if (data == nullptr || data->GetData(&format, &medium) != S_OK) {
    return paths;
  }
  for (const std::string& path :
       PathsFromDrop(static_cast<HDROP>(medium.hGlobal))) {
    paths.push_back(flutter::EncodableValue(path));
  }
  ::ReleaseStgMedium(&medium);
  return paths;
}

}

FileDropBridge::FileDropBridge(flutter::BinaryMessenger* messenger, HWND view)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger,
              kFileDropChannelName,
              &flutter::StandardMethodCodec::GetInstance())),
      view_(view) {}

FileDropBridge::~FileDropBridge() = default;

void FileDropBridge::Register() {
  const HRESULT result = ::RegisterDragDrop(view_, this);
  if (FAILED(result)) {
    wchar_t message[96];
    swprintf_s(message, std::size(message),
               L"Field Notes could not accept file drops (0x%08lX).\n",
               static_cast<unsigned long>(result));
    OutputDebugStringW(message);
    return;
  }
  registered_ = true;
}

void FileDropBridge::Revoke() {
  if (!registered_) {
    return;
  }
  registered_ = false;
  if (FAILED(::RevokeDragDrop(view_))) {
    OutputDebugStringW(L"Field Notes could not stop accepting file drops.\n");
  }
}

HRESULT FileDropBridge::QueryInterface(REFIID riid, void** object) {
  if (object == nullptr) {
    return E_POINTER;
  }
  if (IsEqualIID(riid, __uuidof(IUnknown)) ||
      IsEqualIID(riid, __uuidof(IDropTarget))) {
    *object = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }
  *object = nullptr;
  return E_NOINTERFACE;
}

ULONG FileDropBridge::AddRef() {
  return static_cast<ULONG>(::InterlockedIncrement(&references_));
}

ULONG FileDropBridge::Release() {
  const LONG remaining = ::InterlockedDecrement(&references_);
  if (remaining == 0) {
    delete this;
  }
  return static_cast<ULONG>(remaining);
}

HRESULT FileDropBridge::DragEnter(IDataObject* data,
                                  DWORD key_state,
                                  POINTL point,
                                  DWORD* effect) {
  if (effect == nullptr) {
    return E_INVALIDARG;
  }
  holds_files_ = OffersFiles(data);
  Hover(point, effect);
  return S_OK;
}

HRESULT FileDropBridge::DragOver(DWORD key_state,
                                 POINTL point,
                                 DWORD* effect) {
  if (effect == nullptr) {
    return E_INVALIDARG;
  }
  Hover(point, effect);
  return S_OK;
}

HRESULT FileDropBridge::DragLeave() {
  holds_files_ = false;
  channel_->InvokeMethod(kLeaveMethod, nullptr);
  return S_OK;
}

HRESULT FileDropBridge::Drop(IDataObject* data,
                             DWORD key_state,
                             POINTL point,
                             DWORD* effect) {
  if (effect == nullptr) {
    return E_INVALIDARG;
  }
  holds_files_ = false;
  const flutter::EncodableList paths = DroppedPaths(data);
  flutter::EncodableMap arguments = PositionOf(point);
  arguments.emplace(flutter::EncodableValue("paths"),
                    flutter::EncodableValue(paths));
  channel_->InvokeMethod(
      kDropMethod, std::make_unique<flutter::EncodableValue>(arguments));
  *effect = paths.empty() ? DROPEFFECT_NONE : DROPEFFECT_COPY;
  return S_OK;
}

flutter::EncodableMap FileDropBridge::PositionOf(POINTL point) const {
  POINT client{point.x, point.y};
  if (!::ScreenToClient(view_, &client)) {
    OutputDebugStringW(L"Field Notes could not place a file drop.\n");
  }
  const UINT dpi = ::GetDpiForWindow(view_);
  const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
  return flutter::EncodableMap{
      {flutter::EncodableValue("x"), flutter::EncodableValue(client.x / scale)},
      {flutter::EncodableValue("y"), flutter::EncodableValue(client.y / scale)},
  };
}

void FileDropBridge::Hover(POINTL point, DWORD* effect) {
  if (!holds_files_) {
    *effect = DROPEFFECT_NONE;
    return;
  }
  *effect = DROPEFFECT_COPY;
  channel_->InvokeMethod(
      kHoverMethod,
      std::make_unique<flutter::EncodableValue>(PositionOf(point)));
}
