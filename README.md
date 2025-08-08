# File Vault
A simple Flutter desktop/web app showcasing a split-pane layout to browse a vault folder of `.fva` files on the left and view decrypted contents on the right. Decryption is stubbed and performed in-memory only.

## Key points

- Material 3 theming enabled (light/dark).
- Select a vault folder via the toolbar or the welcome screen.
- Lists only `.fva` files.
- Clicking a file "decrypts" it via `Future<String> decryptFile(File file)`, stores content only in memory, and displays it. Nothing is written to disk.
- Uses `file_picker`, `path`, and `dart:io`.

## Run (Windows desktop)

- Ensure Flutter is set up for Windows: `flutter config --enable-windows-desktop`
- Run: `flutter run -d windows`

## Notes

- Replace the `decryptFile` implementation in `lib/main.dart` with your real decryption.
- Keep decrypted data ephemeral; do not persist to disk.

Basic Flutter app scaffolded for desktop (Windows, Linux, macOS) and Web using Material 3.

## Run

- Windows: `flutter run -d windows`
- Linux: `flutter run -d linux`
- macOS: `flutter run -d macos`
- Web: `flutter run -d chrome`

If a platform device isn't listed, ensure it's enabled:

```
flutter config --enable-windows-desktop --enable-linux-desktop --enable-macos-desktop --enable-web
```

## Notes

- Material 3 is enabled via `ThemeData(useMaterial3: true)`.
- Replace the placeholder home screen with your app content.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
