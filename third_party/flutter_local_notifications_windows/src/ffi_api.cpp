#include <windows.h>  // <-- This must be the first Windows header
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Data.Xml.Dom.h>

#include <memory>

#include "ffi_api.h"
#include "plugin.hpp"
#include "utils.hpp"

using winrt::Windows::Data::Xml::Dom::XmlDocument;
using winrt::Windows::Foundation::Collections::IVectorView;

bool hasPackageIdentity() {
  try {
    if (!IsWindows8OrGreater()) return false;
    uint32_t length = 0;
    int error = GetCurrentPackageFullName(&length, nullptr);
    return error != APPMODEL_ERROR_NO_PACKAGE;
  } catch (const winrt::hresult_error&) {
    return false;
  } catch (const std::exception&) {
    return false;
  } catch (...) {
    return false;
  }
}

NativePlugin* createPlugin() {
  try {
    return new NativePlugin();
  } catch (const winrt::hresult_error&) {
    return nullptr;
  } catch (const std::exception&) {
    return nullptr;
  } catch (...) {
    return nullptr;
  }
}

void disposePlugin(NativePlugin* plugin) {
  try {
    delete plugin;
  } catch (const winrt::hresult_error&) {
    return;
  } catch (const std::exception&) {
    return;
  } catch (...) {
    return;
  }
}

bool init(
  NativePlugin* plugin, char* appName, char* aumId, char* guid, char* iconPath,
  NativeNotificationCallback callback
) {
  try {
    if (plugin == nullptr) return false;
    string icon;
    if (iconPath != nullptr) icon = string(iconPath);
    const auto didRegister = plugin->registerApp(aumId, appName, guid, icon, callback);
    if (!didRegister) return false;
    plugin->hasIdentity = hasPackageIdentity();
    plugin->aumid = winrt::to_hstring(aumId);
    plugin->notifier = plugin->hasIdentity
      ? ToastNotificationManager::CreateToastNotifier()
      : ToastNotificationManager::CreateToastNotifier(plugin->aumid);
    plugin->history = ToastNotificationManager::History();
    plugin->isReady = true;
    return true;
  } catch (const winrt::hresult_error&) {
    return false;
  } catch (const std::exception&) {
    return false;
  } catch (...) {
    return false;
  }
}

bool isValidXml(char* xml) {
  try {
    XmlDocument doc = XmlDocument();
    try {
      doc.LoadXml(winrt::to_hstring(xml));
      return true;
    } catch (winrt::hresult_error error) {
      return false;
    }
  } catch (const winrt::hresult_error&) {
    return false;
  } catch (const std::exception&) {
    return false;
  } catch (...) {
    return false;
  }
}

bool showNotification(NativePlugin* plugin, int id, char* xml, NativeStringMap bindings) {
  try {
    if (!plugin->isReady) return false;
    XmlDocument doc;
    try {
      doc.LoadXml(winrt::to_hstring(xml));
    } catch (winrt::hresult_error error) {
      return false;
    }
    ToastNotification notification(doc);
    const auto data = dataFromMap(bindings);
    notification.Tag(winrt::to_hstring(id));
    notification.Data(data);
    plugin->notifier.value().Show(notification);
    return true;
  } catch (const winrt::hresult_error&) {
    return false;
  } catch (const std::exception&) {
    return false;
  } catch (...) {
    return false;
  }
}

bool scheduleNotification(NativePlugin* plugin, int id, char* xml, int time) {
  try {
    if (!plugin->isReady) return false;
    XmlDocument doc;
    try {
      doc.LoadXml(winrt::to_hstring(xml));
    } catch (winrt::hresult_error error) {
      return false;
    }
    ScheduledToastNotification notification(doc, winrt::clock::from_time_t(time));
    notification.Tag(winrt::to_hstring(id));
    plugin->notifier.value().AddToSchedule(notification);
    return true;
  } catch (const winrt::hresult_error&) {
    return false;
  } catch (const std::exception&) {
    return false;
  } catch (...) {
    return false;
  }
}

NativeUpdateResult updateNotification(NativePlugin* plugin, int id, NativeStringMap bindings) {
  try {
    if (!plugin->isReady) return NativeUpdateResult::failed;
    const auto tag = winrt::to_hstring(id);
    const auto data = dataFromMap(bindings);
    const auto result = plugin->notifier.value().Update(data, tag);
    return (NativeUpdateResult) result;
  } catch (const winrt::hresult_error&) {
    return NativeUpdateResult::failed;
  } catch (const std::exception&) {
    return NativeUpdateResult::failed;
  } catch (...) {
    return NativeUpdateResult::failed;
  }
}

