import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'data/session.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Accessibility tree on demand (also used by automated QA): append ?a11y to the URL.
  if (Uri.base.queryParameters.containsKey('a11y')) SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = true;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  Session.instance.init();
  runApp(const BooqoraApp());
}

class BooqoraApp extends StatefulWidget {
  const BooqoraApp({super.key});

  @override
  State<BooqoraApp> createState() => _BooqoraAppState();
}

class _BooqoraAppState extends State<BooqoraApp> {
  late final _router = buildRouter(Session.instance);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Session.instance,
      child: MaterialApp.router(
        title: 'Booqora — Rental management platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
