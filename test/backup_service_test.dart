import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:file_vault/services/backup_service.dart';

void main() {
  group('BackupPathsService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generateBackupFileName creates correct format', () {
      final result = BackupPathsService.generateBackupFileName(
        'test-vault',
        tempDir.path,
      );
      final fileName = p.basename(result);

      // Should match pattern: test-vault_backup_YYYY-MM-DD.zip
      expect(fileName, matches(r'^test-vault_backup_\d{4}-\d{2}-\d{2}\.zip$'));
      expect(p.dirname(result), equals(tempDir.path));
    });

    test('findExistingBackupFiles finds correct files', () async {
      // Create some test backup files
      await File(
        p.join(tempDir.path, 'test-vault_backup_2024-01-01.zip'),
      ).writeAsString('test1');
      await File(
        p.join(tempDir.path, 'test-vault_backup_2024-01-02.zip'),
      ).writeAsString('test2');
      await File(
        p.join(tempDir.path, 'other-vault_backup_2024-01-01.zip'),
      ).writeAsString('test3');
      await File(
        p.join(tempDir.path, 'test-vault_not_backup.zip'),
      ).writeAsString('test4');
      await File(
        p.join(tempDir.path, 'test-vault_backup_invalid.zip'),
      ).writeAsString('test5');

      final result = await BackupPathsService.findExistingBackupFiles(
        'test-vault',
        tempDir.path,
      );

      expect(result.length, equals(2));
      expect(
        result.any(
          (path) => p.basename(path) == 'test-vault_backup_2024-01-01.zip',
        ),
        isTrue,
      );
      expect(
        result.any(
          (path) => p.basename(path) == 'test-vault_backup_2024-01-02.zip',
        ),
        isTrue,
      );
    });

    test(
      'findExistingBackupFiles returns empty list for non-existent directory',
      () async {
        final nonExistentDir = p.join(tempDir.path, 'non-existent');
        final result = await BackupPathsService.findExistingBackupFiles(
          'test-vault',
          nonExistentDir,
        );

        expect(result, isEmpty);
      },
    );

    test('deletePreviousBackups removes all matching files', () async {
      // Create test backup files
      final file1 = File(
        p.join(tempDir.path, 'test-vault_backup_2024-01-01.zip'),
      );
      final file2 = File(
        p.join(tempDir.path, 'test-vault_backup_2024-01-02.zip'),
      );
      final file3 = File(
        p.join(tempDir.path, 'other-vault_backup_2024-01-01.zip'),
      );

      await file1.writeAsString('test1');
      await file2.writeAsString('test2');
      await file3.writeAsString('test3');

      // Verify files exist
      expect(await file1.exists(), isTrue);
      expect(await file2.exists(), isTrue);
      expect(await file3.exists(), isTrue);

      // Delete backups for test-vault
      await BackupPathsService.deletePreviousBackups(
        'test-vault',
        tempDir.path,
      );

      // Verify only test-vault backups were deleted
      expect(await file1.exists(), isFalse);
      expect(await file2.exists(), isFalse);
      expect(await file3.exists(), isTrue); // Other vault backup should remain
    });

    test(
      'deletePreviousBackups handles non-existent directory gracefully',
      () async {
        final nonExistentDir = p.join(tempDir.path, 'non-existent');

        // Should not throw an exception
        await BackupPathsService.deletePreviousBackups(
          'test-vault',
          nonExistentDir,
        );
      },
    );
  });
}
