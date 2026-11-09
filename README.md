# File Vault

A simple Flutter app for securely managing encrypted notes on Windows and Android. Vaults are stored in a database (Supabase) so the same vaults are available on every device you sign in on. Files are encrypted on the device before they are uploaded: the database only ever holds ciphertext.

## Features

- Vaults synced between Windows and Android through your account, with strong AES-GCM encryption (.fva format) and password-protected vaults
- Works offline: every vault stays available on the device, and changes made offline are synced when you're back online
- Accent colors: pick the app's color in Settings; the app icon follows it
- Fast search, file organization
- Encrypted ZIP backups (e.g. into your OneDrive folder), automatic on open/close if enabled
- Import an existing vault folder or a backup ZIP
- File operations: create, rename, delete, open, save
- Responsive, user-friendly interface (crypto runs in background isolates)
- Edit conflict detection: saving never silently overwrites a change made on another device

### Encryption & Security

File Vault is designed to keep your files safe and private. Here’s how it works:

- **AES-GCM 256-bit encryption**: Every file is encrypted using industry-standard AES-GCM with a 256-bit key.
- **Password-based key derivation**: Your password is never stored. Instead, a strong encryption key is derived using PBKDF2-HMAC-SHA256 (150,000 iterations, 16-byte salt).
- **Unique salt and nonce per file**: Each file uses a unique salt and nonce, making brute-force and rainbow table attacks useless.
- **Authenticated encryption**: Every file includes a 16-byte GCM tag (MAC) to ensure integrity and detect tampering.
- **On-device crypto**: All encryption and decryption happens on your device. Only encrypted `.fva` files and each vault's marker (salt + PBKDF2 password hash) are ever uploaded; the database never receives your vault password or decrypted content.
- **Offline copy**: For offline use, each device keeps the same encrypted files and markers in the app's private storage, as in a backup. Signing out deletes it.
- **Two separate passwords**: your account (email + password) only lets a device read and write your encrypted rows (enforced by row-level security). Each vault still has its own password, which never leaves the device.
- **Encrypted backups**: Backups are always encrypted. You can safely store them anywhere, including cloud folders (e.g., OneDrive, iCloud).
- **Zero knowledge**: The app never knows or stores your vault password or unencrypted data. As with any cloud copy, someone with access to the database could try to guess a vault password offline against its hash, so use a strong one.

If you lose your password, your files cannot be recovered—no backdoors, no tricks. Your secrets stay yours.

## Database setup

The app is preconfigured for its own Supabase project, so this is only needed to use your own database.

1. Create a project at [supabase.com](https://supabase.com).
2. Apply the schema in `supabase/migrations/` (SQL editor, or `supabase db push`). It creates the `vaults` and `vault_files` tables with row-level security.
3. In **Authentication → Providers**, keep **Email** enabled. Turn off "Confirm email" if you don't want to confirm your address before the first sign-in.
4. Build with `--dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_KEY=<publishable-key>` (from **Project Settings → API**). The publishable key is meant to ship in apps; row-level security restricts every account to its own rows.

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

On first launch, create an account (or sign in), then create a vault, or import an existing vault folder (the one containing `.vault_marker`) or a backup ZIP with **Import** (Ctrl+I). Imported vaults keep their password.

### Backups

**Backup** (Ctrl+B) downloads the vault's encrypted files and writes them, with the vault marker, as a ZIP to the folder you choose, for example your OneDrive folder. With **auto backup** on, the ZIP in that folder is replaced each time the vault is opened or closed on this PC. A backup ZIP can be imported again.

## Android app

The Android app shows the vaults of the account you sign in with. It decrypts files in memory and uploads only re-encrypted bytes. Decrypted text is never written to disk, and screenshots and the recent-apps preview are blocked.

### Build and install

```sh
flutter build apk --release
```

Copy `build/app/outputs/flutter-apk/app-release.apk` to your phone and open it (allow installing from unknown sources), or with the phone connected over USB run `flutter install`.

Opening the app requires the phone's screen lock (fingerprint, face, PIN, pattern or password), and so does coming back to it after more than 30 seconds in the background. Every vault password attempt also requires the screen lock *before* the password is checked, so passwords can't be guessed on the phone without it. The app can't be used on a phone with no screen lock.

The home screen icon follows the accent color chosen in Settings. It changes when you leave the app; some launchers move or remove home screen shortcuts when it does.

### Editing on several devices

- Every file is checked against the database when opened (and only downloaded if it changed).
- Each file has a version number that the database bumps on every change. Saving checks that the file wasn't changed on another device since you opened it. If it was, you choose **Reload** or **Overwrite**.
- Pending edits are saved when the app goes to the background or auto-locks.

### Offline

- Every vault is kept on each device and refreshed in the background, so vaults open, and files can be read, created, edited, renamed and deleted without a connection. Creating, importing or deleting a vault still needs one.
- Changes made offline are sent as soon as the server can be reached again. The cloud button in the toolbar shows the state (offline, changes waiting, synced); click it to sync now.
- If a file was changed both offline here and on another device, the other device's version is kept and yours is added next to it as `<name> (conflict <date>)`, so no edit is lost. An edit made here beats a delete made elsewhere, and the other way round.
- Signing out first tries to sync; if changes still can't be sent, you're asked before they're discarded.

## Project Structure

```
lib/           # App code (desktop UI, shared services)
lib/services/cloud/  # Supabase auth, REST client, vault storage
lib/services/offline/  # Offline copy of the vaults and syncing
lib/theme/     # Material 3 Expressive theme and accent colors
lib/mobile/    # Android UI
supabase/      # Database schema (migrations)
tool/          # App icon generator
android/       # Android build files
windows/       # Windows build files
build/         # Generated assets
```

## Development

- Clean build: `flutter clean`
- Update dependencies: `flutter pub get`
- Run tests: `flutter test`
- Regenerate the app icons (one per accent color, Android and Windows) from `assets/icon.png`: `dart run tool/generate_icons.dart`

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

## License

MIT License
