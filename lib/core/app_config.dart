/// app_config.dart — Centralised runtime configuration
///
/// Change [baseUrl] here (ONE place) when the server URL changes.
/// No other file in the project should hardcode the server address.
///
/// ─── Environments ───────────────────────────────────────────────────────
///
///  • Production (Render)
///    defaultValue below → https://edushare-api.onrender.com
///    Replace with your actual Render service URL after deployment.
///
///  • Android Emulator (local dev)
///    flutter run --dart-define=BASE_URL=http://10.0.2.2:5000
///
///  • Physical Android Device (local dev, same Wi-Fi)
///    flutter run --dart-define=BASE_URL=http://192.168.0.137:5000
///    Replace with your machine's current LAN IP.
///
/// ─── Override at build time ─────────────────────────────────────────────
///   flutter run  --dart-define=BASE_URL=http://10.0.2.2:5000
///   flutter build apk --dart-define=BASE_URL=https://edushare-api.onrender.com
/// ───────────────────────────────────────────────────────────────────────

class AppConfig {
  AppConfig._();

  /// ⚠️  UPDATE THIS after you deploy to Render.
  ///
  /// 1. Deploy the backend to Render.
  /// 2. Copy the URL from the Render dashboard (e.g. https://edushare-api.onrender.com).
  /// 3. Replace the defaultValue below with that URL.
  /// 4. Rebuild the Flutter app: flutter build apk
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://edushare-dnd7.onrender.com', // ← Production Render URL
  );

  /// App-wide request timeout.
  /// Raised to 30 s to account for Render free-tier cold starts (up to 15 s spin-up time).
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Timeout for file upload requests (larger files take longer).
  static const Duration uploadTimeout = Duration(seconds: 90);
}