NativeCancelResult cancelAll(NativePlugin* plugin) {
  try {
    if (!plugin->isReady) return NativeCancelResult::lookupFailed;
    auto result = NativeCancelResult::removed;
    try {
      if (plugin->hasIdentity) {
        plugin->history.value().Clear();
      } else {
        plugin->history.value().Clear(plugin->aumid);
      }
    } catch (...) {
      result = NativeCancelResult::historyFailed;
    }
    IVectorView<ScheduledToastNotification> scheduled {nullptr};
    try {
      scheduled = plugin->notifier.value().GetScheduledToastNotifications();
    } catch (...) {
      return NativeCancelResult::lookupFailed;
    }
    for (const auto notification : scheduled) {
      try {
        plugin->notifier.value().RemoveFromSchedule(notification);
      } catch (...) {
        result = NativeCancelResult::removalFailed;
      }
    }
    return result;
  } catch (const winrt::hresult_error&) {
    return NativeCancelResult::lookupFailed;
  } catch (const std::exception&) {
    return NativeCancelResult::lookupFailed;
  } catch (...) {
    return NativeCancelResult::lookupFailed;
  }
}

NativeCancelResult cancelNotification(NativePlugin* plugin, int id) {
  try {
    if (!plugin->isReady) return NativeCancelResult::lookupFailed;
    const auto tag = winrt::to_hstring(id);
    auto result = NativeCancelResult::removed;
    if (plugin->hasIdentity) {
      try {
        plugin->history.value().Remove(tag);
      } catch (...) {
        result = NativeCancelResult::historyFailed;
      }
    }
    IVectorView<ScheduledToastNotification> scheduled {nullptr};
    try {
      scheduled = plugin->notifier.value().GetScheduledToastNotifications();
    } catch (...) {
      return NativeCancelResult::lookupFailed;
    }
    for (const auto notification : scheduled) {
      if (notification.Tag() == tag) {
        try {
          plugin->notifier.value().RemoveFromSchedule(notification);
        } catch (...) {
          return NativeCancelResult::removalFailed;
        }
        return result;
      }
    }
    return result;
  } catch (const winrt::hresult_error&) {
    return NativeCancelResult::lookupFailed;
  } catch (const std::exception&) {
    return NativeCancelResult::lookupFailed;
  } catch (...) {
    return NativeCancelResult::lookupFailed;
  }
}

NativeNotificationDetails* getActiveNotifications(NativePlugin* plugin, int* size) {
  try {
    // TODO: Get more details here
    if (!plugin->isReady) {
      *size = 0;
      return nullptr;
    }
    if (!plugin->hasIdentity) {
      *size = 0;
      return new NativeNotificationDetails[0];
    }
    const auto active = plugin->history.value().GetHistory();
    const auto count = static_cast<int>(active.Size());
    auto result = std::make_unique<NativeNotificationDetails[]>(count);
    int index = 0;
    for (const auto notification : active) {
      const auto tag = notification.Tag();
      const auto tagStr = winrt::to_string(tag);
      const auto tagInt = std::stoi(tagStr);
      result[index++].id = tagInt;
    }
    *size = count;
    return result.release();
  } catch (const winrt::hresult_error&) {
    *size = 0;
    return nullptr;
  } catch (const std::exception&) {
    *size = 0;
    return nullptr;
  } catch (...) {
    *size = 0;
    return nullptr;
  }
}

NativeNotificationDetails* getPendingNotifications(NativePlugin* plugin, int* size) {
  try {
    // TODO: Get more details here
    if (!plugin->isReady) {
      *size = 0;
      return nullptr;
    }
    const auto pending = plugin->notifier.value().GetScheduledToastNotifications();
    const auto count = static_cast<int>(pending.Size());
    auto result = std::make_unique<NativeNotificationDetails[]>(count);
    int index = 0;
    for (const auto notification : pending) {
      const auto tag = notification.Tag();
      const auto tagStr = winrt::to_string(tag);
      const auto tagInt = std::stoi(tagStr);
      result[index++].id = tagInt;
    }
    *size = count;
    return result.release();
  } catch (const winrt::hresult_error&) {
    *size = 0;
    return nullptr;
  } catch (const std::exception&) {
    *size = 0;
    return nullptr;
  } catch (...) {
    *size = 0;
    return nullptr;
  }
}

void freeDetailsArray(NativeNotificationDetails* ptr) {
  try {
    delete[] ptr;
  } catch (const winrt::hresult_error&) {
    return;
  } catch (const std::exception&) {
    return;
  } catch (...) {
    return;
  }
}

void freeLaunchDetails(NativeLaunchDetails details) {
  try {
    if (details.payload != nullptr) delete[] details.payload;
    for (int index = 0; index < details.data.size; index++) {
      const auto pair = details.data.entries[index];
      delete pair.key;
      delete pair.value;
    }
    if (details.data.entries != nullptr) delete[] details.data.entries;
  } catch (const winrt::hresult_error&) {
    return;
  } catch (const std::exception&) {
    return;
  } catch (...) {
    return;
  }
}
