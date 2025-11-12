import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/strayconnected.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

    // ⚠️ Hardcoded Supabase keys (use only for local dev)
  await Supabase.initialize(
    url: 'https://sgbignhkvycsvlkzqhwj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnYmlnbmhrdnljc3Zsa3pxaHdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5ODgxNTYsImV4cCI6MjA3NzU2NDE1Nn0.qB_3XbRG8WekutNmGPfyR0DNcp3D7rQbKVMAfnFxeY0',
  );

  runApp(const StrayConnectedApp());
}

final supabase = Supabase.instance.client;
