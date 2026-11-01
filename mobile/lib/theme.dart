import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kNavy = Color(0xFF1A4C8B);
const Color kNavyDark = Color(0xFF123A6B);
const Color kOrange = Color(0xFFF2941D);
const Color kOrangeDark = Color(0xFFD97E0A);
const Color kBg = Color(0xFFF5F7FB);
const Color kBgDark = Color(0xFF0F1621);
const Color kSurfaceDark = Color(0xFF1A2434);

const kRadius = 16.0;
const kRadiusSm = 12.0;

ThemeData buildAppTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kNavy,
    brightness: brightness,
    primary: dark ? const Color(0xFF5B93D6) : kNavy,
    secondary: kOrange,
    surface: dark ? kSurfaceDark : Colors.white,
  );
  final textTheme = GoogleFonts.plusJakartaSansTextTheme(dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: dark ? kBgDark : kBg,
    colorScheme: scheme,
    textTheme: textTheme,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? kBgDark : Colors.white,
      foregroundColor: dark ? Colors.white : kNavyDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
        elevation: 2,
        shadowColor: kOrange.withValues(alpha: 0.4),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
        side: BorderSide(color: dark ? Colors.white24 : Colors.black12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? const Color(0xFF5B93D6) : kNavy,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? kSurfaceDark : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE2E6EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? kSurfaceDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E6EE)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEF1F6),
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? Colors.white : Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: const StadiumBorder(),
    ),
    dividerTheme: DividerThemeData(color: dark ? Colors.white12 : const Color(0xFFE2E6EE), space: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: dark ? const Color(0xFF5B93D6) : kNavy,
      unselectedItemColor: dark ? Colors.white38 : Colors.grey,
      backgroundColor: dark ? kSurfaceDark : Colors.white,
      type: BottomNavigationBarType.fixed,
      elevation: 12,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _PremiumPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// A soft fade+slide transition for Android (iOS keeps its native slide-from-right) — avoids the
/// default's abrupt platform fade so navigation feels a little more deliberate/premium.
class _PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const _PremiumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

Color statusColor(String status) {
  final s = status.toUpperCase();
  // Negative labels first — "NOT APPROVED" also contains "APPROVED".
  if (s.contains('REJECTED') || s.contains('NOT APPROVED') || s == 'CANCELLED' || s == 'DECLINED' || s == 'DEACTIVATED') {
    return const Color(0xFFC62828);
  }
  if (s.contains('APPROVED') || s == 'CONFIRMED' || s == 'SCHEDULED' || s.startsWith('GRADED') || s == 'DONE' || s == 'COMPLETED') {
    return const Color(0xFF1C8A4B);
  }
  if (s.contains('PENDING') || s.contains('LATE') || s == 'UNDER REVIEW' || s == 'IN PROGRESS' || s == 'UNPUBLISHED') {
    return const Color(0xFFB8720A);
  }
  return Colors.grey;
}

/// Soft brand gradient used behind auth screens and highlight banners.
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kNavy, kNavyDark, Color(0xFF0C2A4F)],
);

const LinearGradient kAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kOrange, kOrangeDark],
);
