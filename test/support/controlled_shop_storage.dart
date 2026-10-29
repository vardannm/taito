import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/types.dart';

final class ControlledShopStorage extends InMemorySharedPreferencesAsync {
  ControlledShopStorage() : super.empty();
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    await gate?.future;
    if (fail) throw PlatformException(code: 'storage-full');
    return super.setString(key, value, options);
  }
}
