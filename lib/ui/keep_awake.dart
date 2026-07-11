import 'package:wakelock_plus/wakelock_plus.dart';

/// 게임/로비 화면이 떠 있는 동안 화면 꺼짐을 막는다.
///
/// 화면이 꺼지면 Wi-Fi 절전으로 LAN 연결이 끊겨 방이 사라지므로,
/// 대기실과 대국 화면에서는 항상 켜 둔다. 여러 화면이 겹칠 수 있어
/// (로비 위에 게임 화면) 참조 카운트로 관리한다.
class KeepAwake {
  static int _count = 0;

  static void acquire() {
    if (++_count == 1) {
      WakelockPlus.enable().catchError((_) {}); // 미지원 플랫폼은 무시
    }
  }

  static void release() {
    if (_count > 0 && --_count == 0) {
      WakelockPlus.disable().catchError((_) {});
    }
  }
}
