import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jagt_app/app/app.dart';
import 'package:jagt_app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('da');
  await initializeDateFormatting('da_DK');
  Intl.defaultLocale = 'da';

  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<ProviderContainer> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = bootstrapApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProviderContainer>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Kunne ikke forbinde til serveren',
                        style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _bootstrap = bootstrapApp();
                      }),
                      child: const Text('Proev igen'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 120),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Starter Jagt-App...'),
                  ],
                ),
              ),
            ),
          );
        }
        return UncontrolledProviderScope(
          container: snapshot.data!,
          child: const JagtApp(),
        );
      },
    );
  }
}
