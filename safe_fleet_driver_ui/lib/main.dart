import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/background/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every Be Vietnam Pro face ships in assets/google_fonts. Turning off runtime
  // fetching keeps typography identical in a depot with no signal and removes a
  // network call from the launch path.
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeBackgroundSync();
  runApp(const ProviderScope(child: SafeFleetDriverApp()));
}
