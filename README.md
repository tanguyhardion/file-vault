# File Vault

File Vault does not store your data. Everything is kept locally on your device and is safely encrypted.

A simple Flutter app for securely managing and encrypting files on Windows. All files stay on your computer and are never uploaded anywhere.

## Features

- Secure local file storage: Everything stays on your device, with strong AES-GCM encryption (.fva format) and password-protected vaults
- Fast search, file organization, and recent vaults
- Encrypted backup and restore support
- File operations: create, rename, delete, open, save
- Responsive, user-friendly interface (crypto runs in background isolates)
- Windows support (other platforms planned)

### Encryption & Security

File Vault is designed to keep your files safe and private. Here’s how it works:

- **AES-GCM 256-bit encryption**: Every file is encrypted using industry-standard AES-GCM with a 256-bit key.
- **Password-based key derivation**: Your password is never stored. Instead, a strong encryption key is derived using PBKDF2-HMAC-SHA256 (150,000 iterations, 16-byte salt).
- **Unique salt and nonce per file**: Each file uses a unique salt and nonce, making brute-force and rainbow table attacks useless.
- **Authenticated encryption**: Every file includes a 16-byte GCM tag (MAC) to ensure integrity and detect tampering.
- **Local-only**: All encryption and decryption happens on your device. No data ever leaves your computer.
- **Encrypted backups**: Backups are always encrypted. You can safely store them anywhere, including cloud folders (e.g., OneDrive, iCloud).
- **Zero knowledge**: The app never knows or stores your password or unencrypted data.

If you lose your password, your files cannot be recovered—no backdoors, no tricks. Your secrets stay yours.

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
