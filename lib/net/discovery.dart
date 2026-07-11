import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'protocol.dart';

/// 발견된 방 하나.
class RoomInfo {
  final String name;
  final InternetAddress address;
  final int port;
  final int humans;
  final int max;
  DateTime lastSeen;

  RoomInfo({
    required this.name,
    required this.address,
    required this.port,
    required this.humans,
    required this.max,
    required this.lastSeen,
  });

  String get key => '${address.address}:$port';
}

/// 같은 네트워크의 방 찾기: 1초마다 UDP 브로드캐스트 핑을 보내고,
/// 호스트의 응답을 모아 목록으로 유지한다 (4초 무응답이면 제거).
class RoomFinder extends ChangeNotifier {
  final Map<String, RoomInfo> _rooms = {};
  RawDatagramSocket? _socket;
  Timer? _timer;
  bool _disposed = false;

  List<RoomInfo> get rooms => _rooms.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _socket!.listen(_onEvent);
    } catch (_) {
      return; // 소켓을 못 열면 방 목록이 비어 있을 뿐, 앱은 계속 동작.
    }
    _ping();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _ping();
      _prune();
    });
  }

  void _ping() {
    try {
      _socket?.send(utf8.encode(discoveryPing),
          InternetAddress('255.255.255.255'), discoveryPort);
    } catch (_) {}
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;
    String text;
    try {
      text = utf8.decode(datagram.data);
    } catch (_) {
      return;
    }
    if (!text.startsWith(discoveryReplyPrefix)) return;
    try {
      final info = jsonDecode(text.substring(discoveryReplyPrefix.length))
          as Map<String, dynamic>;
      final room = RoomInfo(
        name: info['name'] as String,
        address: datagram.address,
        port: info['port'] as int,
        humans: info['n'] as int,
        max: info['max'] as int,
        lastSeen: DateTime.now(),
      );
      _rooms[room.key] = room;
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 4));
    final before = _rooms.length;
    _rooms.removeWhere((_, room) => room.lastSeen.isBefore(cutoff));
    if (_rooms.length != before && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _socket?.close();
    super.dispose();
  }
}
