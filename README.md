# Ren'Py Studio Mobile

A Flutter app for building [Ren'Py](https://www.renpy.org/) visual novel
projects entirely from a phone or tablet.

## Features

| Feature | Where | What it does |
|---|---|---|
| **File Explorer** | `lib/screens/file_explorer_screen.dart` | Browse/create/rename/delete files & folders inside a project's `game/` tree; opens `.rpy`/`.txt`/`.json` in a raw text editor. |
| **Dialogue Editor** | `lib/screens/dialogue_editor_screen.dart` | Block-based visual editor — Say, Narration, Scene/Show, Menu, Label, Jump, Comment blocks — reorderable, per-script-file tabs, with a live "View Raw" toggle showing compiled Ren'Py syntax. |
| **Character Manager** | `lib/screens/character_manager_screen.dart` | List/add/edit/delete a project's `Character` defines — display name, variable name, image tag, and text color (hex) — each change saved via `ProjectService.updateProject()`. |
| **AI Assistant** | `lib/screens/ai_assistant_screen.dart` | Chat interface backed by the Anthropic Messages API (BYO API key, stored locally) with the project's characters/scripts fed in as context. |
| **Image Importer** | `lib/screens/image_importer_screen.dart` | Pull images from gallery or camera, rename to Ren'Py tag convention, copy into `game/images/`. |
| **Export** | `lib/screens/export_screen.dart` | Materializes a launcher-ready Ren'Py folder (`game/script.rpy`, `options.rpy`, `screens.rpy`, `images/`, `audio/`, `gui/`) and zips it for sharing. |

## Project structure

```
lib/
  main.dart                     # app entry, Provider wiring
  theme/app_theme.dart          # dark IDE-style theme
  models/
    renpy_project.dart          # project metadata + JSON (de)serialization
    character.dart              # Character -> `define` statement
    dialogue_line.dart          # structured block -> Ren'Py line compiler
    script_file.dart            # one .rpy file: structured lines or raw override
  services/
    project_service.dart        # CRUD + on-disk folder skeleton + persistence
    file_explorer_service.dart  # dart:io wrapper for browsing/editing files
    renpy_export_service.dart   # materialize + zip a full Ren'Py project
    ai_service.dart             # Anthropic API client, chat history
    image_import_service.dart   # image_picker wrapper + tag-name guessing
  screens/                      # one file per tab/feature
  widgets/                      # dialogue block editor widgets
```

## Why a "compiler," not a raw text blob

Each `.rpy` file is stored as a list of typed `DialogueLine` blocks
(`say`, `narration`, `sceneShow`, `menuChoice`, `label`, `jump`, `comment`).
`ScriptFile.compile()` turns that structured list into syntactically valid
Ren'Py text with correct indentation. This lets the visual editor guarantee
valid output while still letting power users drop into a raw text editor
(`rawOverride` on `ScriptFile`, or editing the file directly via the File
Explorer) whenever they want full control.

## Setup

```bash
flutter pub get
flutter run          # device/emulator of your choice
```

### AI Assistant

The assistant calls `https://api.anthropic.com/v1/messages` directly using
a key you paste into Settings (the key icon in the AI tab). It's stored
locally via `shared_preferences` and never leaves the device except in
requests to Anthropic. Every other feature works fully offline without it.

### Permissions

- **Android**: camera, media/image read, storage (scoped for older SDKs),
  and a `FileProvider` for sharing exported `.zip` files — all declared in
  `android/app/src/main/AndroidManifest.xml`.
- **iOS**: camera + photo library usage strings in `ios/Runner/Info.plist`.

## Exporting a project

"Export" tab → **Sync project folder on device** writes/refreshes the
`game/` folder in place (useful if you're syncing the folder to a cloud
drive that the desktop Ren'Py launcher can also see). **Build .zip for
export** does the same and then zips the whole project folder, ready to
share via the OS share sheet — unzip it and open it with the Ren'Py
launcher's "Select Ren'Py Directory" on desktop.

## Known limitations / next steps

- The dialogue editor's `sceneShow` and raw `jump`/`label` blocks accept
  free text rather than validating against real image tags — cheap to add
  a picker once you want stricter guardrails.
- No live Ren'Py preview/renderer (Ren'Py itself doesn't run on mobile);
  export and test in the desktop launcher or Ren'Py's own Android build.
- `flutter pub get` requires network access, which this build environment
  doesn't have — dependencies are pinned in `pubspec.yaml` and this hasn't
  been run through `flutter analyze`/`flutter build` here. Recommend
  running both locally before your first release build.
