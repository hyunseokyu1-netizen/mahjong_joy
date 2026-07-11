import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../logic/score.dart';
import '../sound/sound_service.dart';
import 'theme.dart';

/// 승리 점수 영수증: 보너스 항목이 딩~ 소리와 함께 한 줄씩 나타나고
/// 소계가 올라가다가, 마지막에 총점이 팡파레와 함께 등장한다.
class ScoreReceipt extends StatefulWidget {
  final ScoreResult score;
  final Strings strings;

  const ScoreReceipt(this.score, {required this.strings, super.key});

  @override
  State<ScoreReceipt> createState() => _ScoreReceiptState();
}

class _ScoreReceiptState extends State<ScoreReceipt> {
  static const _lineInterval = Duration(milliseconds: 550);

  int _revealed = 0;
  bool _showTotal = false;
  int _prevSubtotal = 0;
  int _subtotal = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_lineInterval, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_revealed < widget.score.lines.length) {
      setState(() {
        _revealed++;
        _prevSubtotal = _subtotal;
        _subtotal = widget.score.subtotal(_revealed);
      });
      SoundService.instance.ding();
    } else {
      _timer?.cancel();
      setState(() => _showTotal = true);
      SoundService.instance.total();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.score.lines;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.strings.receiptTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Palette.textBrown)),
          const _DashedDivider(),
          for (var i = 0; i < _revealed; i++)
            _ReceiptLine(lines[i], widget.strings),
          const _DashedDivider(),
          _showTotal ? _totalRow() : _subtotalRow(),
        ],
      ),
    );
  }

  /// 항목이 나타나는 동안 보여주는 소계 (숫자가 굴러 올라간다).
  Widget _subtotalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.strings.subtotalLabel,
            style: const TextStyle(fontSize: 13, color: Colors.black45)),
        TweenAnimationBuilder<double>(
          key: ValueKey(_subtotal),
          tween: Tween(
              begin: _prevSubtotal.toDouble(), end: _subtotal.toDouble()),
          duration: const Duration(milliseconds: 350),
          builder: (context, v, _) => Text(
            widget.strings.points('${v.round()}'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Palette.textBrown),
          ),
        ),
      ],
    );
  }

  /// 총점: 통통 튀며 등장.
  Widget _totalRow() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.strings.totalLabel,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Palette.textBrown)),
          Text(
            widget.strings.points('${widget.score.total}'),
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Palette.pinkDark),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  final ScoreLine line;
  final Strings strings;

  const _ReceiptLine(this.line, this.strings);

  @override
  Widget build(BuildContext context) {
    final isTimes = line.times != null;
    // 왼쪽에서 미끄러져 들어오는 등장
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(-24 * (1 - t), 0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.bonusName(line.bonus, line.count),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Palette.textBrown)),
                  Text(strings.bonusDetail(line.bonus),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
            ),
            Text(
              isTimes ? '×${line.times}' : '+${line.plus}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isTimes ? Palette.pinkDark : Palette.mintDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => const SizedBox(
                width: 4,
                height: 1.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black26),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
