import 'package:flutter/material.dart';

import 'mobile_app_state.dart';
import 'screens/mobile_home_screen.dart';

/// Entry point of the Android UI.
class MobileRoot extends StatefulWidget {
  const MobileRoot({super.key});

  @override
  State<MobileRoot> createState() => _MobileRootState();
}

class _MobileRootState extends State<MobileRoot> {
  final MobileAppState _appState = MobileAppState();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Any touch counts as activity for the inactivity lock.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _appState.userActivity(),
      child: MobileHomeScreen(appState: _appState),
    );
  }
}
