# File Vault

A simple Flutter app for securely managing encrypted notes on Windows and Android. Vaults are stored in a database (Supabase) so the same vaults are available on every device you sign in on. Files are encrypted on the device before they are uploaded: the database only ever holds ciphertext.

## Features

- Vaults synced between Windows and Android through your account, with strong AES-GCM encryption (.fva format) and password-protected vaults
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
- **Two separate passwords**: your account (email + password) only lets a device read and write your encrypted rows (enforced by row-level security). Each vault still has its own password, which never leaves the device.
- **Encrypted backups**: Backups are always encrypted. You can safely store them anywhere, including cloud folders (e.g., OneDrive, iCloud).
- **Zero knowledge**: The app never knows or stores your vault password or unencrypted data. As with any cloud copy, someone with access to the database could try to guess a vault password offline against its hash, so use a strong one.

If you lose your password, your files cannot be recovered—no backdoors, no tricks. Your secrets stay yours.

## Database setup (once)

1. Create a project at [supabase.com](https://supabase.com).
2. Apply the schema in `supabase/migrations/` (SQL editor, or `supabase db push`). It creates the `vaults` and `vault_files` tables with row-level security.
3. In **Authentication → Providers**, keep **Email** enabled. Turn off "Confirm email" if you don't want to confirm your address before the first sign-in.
4. Note the project URL and the publishable (anon) key from **Project Settings → API**. The key is meant to ship in apps; row-level security restricts every account to its own rows.

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
   flutter run -d windows --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_KEY=<publishable-key>
   ```

On first launch, create an account (or sign in), then create a vault, or import an existing vault folder (the one containing `.vault_marker`) or a backup ZIP with **Import** (Ctrl+I). Imported vaults keep their password.

### Backups

**Backup** (Ctrl+B) downloads the vault's encrypted files and writes them, with the vault marker, as a ZIP to the folder you choose, for example your OneDrive folder. With **auto backup** on, the ZIP in that folder is replaced each time the vault is opened or closed on this PC. A backup ZIP can be imported again.

## Android app

The Android app shows the vaults of the account you sign in with. It decrypts files in memory and uploads only re-encrypted bytes. Decrypted text is never written to disk, and screenshots and the recent-apps preview are blocked.

### Build and install

```sh
flutter build apk --release --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_KEY=<publishable-key>
```

Copy `build/app/outputs/flutter-apk/app-release.apk` to your phone and open it (allow installing from unknown sources), or with the phone connected over USB run `flutter install`.

Every vault password attempt also requires the phone's screen lock (fingerprint, face, PIN, pattern or password) *before* the password is checked, so passwords can't be guessed on the phone without it. Vaults can't be opened on a phone with no screen lock.

### Editing on several devices

- Every file is read fresh from the database when opened.
- Each file has a version number that the database bumps on every change. Saving checks that the file wasn't changed on another device since you opened it. If it was, you choose **Reload** or **Overwrite**.
- Pending edits are saved when the app goes to the background or auto-locks.

## Project Structure

```
lib/           # App code (desktop UI, shared services)
lib/services/cloud/  # Supabase auth, REST client, vault storage
lib/mobile/    # Android UI
supabase/      # Database schema (migrations)
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
