import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/app/router.dart';
import 'package:jagt_app/app/theme.dart';

class JagtApp extends ConsumerWidget {
  const JagtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Risinge Jagtvæsen',
      theme: JagtTheme.light,
      darkTheme: JagtTheme.dark,
      routerConfig: goRouter,
    );
  }
}
