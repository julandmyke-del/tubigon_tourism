// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Browser sessionStorage is isolated per top-level tab and is discarded when
/// that tab closes. This prevents one Tour Tubigon account from replacing the
/// active credentials and role metadata of another tab on the same origin.
bool get sessionStorageAvailable => true;

String? readSessionValue(String key) {
  try {
    return html.window.sessionStorage[key];
  } catch (_) {
    return null;
  }
}

void writeSessionValue(String key, String value) {
  try {
    html.window.sessionStorage[key] = value;
  } catch (_) {}
}

void removeSessionValue(String key) {
  try {
    html.window.sessionStorage.remove(key);
  } catch (_) {}
}

void clearSessionValues(Iterable<String> keys) {
  try {
    for (final key in keys) {
      html.window.sessionStorage.remove(key);
    }
  } catch (_) {}
}

Set<String> sessionStorageKeys() {
  try {
    return html.window.sessionStorage.keys.toSet();
  } catch (_) {
    return const <String>{};
  }
}
