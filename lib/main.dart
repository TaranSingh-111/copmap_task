import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'modules/auth/bindings/auth_binding.dart';
import 'modules/auth/views/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
  if (supabaseUrl == null || supabaseUrl.isEmpty ||
      supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Set SUPABASE_URL and SUPABASE_ANON_KEY in the local .env file.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const CopMapApp());
}

class CopMapApp extends StatelessWidget {
  const CopMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'CopMap',
      debugShowCheckedModeBanner: false,
      initialBinding: AuthBinding(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.brandColor),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
