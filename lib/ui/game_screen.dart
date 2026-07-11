import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../models/tile.dart';
import '../settings/app_settings.dart';
import '../sound/sound_service.dart';
import 'game_controller.dart';
import 'keep_awake.dart';
import 'score_receipt.dart';
import 'table_controller.dart';
import 'theme.dart';
import 'tile_widget.dart';

const _avatars = ['🙂', '🐰', '🧸', '🐱'];

String _fmt(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// 좌석 표시 이름: 네트워크 대전이면 참가자 이름, 아니면 언어 기본 이름.
String _nameOf(TableController gc, Strings s, int seat) =>
    gc.seatNames?[seat] ?? s.playerNames[seat];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TableController _gc;

  @override
  void initState() {
    super.initState();
    KeepAwake.acquire(); // 대국 중 화면 꺼짐(→ Wi-Fi 절전) 방지
    _gc = context.read<TableController>();
    _gc.notice.addListener(_onNotice);
  }

  @override
  void dispose() {
    _gc.notice.removeListener(_onNotice);
    KeepAwake.release();
    super.dispose();
  }

  /// 참가자 퇴장/복귀 알림을 방 전체에 스낵바로 띄운다.
  void _onNotice() {
    final n = _gc.notice.value;
    if (n == null || !mounted) return;
    final s = context.read<AppSettings>().strings;
    final text = switch (n.kind) {
      TableNoticeKind.left => s.playerLeft(n.name),
      TableNoticeKind.rejoined => s.playerRejoined(n.name),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(fontSize: 14)),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<TableController>();
    final s = context.watch<AppSettings>().strings;
    // 가로모드: 화면 세로 폭이 좁으므로 상단 패널을 한 줄로 눕혀
    // 초록 게임판이 쓸 수 있는 세로 공간을 늘린다.
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _OpponentPanel(seat: 2, compact: landscape),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        _OpponentPanel(seat: 3),
                        const SizedBox(width: 8),
                        const Expanded(child: _CenterTable()),
                        const SizedBox(width: 8),
                        _OpponentPanel(seat: 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _HumanPanel(),
                ],
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: s.homeTooltip,
                icon: const Icon(Icons.home_rounded,
                    color: Palette.textBrown, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // 판/남은 패 정보: 테이블 중앙을 가리지 않게 홈 버튼 아래에.
            Positioned(
              top: 52,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.mint, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🀄 ${s.roundOf(gc.match.currentRound, MatchState.totalRounds)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Palette.textBrown),
                    ),
                    Text(
                      s.wallLeft(gc.game.wallCount),
                      style: const TextStyle(
                          fontSize: 11, color: Palette.textBrown),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: ValueListenableBuilder<bool>(
                valueListenable: SoundService.instance.enabled,
                builder: (context, on, _) => IconButton(
                  tooltip: on ? s.muteTooltip : s.unmuteTooltip,
                  icon: Icon(
                    on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: Palette.textBrown,
                    size: 26,
                  ),
                  onPressed: SoundService.instance.toggle,
                ),
              ),
            ),
            if (gc.isReconnecting)
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Palette.pink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(s.reconnecting,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            // 다른 사람이 완성/뺏어오기를 고민 중일 때 (내 프롬프트는 없음)
            if (!gc.isReconnecting &&
                !gc.isFinished &&
                gc.humanClaimOpportunity == null &&
                gc.claimWaitingSeats.any((seat) => seat != 0))
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Palette.mint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🤔 ${s.decidingOf(gc.claimWaitingSeats.where((seat) => seat != 0).map((seat) => _nameOf(gc, s, seat)).join(', '))}',
                      style: const TextStyle(
                          color: Palette.textBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ),
            if (gc.humanClaimOpportunity != null)
              _ClaimPrompt(key: ValueKey(gc.game.lastDiscard)),
            if (gc.isFinished) const _ResultOverlay(),
          ],
        ),
      ),
    );
  }
}

