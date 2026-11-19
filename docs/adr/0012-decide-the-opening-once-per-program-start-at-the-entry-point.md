# Decide the opening once per program start at the entry point

Status: accepted

Whether the opening plays is decided once, when the app's Dart program starts: the device entry point builds the app with a playsOpening flag that a keep-alive provider carries, and the plain app widget never plays it. A return from the background never restarts the program, so it cannot replay the opening, and the many tests that build the plain app widget see no opening without each opting out. Watching app lifecycle events, or storing when the app last opened, was rejected because both guess at a fresh start that the entry point already knows, and both would replay the opening after a long pause in the background.
