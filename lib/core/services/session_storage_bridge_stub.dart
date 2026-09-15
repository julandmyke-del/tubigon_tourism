/// Native platforms keep using their existing persistent storage.
bool get sessionStorageAvailable => false;

String? readSessionValue(String key) => null;

void writeSessionValue(String key, String value) {}

void removeSessionValue(String key) {}

void clearSessionValues(Iterable<String> keys) {}

Set<String> sessionStorageKeys() => const <String>{};
