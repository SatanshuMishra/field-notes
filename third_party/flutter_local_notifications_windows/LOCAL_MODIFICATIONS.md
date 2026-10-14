# flutter_local_notifications_windows — local modifications

This is a vendored copy of `flutter_local_notifications_windows` (pub name
`flutter_local_notifications_windows`, version `3.1.1`), sourced from the published
archive at https://pub.dev/packages/flutter_local_notifications_windows. It holds
`CHANGELOG.md`, `LICENSE`, `README.md`, `ffigen.yaml`, `pubspec.yaml`, `lib/`, `src/` and
`windows/CMakeLists.txt` from that archive; `build.bat`, `dart_test.yaml` and `test/` are
left out. Field Notes selects it through `dependency_overrides` in the app's
`pubspec.yaml`, while `flutter_local_notifications` stays a hosted dependency.

Field Notes carries local fixes on top of the published sources. Upstream 3.1.1 lets a
WinRT failure in cancel, schedule or the lookups throw a C++ exception out of an
`extern "C"` function, which aborts the app on Windows (BEX64 in `ucrtbase.dll`, code
0xc0000409) each time reminders re-sync. A future re-vendor (bumping the upstream version
or re-downloading it) MUST re-apply the deltas below, or that abort returns. Verify each
item is still present after any upstream sync.

## Delta

1. Every exported entry point is guarded — `src/ffi_api.cpp`. The whole body of
   `hasPackageIdentity`, `isValidXml`, `createPlugin`, `disposePlugin`, `init`,
   `showNotification`, `scheduleNotification`, `updateNotification`, `cancelAll`,
   `cancelNotification`, `getActiveNotifications`, `getPendingNotifications`,
   `freeDetailsArray` and `freeLaunchDetails` sits in `try` with
   `catch (const winrt::hresult_error&)`, `catch (const std::exception&)` and
   `catch (...)`, each returning a failure value: `false` for the `bool` functions,
   `nullptr` for `createPlugin`, `nullptr` with `*size = 0` for the two lookups,
   `NativeUpdateResult::failed` for `updateNotification`, and a plain return for the
   `void` functions. `init` returns `false` for a null plugin, which is how a failed
   `createPlugin` reaches it. Upstream catches only the three XML loads.

2. Registration is guarded — `src/plugin.cpp`. `NativePlugin::registerApp` catches what
   `UpdateRegistry` and `RegisterCallback` throw through `winrt::check_win32` and
   `winrt::check_hresult` and returns `false`, so `init` reports the failure.

3. Cancel reports which step failed — `src/ffi_api.h`, `src/ffi_api.cpp`. A new
   `NativeCancelResult { removed = 0, historyFailed = 1, lookupFailed = 2,
   removalFailed = 3 }` is the return type of `cancelNotification` and `cancelAll`,
   which upstream declares `void`. Each WinRT call is guarded on its own:
   - the Action Center removal (`History().Remove` for one id, `History().Clear` for
     all) failing gives `historyFailed` and does not stop the scheduled part;
   - `GetScheduledToastNotifications` failing returns `lookupFailed`;
   - a `RemoveFromSchedule` failing gives `removalFailed`, and `cancelAll` goes on
     removing the other scheduled toasts.

   The result is `removed` when nothing failed, `historyFailed` when only the Action
   Center removal failed, and `lookupFailed` or `removalFailed` when the scheduled part
   failed. A plugin that is not ready reports `lookupFailed`, where upstream returned
   silently. `cancelNotification` still removes only the first scheduled toast with the
   id's tag, as upstream does.

4. Lookups tell failure from an empty list — `src/ffi_api.cpp`. Both lookups build
   their array in a `std::unique_ptr` and release it only on success, so a tag that
   `std::stoi` cannot parse no longer leaks the array. `getActiveNotifications` returns
   an empty, non-null array for an app without package identity, as the header comment
   already promises, so `nullptr` now means only failure. Upstream returned `nullptr`
   for that case.

5. Bindings follow the header — `lib/src/ffi/bindings.dart`, maintained by hand.
   `cancelAll` and `cancelNotification` return `NativeCancelResult`, read from a native
   `UnsignedInt`, and the `NativeCancelResult` enum is added in ffigen's style.
   Regenerating with `dart run ffigen --config ffigen.yaml` from `src/ffi_api.h` must
   give the same shape.

6. Native failures become Dart exceptions — `lib/src/plugin/ffi.dart`.
   - `cancel` and `cancelAll` complete for `removed` and `historyFailed`, since only
     the Action Center copy of a shown toast is left behind then, and throw an
     `Exception` naming the call, the id and the failed step (`lookup` or `removal`)
     for `lookupFailed` and `removalFailed`.
   - `zonedSchedule` and `zonedScheduleRawXml` throw an `Exception` when
     `scheduleNotification` returns `false`; upstream ignored the result.
   - `getActiveNotifications` and `pendingNotificationRequests` throw an `Exception`
     when the native lookup returns `nullptr`.
   - `show` throws as upstream does, and `initialize` returns the native `init` result
     as upstream does.

7. Tests can build the plugin without the DLL — `lib/src/plugin/ffi.dart`,
   `lib/flutter_local_notifications_windows.dart`.
   - The native library opens lazily, on the first call that needs the bindings,
     instead of when the plugin object is built.
   - `FlutterLocalNotificationsWindows.withBindings(NotificationsPluginBindings)`
     builds the plugin over the given bindings, and `lib/src/plugin/ffi.dart` exports
     `NotificationsPluginBindings`, so a host test can pass fakes made with
     `NotificationsPluginBindings.fromLookup` and `Pointer.fromFunction`.
   - The library's conditional export picks `src/plugin/ffi.dart` by default and
     `src/plugin/stub.dart` only `if (dart.library.js_interop)`, the web. Upstream picks
     the stub by default and `ffi.dart` `if (dart.library.ffi)`; the analyzer resolves
     the default, which hid the FFI class from analysis. Every platform compiles the
     same file as before: `ffi.dart` on Windows, macOS and Android, the stub on the web.

`CHANGELOG.md`, `README.md`, `LICENSE`, `ffigen.yaml`, `pubspec.yaml`, `src/plugin.hpp`,
`src/utils.cpp`, `src/utils.hpp`, both `CMakeLists.txt` files and the other files under
`lib/` are as published. `test/third_party/flutter_local_notifications_windows_test.dart`
in the app checks the override and the Dart side over fake native functions; the native
changes compile only on Windows and are checked there.
