# Bind video capture when the camera opens

Status: accepted

The Android camera plugin added video capture to the running camera session when recording began, which rebuilt the session and left a visible wait on every take, right after the person had taken a breath to speak. Field Notes binds preview, still capture and video capture together when the camera opens, so starting a take only starts the recording. The plugin has no public way to do this, so camera_android_camerax 0.7.5 is vendored with that one change, as the Mac and Windows camera plugins already are; subclassing it would have reached into test-only fields and broken silently on an update. The cost is an idle encoder while the recorder is open and a plugin that no longer updates itself.
