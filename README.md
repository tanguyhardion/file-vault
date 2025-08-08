# File Vault

A secure and modern Flutter application for managing and encrypting files on Windows.

## Features
- Secure file storage and encryption
- User-friendly interface
- Cross-platform ready (Windows, with potential for other platforms)
- Fast search and organization

## Getting Started

### Prerequisites
- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable)
- Windows 10/11

### Installation
1. Clone the repository:
   ```sh
   git clone https://github.com/tanguyhardion/file-vault.git
   cd file-vault
   ```
2. Fetch dependencies:
   ```sh
   flutter pub get
   ```
3. Build the Windows app:
   ```sh
   flutter build windows
   ```
4. Run the app:
   ```sh
   flutter run -d windows
   ```

## Project Structure
```
lib/
  main.dart                # App entry point
  models/                  # Data models
  services/                # Business logic & encryption
  widgets/                 # UI components
windows/                   # Windows-specific build files
build/                     # Generated build assets
```

## Development
- To clean the build: `flutter clean`
- To update dependencies: `flutter pub get`
- To run tests: `flutter test`

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
This project is licensed under the MIT License.

---

For more information, see the [Flutter documentation](https://docs.flutter.dev/).