/// AI 상대 표시: 아바타, 점수(또는 승수), 뒷면 손패 수, 공개 몸통.
///
/// [compact]는 가로모드 상단(seat 2) 전용 한 줄 레이아웃. 가로모드는
/// 화면 세로 폭이 좁아서, 상단 패널이 세로로 길면 정작 중요한 초록
/// 게임판이 밀려 작아진다 — 그래서 여기서만 가로로 눕혀 높이를 아낀다.
class _OpponentPanel extends StatelessWidget {
  final int seat;
  final bool compact;

  const _OpponentPanel({required this.seat, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<TableController>();
    final s = context.watch<AppSettings>().strings;
    final p = gc.game.players[seat];
    final isTurn = !gc.isFinished && gc.game.current == seat;

    final decoration = BoxDecoration(
      color: isTurn ? Palette.mint : Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isTurn ? Palette.mintDark : Colors.black12,
        width: isTurn ? 2 : 1,
      ),
    );
    final nameText = Text('${_avatars[seat]} ${_nameOf(gc, s, seat)}',
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Palette.textBrown));
    final scoreText = Text(
      gc.simpleMode
          ? s.wins(gc.match.winCounts[seat])
          : s.points(_fmt(gc.match.scores[seat])),
      style: const TextStyle(fontSize: 12, color: Palette.textBrown),
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            nameText,
            const SizedBox(width: 8),
            scoreText,
            const SizedBox(width: 12),
            const TileWidget(null, size: 14),
            const SizedBox(width: 4),
            Text('× ${p.hand.length}',
                style: const TextStyle(color: Palette.textBrown)),
            for (final meld in p.melds)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TileRow(meld.tiles, size: 16),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          nameText,
          scoreText,
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TileWidget(null, size: 14),
              const SizedBox(width: 4),
              Text('× ${p.hand.length}',
                  style: const TextStyle(color: Palette.textBrown)),
            ],
          ),
          for (final meld in p.melds)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TileAppear(
                from: const Offset(0, 16),
                child: TileRow(meld.tiles, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

/// 중앙 테이블: 실제 마작 테이블처럼 4인의 강(버림패)이 각자 자리 앞에
/// 놓이고, 옆/맞은편 플레이어의 패는 그 방향으로 회전된다.
///
/// Stack+Align 대신 Column/Row+Expanded로 짠 이유: Align은 "가능한 한
/// 크게" 채우려는 성질이 있어, 위/아래 강 영역이 실제 내용과 무관하게
/// 항상 통짜로 부풀어 옆 플레이어 패널 자리까지 침범하는 문제가 있었다.
/// 여기서는 위/아래 강에 전체 높이의 일정 비율까지만 [ConstrainedBox]로
/// 상한을 씌우고, 좌/우 강은 [Expanded]로 폭 상한을 준 뒤 [_River]가
/// 그 안에서 알아서 타일 크기를 줄이거나(그래도 안 맞으면) 최근 패만
/// 보여주도록 한다 — 어떤 화면 크기에서도 절대 넘치지 않는다.
class _CenterTable extends StatelessWidget {
  const _CenterTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias, // 극단적인 경우를 위한 마지막 안전장치
      decoration: BoxDecoration(
        color: Palette.tableGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.mint, width: 3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final capHeight =
              constraints.maxHeight.isFinite ? constraints.maxHeight * 0.32 : 160.0;
          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: capHeight),
                child: const RotatedBox(
                    quarterTurns: 2, child: _River(seat: 2)),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: RotatedBox(
                          quarterTurns: 1, child: _River(seat: 3)),
                    ),
                    const Spacer(flex: 2),
                    Expanded(
                      flex: 5,
                      child: RotatedBox(
                          quarterTurns: 3, child: _River(seat: 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: capHeight),
                child: const _River(seat: 0),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 한 플레이어의 강: 주어진 폭·높이 안에 다 들어가는 가장 큰 타일 크기를
/// 찾아서 그리고, 그래도 안 들어갈 만큼 패가 쌓였으면 가장 최근 패만
/// 보여준다 (절대 부모 영역을 넘치지 않는다).
///
/// 좌우 플레이어(seat 1/3)는 [RotatedBox]로 90도 돌아간 채 이 위젯의
/// 자식이 되는데, RotatedBox는 90/270도일 때 자식에게 넘기는 제약을
/// 가로-세로 서로 바꿔서 준다. 그래서 이 위젯은 회전 여부를 신경 쓸
/// 필요 없이 그냥 "내가 받은 제약 안에 맞추기"만 하면 된다.
class _River extends StatelessWidget {
  final int seat;

  const _River({required this.seat});

  static const _baseTileSize = 22.0;
  static const _minTileSize = 14.0;
  static const _tileGap = 2.0;
  static const _rowGap = 2.0;
  static const _tileAspect = 1.4; // TileWidget: height = width * 1.4

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<TableController>();
    final game = gc.game;
    final tiles = game.players[seat].discards;
    if (tiles.isEmpty) return const SizedBox.shrink();

    final claimable =
        game.phase == GamePhase.awaitingClaims && game.lastDiscarder == seat;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final maxH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 160.0;

        var size = _baseTileSize;
        var perRow = _perRowFor(maxW, size);
        var rowCount = (tiles.length / perRow).ceil();
        while (_neededHeight(rowCount, size) > maxH && size > _minTileSize) {
          size -= 1;
          perRow = _perRowFor(maxW, size);
          rowCount = (tiles.length / perRow).ceil();
        }

        // 그래도 못 맞추면(아주 오래 쌓인 강) 최근 패만 보여준다.
        final maxRows =
            math.max(1, (maxH / (size * _tileAspect + _rowGap)).floor());
        final shown = rowCount > maxRows
            ? tiles.sublist(math.max(0, tiles.length - perRow * maxRows))
            : tiles;

        final rows = <Widget>[];
        for (var start = 0; start < shown.length; start += perRow) {
          final end = math.min(start + perRow, shown.length);
          rows.add(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = start; i < end; i++)
                Padding(
                  padding:
                      const EdgeInsets.only(right: _tileGap, top: _rowGap),
                  child: _tileAt(shown, i, size, claimable),
                ),
            ],
          ));
        }

        // verticalDirection.up: 첫 줄이 플레이어 쪽(아래), 새 줄은 중앙 쪽으로.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          verticalDirection: VerticalDirection.up,
          children: rows,
        );
      },
    );
  }

  static int _perRowFor(double maxWidth, double tileSize) =>
      math.max(1, (maxWidth / (tileSize + _tileGap)).floor());

  static double _neededHeight(int rows, double tileSize) =>
      rows * (tileSize * _tileAspect + _rowGap);

  Widget _tileAt(List<Tile> tiles, int index, double size, bool claimable) {
    final isNewest = index == tiles.length - 1;
    final tile = TileWidget(
      tiles[index],
      size: size,
      highlighted: claimable && isNewest,
    );
    if (!isNewest) return tile;
    return TileAppear(
      key: ValueKey('river-$seat-${tiles.length}'),
      from: const Offset(0, 44), // 플레이어 쪽(아래)에서 날아온다
      child: tile,
    );
  }
}

