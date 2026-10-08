#ifndef RUNNER_FILE_DROP_BRIDGE_H_
#define RUNNER_FILE_DROP_BRIDGE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <ole2.h>

#include <memory>

class FileDropBridge : public IDropTarget {
 public:
  FileDropBridge(flutter::BinaryMessenger* messenger, HWND view);

  FileDropBridge(const FileDropBridge&) = delete;
  FileDropBridge& operator=(const FileDropBridge&) = delete;

  void Register();

  void Revoke();

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                           void** object) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;

  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data,
                                      DWORD key_state,
                                      POINTL point,
                                      DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragOver(DWORD key_state,
                                     POINTL point,
                                     DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragLeave() override;
  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data,
                                 DWORD key_state,
                                 POINTL point,
                                 DWORD* effect) override;

 private:
  ~FileDropBridge();

  flutter::EncodableMap PositionOf(POINTL point) const;

  void Hover(POINTL point, DWORD* effect);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND view_;
  LONG references_ = 1;
  bool holds_files_ = false;
  bool registered_ = false;
};

#endif
