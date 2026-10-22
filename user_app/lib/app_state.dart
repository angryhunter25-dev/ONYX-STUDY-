import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<bool> darkMode = ValueNotifier<bool>(true);
bool vibrationOn = true;
bool notificationsOn = true;
final ValueNotifier<int> annSeen = ValueNotifier<int>(0);

Future<void> loadSettings() async {
  try {
    final p = await SharedPreferences.getInstance();
    darkMode.value = p.getBool('dark') ?? true;
    vibrationOn = p.getBool('vibration') ?? true;
    notificationsOn = p.getBool('notifications') ?? true;
    annSeen.value = p.getInt('annSeen') ?? 0;
  } catch (_) {}
}

Future<void> saveSetting(String key, bool v) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  } catch (_) {}
}

Future<void> saveAnnSeen(int v) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setInt('annSeen', v);
  } catch (_) {}
}