/// 내 영역: 대기패 가이드, 공개 몸통, 손패, 완성 버튼.
class _HumanPanel extends StatelessWidget {
  const _HumanPanel();

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<TableController>();
    final s = context.watch<AppSettings>().strings;
    final p = gc.human;
    final myTurn = gc.isHumanDiscardTurn;
    final waits = gc.humanWaits;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: myTurn ? Palette.mint : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: myTurn ? Palette.mintDark : Colors.black12,
          width: myTurn ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (waits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.waitingLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Palette.textBrown)),
                  TileRow(waits, size: 20),
                ],
              ),
            ),
          Row(
            children: [
              Text('${_avatars[0]} ${_nameOf(gc, s, 0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Palette.textBrown)),
              const SizedBox(width: 6),
              Text(
                gc.simpleMode
                    ? s.wins(gc.match.winCounts[0])
                    : s.points(_fmt(gc.match.scores[0])),
                style:
                    const TextStyle(fontSize: 12, color: Palette.textBrown),
              ),
              const SizedBox(width: 12),
              for (final meld in p.melds)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TileAppear(
                    from: const Offset(0, -16),
                    child: TileRow(meld.tiles, size: 18),
                  ),
                ),
              const Spacer(),
              if (myTurn)
                Text(
                  gc.canHumanTsumo ? s.canComplete : s.chooseDiscard,
                  style: const TextStyle(color: Palette.textBrown),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _handRow(gc, myTurn)),
              if (gc.canHumanTsumo)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton(
                    onPressed: gc.humanTsumo,
                    child: Text(s.completeBtn),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 손패 나열. 방금 뽑은 패는 실제 마작처럼 오른쪽에 분리해 표시하고
  /// 덱에서 날아오는 애니메이션으로 등장시킨다.
  ///
  /// 타일 크기를 폭에 맞춰 계산해서 항상 한 줄에 [_targetCols]장 정도가
  /// 들어가게 한다. 고정 크기(42)를 쓰면 "완성!" 버튼이 나타났다
  /// 사라졌다 할 때마다 남은 폭이 바뀌어 줄 수가 2↔3으로 들쭉날쭉했다.
  Widget _handRow(TableController gc, bool myTurn) {
    final p = gc.human;
    final drawn = myTurn ? gc.game.drawnTile : null;
    final handTiles = List<Tile>.of(p.hand);
    if (drawn != null) handTiles.remove(drawn); // 뽑은 패 한 장만 분리

    const targetCols = 7;
    const maxTileSize = 42.0;
    const minTileSize = 28.0;
    const gap = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.isFinite
            ? ((constraints.maxWidth - (targetCols - 1) * gap) / targetCols)
                .clamp(minTileSize, maxTileSize)
            : maxTileSize;

        return Row(
          children: [
            Flexible(
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final tile in handTiles)
                    TileWidget(
                      tile,
                      size: size,
                      onTap: myTurn ? () => gc.humanDiscard(tile) : null,
                    ),
                ],
              ),
            ),
            if (drawn != null) ...[
              const SizedBox(width: 18),
              TileAppear(
                key: ValueKey('drawn-${gc.game.wallCount}'),
                from: const Offset(60, -30), // 중앙 덱 쪽에서 날아온다
                child: TileWidget(
                  drawn,
                  size: size,
                  highlighted: true,
                  onTap: () => gc.humanDiscard(drawn),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 완성/뺏어오기 응답 프롬프트. 15초 안에 답하지 않으면 자동 패스해
/// 다른 참가자를 기다리게 하지 않는다.
class _ClaimPrompt extends StatefulWidget {
  const _ClaimPrompt({super.key});

  @override
  State<_ClaimPrompt> createState() => _ClaimPromptState();
}

class _ClaimPromptState extends State<_ClaimPrompt> {
  static const _timeoutSeconds = 15;

  int _remaining = _timeoutSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        context.read<TableController>().humanRespondClaim(); // 자동 패스
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<TableController>();
    final s = context.watch<AppSettings>().strings;
    final opp = gc.humanClaimOpportunity!;
    final discarded = gc.game.lastDiscard!;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 180,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TileWidget(discarded, size: 30, highlighted: true),
                  const SizedBox(width: 8),
                  Text(s.claimQuestion,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Palette.textBrown)),
                  const SizedBox(width: 10),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _remaining <= 5 ? Palette.pink : Palette.mint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_remaining',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (opp.canWin)
                    ElevatedButton(
                      onPressed: () => gc.humanRespondClaim(win: true),
                      child: Text(s.completeBtn),
                    ),
                  for (final option in opp.options)
                    OutlinedButton(
                      onPressed: () => gc.humanRespondClaim(option: option),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TileRow(option.meld.tiles, size: 22),
                      ),
                    ),
                  TextButton(
                    onPressed: () => gc.humanRespondClaim(),
                    child: Text(s.passBtn),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 판 결과(점수 정산) + 대국 종료 시 최종 순위 화면.
class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay();

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<TableController>();
    final settings = context.watch<AppSettings>();
    final s = settings.strings;
    final match = gc.match;
    final result = match.lastResult!;
    final winner = result.winner;
    final simple = gc.simpleMode;

    final String title;
    final String emoji;
    String subtitle = '';
    if (winner == null) {
      emoji = '😴';
      title = s.drawTitle;
    } else {
      emoji = winner == GameController.humanSeat ? '🎉' : '😯';
      title = winner == GameController.humanSeat
          ? s.iWonTitle
          : s.otherWon('${_avatars[winner]} ${_nameOf(gc, s, winner)}');
      if (result.winType == WinType.ron) {
        final loser =
            '${_avatars[result.loser!]} ${_nameOf(gc, s, result.loser!)}';
        subtitle = simple
            ? s.simpleRonSub(loser)
            : s.ronSub(loser, s.points(_fmt(result.value)));
      } else {
        subtitle = simple
            ? s.simpleTsumoSub
            : s.tsumoSub(s.points(_fmt(result.value)));
      }
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Palette.cream,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Palette.textBrown)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: Palette.textBrown)),
              ],
              if (gc.game.winningHand != null) ...[
                const SizedBox(height: 12),
                TileRow(gc.game.winningHand!, size: 26),
                if (gc.game.players[winner!].melds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final meld in gc.game.players[winner].melds)
                        TileRow(meld.tiles, size: 20),
                    ],
                  ),
                ],
              ],
              if (result.score != null) ...[
                const SizedBox(height: 14),
                ScoreReceipt(result.score!,
                    strings: s, key: ValueKey(match.roundsPlayed)),
              ],
              const SizedBox(height: 16),
              _scoreBoard(gc, match, result, s, simple),
              const SizedBox(height: 20),
              if (match.isMatchOver)
                _finalResult(context, gc, s, simple)
              else if (gc.canControlRounds)
                ElevatedButton(
                  onPressed: gc.nextRound,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Text(s.nextRound(
                        match.currentRound, MatchState.totalRounds)),
                  ),
                )
              else
                Text(s.waitingHostNext,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }

  /// 이번 판의 점수 변동과 현재 점수 (초보자 모드에서는 승수만).
  Widget _scoreBoard(TableController gc, MatchState match, RoundResult result,
      Strings s, bool simple) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var seat = 0; seat < 4; seat++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('${_avatars[seat]} ${_nameOf(gc, s, seat)}',
                        style: const TextStyle(color: Palette.textBrown),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (simple) ...[
                    SizedBox(
                      width: 60,
                      child: Text(
                        result.winner == seat ? '🏆' : '—',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.black38),
                      ),
                    ),
                    Expanded(
                      child: Text(s.wins(match.winCounts[seat]),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Palette.textBrown)),
                    ),
                  ] else ...[
                    SizedBox(
                      width: 80,
                      child: Text(
                        result.deltas[seat] == 0
                            ? '—'
                            : '${result.deltas[seat] > 0 ? '+' : ''}${_fmt(result.deltas[seat])}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: result.deltas[seat] > 0
                              ? Palette.mintDark
                              : result.deltas[seat] < 0
                                  ? Palette.pinkDark
                                  : Colors.black38,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(s.points(_fmt(match.scores[seat])),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Palette.textBrown)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 대국 종료: 최종 순위와 새 대국/메인 버튼.
  Widget _finalResult(
      BuildContext context, TableController gc, Strings s, bool simple) {
    final ranking = gc.match.ranking(byWins: simple);
    final medals = ['🥇', '🥈', '🥉', s.fourthPlace];
    return Column(
      children: [
        Text(s.finalRanking,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Palette.textBrown)),
        const SizedBox(height: 8),
        for (var i = 0; i < ranking.length; i++)
          Text(
            '${medals[i]}  ${_avatars[ranking[i]]} ${_nameOf(gc, s, ranking[i])} '
            '· ${simple ? s.wins(gc.match.winCounts[ranking[i]]) : s.points(_fmt(gc.match.scores[ranking[i]]))}',
            style: TextStyle(
              fontSize: i == 0 ? 16 : 14,
              fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
              color: Palette.textBrown,
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gc.canControlRounds)
              ElevatedButton(
                onPressed: gc.newMatch,
                child: Text(s.newMatch),
              ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.toMain),
            ),
          ],
        ),
      ],
    );
  }
}
