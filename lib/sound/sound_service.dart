import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 효과음 재생 (assets/sfx/*.wav, gen_sfx 스크립트로 합성한 파일들).
///
/// 짧은 효과음이 겹칠 수 있어 플레이어 풀을 돌려가며 쓴다.
/// 재생 실패(플랫폼 미지원 등)는 게임 진행에 영향이 없도록 무시한다.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  /// 음소거 토글. UI가 구독해 아이콘을 갱신한다.
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  /// 첫 재생 시 생성 (음소거 상태나 테스트에서는 아예 만들지 않는다).
  List<AudioPlayer>? _pool;
  int _next = 0;

  void toggle() => enabled.value = !enabled.value;

  /// 패 버리기 — 톡.
  void tap() => _play('tap', volume: 0.7);

  /// 패 뽑기 — 블립.
  void draw() => _play('draw', volume: 0.5);

  /// 뺏어오기 — 뾰롱.
  void claim() => _play('claim');

  /// 영수증 항목 체크 — 딩.
  void ding() => _play('ding');

  /// 총점 발표 — 상승 팡파레.
  void total() => _play('total');

  /// 내가 이겼을 때.
  void win() => _play('win');

  /// 남이 이겼거나 유국.
  void lose() => _play('lose', volume: 0.7);

  Future<void> _play(String name, {double volume = 1.0}) async {
    if (!enabled.value) return;
    final pool = _pool ??= List.generate(4, (_) => _newPlayer());
    final player = pool[_next];
    _next = (_next + 1) % pool.length;
    try {
      await player.stop();
      await player.play(AssetSource('sfx/$name.wav'), volume: volume);
    } catch (_) {
      // 효과음은 실패해도 무시
    }
  }

  static AudioPlayer _newPlayer() {
    final player = AudioPlayer();
    player.setPlayerMode(PlayerMode.lowLatency).catchError((_) {});
    return player;
  }
}
