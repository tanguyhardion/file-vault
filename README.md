# File Vault

File Vault does not store your data. Everything is kept locally on your device and is safely encrypted.

A simple Flutter app for securely managing and encrypting files on Windows and Android. On Windows, vaults are local folders (which you can keep in a OneDrive-synced folder); the Android app opens the same vaults from a folder on the phone kept in sync with Syncthing. Files are only ever stored or uploaded in encrypted form.

## Features

- Secure local file storage: Everything stays on your device, with strong AES-GCM encryption (.fva format) and password-protected vaults
- Fast search, file organization, and recent vaults
- Encrypted backup and restore support
- File operations: create, rename, delete, open, save
- Responsive, user-friendly interface (crypto runs in background isolates)
- Windows and Android support (vaults synced between devices with Syncthing)
- Edit conflict detection: saving never silently overwrites a change made on another device

### Encryption & Security

File Vault is designed to keep your files safe and private. Here’s how it works:

- **AES-GCM 256-bit encryption**: Every file is encrypted using industry-standard AES-GCM with a 256-bit key.
- **Password-based key derivation**: Your password is never stored. Instead, a strong encryption key is derived using PBKDF2-HMAC-SHA256 (150,000 iterations, 16-byte salt).
- **Unique salt and nonce per file**: Each file uses a unique salt and nonce, making brute-force and rainbow table attacks useless.
- **Authenticated encryption**: Every file includes a 16-byte GCM tag (MAC) to ensure integrity and detect tampering.
- **On-device crypto**: All encryption and decryption happens on your device. Only encrypted `.fva` files and the `.vault_marker` (salt + password hash) are ever synced or uploaded; neither Syncthing nor OneDrive ever receives your password or decrypted content.
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

## Android app

The Android app opens a vault from a folder on the phone. It decrypts files in memory and writes back only re-encrypted bytes. Decrypted text is never written to disk, and screenshots and the recent-apps preview are blocked.

To get the same vaults on the PC and the phone, sync the vault folder with [Syncthing](https://syncthing.net/). Syncthing copies files directly between your devices, with no cloud account. The vault can stay in your OneDrive folder on the PC, so OneDrive still backs it up.

### Set up syncing (once)

1. Install Syncthing on Windows and the Syncthing app on the phone (Syncthing-Fork on Android).
2. Pair the two devices (scan the device ID QR code).
3. On the PC, share the vault folder (the one containing `.vault_marker`) with the phone, and accept it on the phone into a folder in the phone's storage, e.g. `/storage/emulated/0/Vaults/Personal`.

### Build and install

```sh
flutter build apk --release
```

Copy `build/app/outputs/flutter-apk/app-release.apk` to your phone and open it (allow installing from unknown sources), or with the phone connected over USB run `flutter install`.

In the app, tap **Add vault**, allow **All files access** when asked, browse to the synced vault folder, and enter the vault password.

Every vault password attempt also requires the phone's screen lock (fingerprint, face, PIN, pattern or password) *before* the password is checked, so passwords can't be guessed on the phone without it. Vaults can't be opened on a phone with no screen lock.

### Editing on several devices

- Every file is read fresh from the folder when opened.
- Saving checks that the file wasn't changed (e.g. synced from the PC) since you opened it. If it was, you choose **Reload** or **Overwrite**. The desktop app does the same check.
- Pending edits are saved when the app goes to the background or auto-locks.
- Changes travel only while both devices are online. If both edit the same file before syncing, Syncthing keeps the other version as a `*.sync-conflict-*.fva` file in the vault, so nothing is lost.

### Optional: open vaults directly from OneDrive

The app can also talk to OneDrive itself through Microsoft Graph, without Syncthing. This needs an app registration in [Microsoft Entra](https://entra.microsoft.com) (App registrations → New registration, any organizational directory + personal accounts, redirect URI type **Public client/native**, value `com.tanguyhardion.filevault://auth`, delegated Graph permissions `Files.ReadWrite` and `offline_access`). Then build with:

```sh
flutter build apk --release --dart-define=ONEDRIVE_CLIENT_ID=<application-id>
```

**Add vault** then offers **OneDrive** next to **Folder on this phone**. OneDrive sees file names, sizes and dates, never passwords or decrypted content.

## Project Structure

```
lib/           # App code
lib/mobile/    # Android UI, vault storage (local folder, optional OneDrive)
android/       # Android build files
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
