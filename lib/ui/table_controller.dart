import 'package:flutter/foundation.dart';

import '../logic/claim.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../models/tile.dart';

enum TableNoticeKind { left, rejoined }

/// 방 전체에 띄우는 일회성 알림 (참가자 퇴장/복귀).
class TableNotice {
  final TableNoticeKind kind;
  final String name;

  const TableNotice(this.kind, this.name);
}

/// GameScreen이 소비하는 대국 컨트롤러 공통 인터페이스.
///
/// 구현체: 로컬 AI 대전([GameController]), LAN 호스트([NetHostController]),
/// LAN 클라이언트([NetClientController]).
/// 어느 구현에서든 좌석 0 = 화면을 보는 나. (네트워크에서는 호스트가
/// 클라이언트마다 좌석을 회전시켜 보내므로 UI는 신경 쓸 필요 없다.)
abstract class TableController extends ChangeNotifier {
  /// 최근 알림 (퇴장/복귀). UI가 구독해 스낵바로 보여준다.
  final ValueNotifier<TableNotice?> notice = ValueNotifier(null);
  Game get game;

  MatchState get match;

  /// 초보자 모드 (점수 없이 승수만).
  bool get simpleMode;

  /// 다음 판/새 대국 진행 권한. 로컬·호스트는 true, 클라이언트는 false
  /// (호스트를 기다린다).
  bool get canControlRounds;

  /// 좌석별 표시 이름. null이거나 항목이 null이면 언어별 기본 이름 사용.
  List<String?>? get seatNames;

  /// 네트워크 대전에서 순간 끊김을 복구하는 중인지 (배너 표시용).
  bool get isReconnecting => false;

  /// 완성/뺏어오기 응답을 아직 고민 중인 좌석들 (0 = 나).
  /// 다른 사람이 고르는 동안 "선택 중" 배너를 띄우는 데 쓴다.
  List<int> get claimWaitingSeats => const [];

  bool get isFinished;

  bool get isHumanDiscardTurn;

  bool get canHumanTsumo;

  Player get human;

  List<Tile> get humanWaits;

  ClaimOpportunity? get humanClaimOpportunity;

  void humanDiscard(Tile tile);

  void humanTsumo();

  void humanRespondClaim({bool win = false, ClaimOption? option});

  void nextRound();

  void newMatch();
}
