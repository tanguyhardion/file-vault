import 'package:material_ui/material_ui.dart';

import '../services/cloud/cloud_auth.dart';
import '../services/offline/vault_repository.dart';
import 'mobile_app_state.dart';
import 'screens/mobile_home_screen.dart';

/// Entry point of the Android UI.
class MobileRoot extends StatefulWidget {
  final CloudAuth auth;
  final VaultRepository repository;

  const MobileRoot({super.key, required this.auth, required this.repository});

  @override
  State<MobileRoot> createState() => _MobileRootState();
}

class _MobileRootState extends State<MobileRoot> {
  late final MobileAppState _appState = MobileAppState(
    auth: widget.auth,
    repository: widget.repository,
  );

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
