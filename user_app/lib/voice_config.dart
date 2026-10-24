import 'common.dart';

/// Agora App ID. Do tareeke:
///  1) Owner app > App update > "Agora App ID" me paste karo (rebuild nahi chahiye), ya
///  2) yahan paste karo.
/// (https://console.agora.io -> New Project -> "Testing mode: App ID only")
const String agoraAppId = '';

/// Ek room me kitni seat hongi.
const int voiceSeatCount = 8;

/// App ID: pehle yahan wala, warna Firebase `appConfig/agoraAppId`.
Future<String> loadAgoraAppId() async {
  final local = agoraAppId.trim();
  if (local.isNotEmpty && local != 'YOUR_AGORA_APP_ID') return local;
  try {
    final s = await rtdb.ref('appConfig/agoraAppId').get();
    return '${s.value ?? ''}'.trim();
  } catch (_) {
    return '';
  }
}
