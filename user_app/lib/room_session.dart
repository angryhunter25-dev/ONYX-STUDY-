import 'package:flutter/material.dart';

/// Keeps one voice room alive while the user moves around the app.
/// The room page lives in HomeShell; "minimize" just hides it.
class RoomSession {
  static final ValueNotifier<String?> roomId = ValueNotifier<String?>(null);
  static final ValueNotifier<bool> expanded = ValueNotifier<bool>(false);

  static bool get active => roomId.value != null;

  static void open(BuildContext context, String id) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    roomId.value = id;
    expanded.value = true;
  }

  static void expand() => expanded.value = true;
  static void minimize() => expanded.value = false;

  static void exit() {
    expanded.value = false;
    roomId.value = null;
  }
}
