class AppConfig {
  /// Android emülatöründe bilgisayarın localhost'u 10.0.2.2'dir.
  /// Gerçek telefonda: flutter run --dart-define=N8N_URL=http://BILGISAYAR_IP:5678
  static const String n8nBaseUrl =
      String.fromEnvironment('N8N_URL', defaultValue: 'http://10.0.2.2:5678');
}
