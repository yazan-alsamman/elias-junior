import 'package:app/common/app_colors.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/page_transitions.dart';
import 'package:app/controller/career_controller.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/controller/pipeline_controller.dart';
import 'package:app/controller/portfolio_controller.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/services/career_api_service.dart';
import 'package:app/view/screens/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AuroraDark.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Get.putAsync<AuthApiService>(() => AuthApiService().init());
  Get.put<CareerApiService>(CareerApiService(), permanent: true);

  final AuthApiService auth = Get.find<AuthApiService>();
  final CareerController career = CareerController();
  if (auth.isLoggedIn) {
    career.phase = AppPhase.dashboard;
    career.mainPage = AppMainPage.dashboard;
  }

  Get.put<CareerController>(career, permanent: true);
  Get.put<CVController>(CVController(), permanent: true);
  Get.put<PipelineController>(PipelineController(), permanent: true);
  Get.put<PortfolioController>(PortfolioController(), permanent: true);
  CareerController.onLogoutNavigation = () {
    Get.offAll<void>(() => const HomeView());
  };

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!Get.find<AuthApiService>().isLoggedIn) {
      return;
    }
    await Get.find<AuthApiService>().validateToken();
    if (!Get.find<AuthApiService>().isLoggedIn) {
      career.phase = AppPhase.login;
    } else if (Get.key.currentState?.canPop() == true) {
      Get.offAll<void>(() => const HomeView());
    }
    career.update();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CareerPath AI',
      themeMode: ThemeMode.dark,
      darkTheme: _buildAuroraTheme(),
      theme: _buildAuroraTheme(),
      customTransition: AuroraSharedAxisTransition(),
      transitionDuration: AppDurations.medium,
      defaultTransition: Transition.noTransition,
      initialRoute: '/',
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(name: '/', page: () => const HomeView()),
        // GetX / web may request this name when [home] was used before.
        GetPage<dynamic>(name: '/HomeView', page: () => const HomeView()),
      ],
    );
  }

  ThemeData _buildAuroraTheme() {
    final ColorScheme scheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AuroraDark.indigo,
      onPrimary: Colors.white,
      primaryContainer: AuroraDark.surfaceHigh,
      onPrimaryContainer: AuroraDark.textPrimary,
      secondary: AuroraDark.cyanBright,
      onSecondary: AuroraDark.bg,
      tertiary: AuroraDark.violet,
      onTertiary: Colors.white,
      surface: AuroraDark.surface,
      onSurface: AuroraDark.textPrimary,
      surfaceContainer: AuroraDark.surfaceAlt,
      surfaceContainerHigh: AuroraDark.surfaceHigh,
      surfaceContainerHighest: AuroraDark.surfaceHigh,
      onSurfaceVariant: AuroraDark.textSecondary,
      outline: AuroraDark.border,
      outlineVariant: AuroraDark.borderStrong,
      error: AuroraDark.danger,
      onError: Colors.white,
    );

    final TextTheme textTheme = TextTheme(
      displayLarge: AppType.displayLarge,
      displayMedium: AppType.displayMedium,
      headlineLarge: AppType.headlineLarge,
      headlineMedium: AppType.headlineMedium,
      headlineSmall: AppType.headlineSmall,
      titleLarge: AppType.titleLarge,
      titleMedium: AppType.titleMedium,
      titleSmall: AppType.titleSmall,
      bodyLarge: AppType.bodyLarge,
      bodyMedium: AppType.bodyMedium,
      bodySmall: AppType.bodySmall,
      labelLarge: AppType.labelLarge,
      labelMedium: AppType.labelMedium,
      labelSmall: AppType.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AuroraDark.bg,
      canvasColor: AuroraDark.bg,
      dialogTheme: const DialogThemeData(
        backgroundColor: AuroraDark.surface,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AuroraDark.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppType.titleLarge,
        iconTheme: const IconThemeData(color: AuroraDark.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AuroraDark.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rLg),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AuroraDark.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rSm),
          textStyle: AppType.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AuroraDark.textPrimary,
          side: const BorderSide(color: AuroraDark.borderStrong, width: 1.2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rSm),
          textStyle: AppType.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AuroraDark.cyanBright,
          textStyle: AppType.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AuroraDark.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuroraDark.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.rSm,
          borderSide: const BorderSide(color: AuroraDark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.rSm,
          borderSide: const BorderSide(color: AuroraDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.rSm,
          borderSide: const BorderSide(color: AuroraDark.cyanBright, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rSm,
          borderSide: const BorderSide(color: AuroraDark.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rSm,
          borderSide: const BorderSide(color: AuroraDark.danger, width: 1.4),
        ),
        labelStyle: AppType.bodyMedium,
        hintStyle: AppType.bodyMedium
            .copyWith(color: AuroraDark.textMuted),
        prefixIconColor: AuroraDark.textMuted,
        suffixIconColor: AuroraDark.textMuted,
      ),
      dividerTheme: const DividerThemeData(
        color: AuroraDark.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AuroraDark.surfaceAlt,
        side: const BorderSide(color: AuroraDark.border),
        labelStyle: AppType.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rPill),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AuroraDark.surfaceHigh,
          borderRadius: AppRadii.rXs,
          border: Border.all(color: AuroraDark.border),
        ),
        textStyle: AppType.bodySmall.copyWith(color: AuroraDark.textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 2,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AuroraDark.surfaceHigh,
        contentTextStyle: AppType.bodyMedium
            .copyWith(color: AuroraDark.textPrimary),
        actionTextColor: AuroraDark.cyanBright,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.rSm,
          side: const BorderSide(color: AuroraDark.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AuroraDark.cyanBright,
        linearTrackColor: AuroraDark.surfaceAlt,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
