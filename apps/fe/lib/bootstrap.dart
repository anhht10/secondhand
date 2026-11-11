import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

/// Initializes platform bindings, local preferences, and mounts [ProviderScope].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences? sharedPreferences;
  try {
    sharedPreferences = await SharedPreferences.getInstance();
  } catch (_) {
    // Continue gracefully if SharedPreferences is unavailable in test environment
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        if (sharedPreferences != null)
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        splashMinDurationProvider.overrideWithValue(
          const Duration(milliseconds: 1800),
        ),
      ],
      child: const ReMarketApp(),
    ),
  );
}
