import 'dart:async';

import 'package:file_vault/mobile/app_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:material_ui/material_ui.dart';

/// The phone's screen lock; each prompt completes when the test says so.
class FakeScreenLock extends LocalAuthPlatform {
  final prompts = <Completer<bool>>[];

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) {
    final prompt = Completer<bool>();
    prompts.add(prompt);
    return prompt.future;
  }
}

void main() {
  late FakeScreenLock lock;

  setUp(() => LocalAuthPlatform.instance = lock = FakeScreenLock());

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => AppLockGate(child: child!),
      home: const Scaffold(body: Text('vaults')),
    ),
  );

  testWidgets('asks for the screen lock before showing the app', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pump();
    expect(find.text('File Vault is locked'), findsOneWidget);
    expect(find.text('vaults'), findsNothing);
    expect(lock.prompts, hasLength(1));

    lock.prompts.single.complete(true);
    await tester.pump();
    expect(find.text('File Vault is locked'), findsNothing);
    expect(find.text('vaults'), findsOneWidget);
  });

  testWidgets('stays locked when the prompt is dismissed', (tester) async {
    await pumpApp(tester);
    await tester.pump();
    lock.prompts.single.complete(false);
    await tester.pump();
    expect(find.text('vaults'), findsNothing);
    expect(find.text('Screen lock not verified.'), findsOneWidget);

    await tester.tap(find.text('Unlock'));
    await tester.pump();
    expect(lock.prompts, hasLength(2));
    lock.prompts.last.complete(true);
    await tester.pump();
    expect(find.text('vaults'), findsOneWidget);
  });

  testWidgets('a quick app switch does not lock again', (tester) async {
    await pumpApp(tester);
    await tester.pump();
    lock.prompts.single.complete(true);
    await tester.pump();

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('vaults'), findsOneWidget);
    expect(lock.prompts, hasLength(1));
  });
}
