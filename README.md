# File Vault

File Vault does not store your data. Everything is kept locally on your device and is safely encrypted.

A simple Flutter app for securely managing and encrypting files on Windows. All files stay on your computer and are never uploaded anywhere.

## Features

- Local file storage and strong encryption
- Simple, user-friendly interface
- Fast search and organization
- Windows support (other platforms planned)

## Getting Started

1. Install [Flutter](https://flutter.dev/docs/get-started/install) (latest stable)
2. Clone this repo and enter the folder:
   ```sh
   git clone https://github.com/tanguyhardion/file-vault.git
   cd file-vault
   ```
3. Get dependencies:
   ```sh
   flutter pub get
   ```
4. Build and run for Windows:
   ```sh
   flutter run -d windows
   ```

## Project Structure

```
lib/           # App code
windows/       # Windows build files
build/         # Generated assets
```

## Development

- Clean build: `flutter clean`
- Update dependencies: `flutter pub get`
- Run tests: `flutter test`

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

## License

MIT License

---

For more info, see the [Flutter documentation](https://docs.flutter.dev/).
