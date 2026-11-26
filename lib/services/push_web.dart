import 'dart:js_interop';

@JS('registerPush')
external JSPromise<JSString> _registerPush(JSString vapidKey);

/// Asks the browser for permission and returns this device's push token.
Future<String?> registerPushToken(String vapidKey) async {
  try {
    final r = await _registerPush(vapidKey.toJS).toDart;
    final t = r.toDart;
    return t.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}
