import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_settings.dart';
import 'app_providers.dart';

final appModeProvider = Provider<AppMode>((ref) {
  final settingsAsync = ref.watch(settingsProvider);

  return settingsAsync.when(
    data: (settings) => settings.appMode,
    loading: () => AppMode.combined,
    error: (_, _) => AppMode.combined,
  );
});
