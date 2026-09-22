# Charter — Note Fix Wave

Binding on every Worker in the 2026-09-21 note fix wave. Read all of it before your first Step.

## The project

- The app is **field-notes**, a Flutter journaling app for macOS and Android, with iOS later. Never call
  it anything else, even though the directory on disk is named `fireplace`.
- State is Riverpod 3 with `riverpod_generator`; storage is drift. Generated `*.g.dart` files are
  committed.
- The authority for this wave is `docs/specs/2026-09-21-note-fix-wave.md`. The feature's authority is
  `docs/specs/2026-09-20-note-editor-and-scrapbook-photos.md`. Where they disagree, the fix-wave
  document wins. Nothing under `docs/specs/archive/` is binding; do not read it.

## Absolute rules

1. **No comments** in any code you write: no `//`, `///` or `/* */` explanations, no doc comments, no
   section headers. Tooling pragmas such as `// ignore: ...` are allowed only when a tool requires one.
   If an existing comment contradicts code you are changing, delete it.
2. **No emojis** anywhere.
3. **No new package dependency.** Do not edit `pubspec.yaml` or `pubspec.lock`.
4. **No schema change and no migration.** `schemaVersion` stays 1.
5. **Never edit anything under `test/features/entry_cards/playback/`.**
6. **Never run `flutter test integration_test/` as a directory**, and never run
   `integration_test/capture_save_persist_test.dart` at all: it writes into the real journal. A single
   named file under `integration_test/` may be run only when your Step says so.
7. **Never run the app** (`flutter run`). There is no display for you.
8. **Never connect to a network service or database.** Nothing in this wave needs one.

## Git and the shared tree

mitosis owns git. Other Workers may be editing other files in the same worktree.

- Edit **only** the files in your write-set. If you believe a file outside it must change, do not change
  it; say so in your return notes.
- Run no command that changes the index or history: no `git add`, `commit`, `stash`, `reset`,
  `checkout`, `restore`, `clean`, `merge`, `rebase`, `switch` or `push`. Read-only git (`git diff`,
  `git log`, `git show`, `git status`) is fine.
- To undo your own edit, edit the file back. Never restore a file through git.

## Environment

Run these once, in your worktree, before anything else:

```
export PATH="/opt/homebrew/bin:$PATH"
export LANG=en_US.UTF-8
flutter pub get --offline || flutter pub get
```

- If you change a `@riverpod` or `@Riverpod` provider's function, run
  `dart run build_runner build --delete-conflicting-outputs`. The regenerated `.g.dart` for that
  provider is in your write-set wherever that can happen. No other generated file should change; if one
  does, name it in your notes.
- There is no Android SDK on this machine.

## How to work each Step

1. Read every file in your write-set, the files it names, and their existing tests.
2. **Write or rewrite the acceptance tests first**, using the exact test names your Step gives. A test
   name is the string passed to `test(...)` or `testWidgets(...)`; it must match exactly, because the
   gate runs it with `flutter test <file> --plain-name "<name>"`.
3. Run them. They must **fail** against the unfixed code, for the reason the defect describes. A test
   that passes before your fix proves nothing; strengthen it until it fails. A compile failure counts
   only when your Step introduces a new symbol the test must use.
4. Implement the fix.
5. Run the acceptance tests again. They must pass.
6. Run `flutter analyze`. It must print `No issues found!`.
7. Run the full suite with `flutter test` (no path argument; this runs `test/` only). It must end with
   `All tests passed!`.

### Changing existing tests

- **Never delete a test. Never weaken an assertion.**
- The only existing tests whose assertions you may change are the ones your Step names as asserting a
  defect. Rewrite each to assert the behaviour your Step specifies.
- If the full suite shows another existing test failing because of your change, the behaviour change
  must be one your Step requires. Then retarget that test so it pins the same intent through the new
  behaviour, and say so in your notes. If your Step does not require the behaviour that broke it, your
  change is wrong; fix the change, not the test.

## Code style

- Match the surrounding code: explicit types on locals, `final` wherever possible, `const` constructors,
  trailing commas, the file's existing import style.
- Create new values rather than mutating existing ones.
- Keep names self-explanatory, since there are no comments to explain them.
- Keys that tests find widgets by are `const Key` values exported from the widget's file, as the
  codebase already does.

## Your return

End with the one-line JSON return your brief specifies, and nothing after it. In `notes`, state which
acceptance tests you watched fail and then pass, and whether `flutter analyze` and the full suite were
clean. If you could not make something pass, set `status` to `failed` and say what is left.
