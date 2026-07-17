import 'package:flutter/foundation.dart';

import '../logic/claim.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../models/tile.dart';

enum TableNoticeKind { left, rejoined, claimed }

/// 방 전체에 띄우는 일회성 알림 (참가자 퇴장/복귀/뺏어오기).
///
/// left·rejoined는 사람이 직접 입력한 이름을 그대로 담고, claimed는
/// AI 좌석일 수도 있으므로 좌석 번호만 담아 UI가 언어별 이름으로
/// 표시하게 한다.
class TableNotice {
  final TableNoticeKind kind;
  final String name;
  final int? seat;

  const TableNotice(this.kind, this.name, {this.seat});
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

  /// 화면에 보이는 좌석 번호(0=나)를 실제(회전 전) 좌석 번호로 바꾼다.
  /// 로컬 대전은 회전이 없어 항등함수, LAN 클라이언트는 호스트가
  /// 알려준 자신의 실제 좌석을 기준으로 되돌린다.
  ///
  /// AI 이름처럼 "좌석 번호로 언어별 이름을 고르는" 곳에서 이 값을
  /// 써야 한다 — 화면 위치는 참가자마다 회전이 달라, 화면 위치 번호로
  /// 이름을 고르면 같은 AI가 참가자마다 다른 이름으로 보이는 문제가
  /// 생긴다.
  int actualSeatOf(int seat) => seat;

  /// 네트워크 대전에서 순간 끊김을 복구하는 중인지 (배너 표시용).
  bool get isReconnecting => false;

  /// 내 버리기 차례의 제한시간 (초과하면 호스트가 자동으로 버린다).
  /// UI가 카운트다운을 띄우는 데 쓴다. null = 제한 없음 (로컬 AI 대전).
  Duration? get discardTimeLimit => null;

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
