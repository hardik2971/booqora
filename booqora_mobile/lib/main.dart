import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'data/session.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Accessibility tree on demand in browser previews (used by automated QA).
  if (kIsWeb && Uri.base.queryParameters.containsKey('a11y')) SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = true;
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  }
  Session.instance.init();
  runApp(const BooqoraMobileApp());
}

class BooqoraMobileApp extends StatefulWidget {
  const BooqoraMobileApp({super.key});
  @override
  State<BooqoraMobileApp> createState() => _BooqoraMobileAppState();
}

class _BooqoraMobileAppState extends State<BooqoraMobileApp> {
  late final _router = buildRouter(Session.instance);

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.light();
    return ChangeNotifierProvider.value(
      value: Session.instance,
      child: MaterialApp.router(
        title: 'Booqora',
        debugShowCheckedModeBanner: false,
        theme: base.copyWith(
          platform: defaultTargetPlatform,
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: AppColors.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: base.textTheme.titleLarge,
            iconTheme: const IconThemeData(color: AppColors.ink),
          ),
          inputDecorationTheme: base.inputDecorationTheme.copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          }),
        ),
        routerConfig: _router,
        builder: (context, child) => MediaQuery(
          // Respect user font size but keep layouts intact.
          data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25)),
          child: child!,
        ),
      ),
    );
  }
}
