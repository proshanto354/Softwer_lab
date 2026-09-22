/// Push (FCM) messages would need a Cloud Function to send them, which cannot be written in Dart.
/// Instead, the app has in-app notifications (the bell on the home screen) that work on the free plan.
class PushService {
  static Future<void> register() async {}
}
