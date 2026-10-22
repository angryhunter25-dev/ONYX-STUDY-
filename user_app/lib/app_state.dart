import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<bool> darkMode = ValueNotifier<bool>(true);
bool vibrationOn = true;
bool notificationsOn = true;

Future<void> loadSettings() async {
  try {
    final p = await SharedPreferences.getInstance();
    darkMode.value = p.getBool('dark') ?? true;
    vibrationOn = p.getBool('vibration') ?? true;
    notificationsOn = p.getBool('notifications') ?? true;
  } catch (_) {}
}

Future<void> saveSetting(String key, bool v) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  } catch (_) {}
}
