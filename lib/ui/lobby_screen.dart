import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../net/client_session.dart';
import '../net/discovery.dart';
import '../net/host_session.dart';
import '../settings/app_settings.dart';
import 'game_screen.dart';
import 'keep_awake.dart';
import 'table_controller.dart';
import 'theme.dart';

/// 친구와 하기 진입점: 이름 입력 + 방 만들기 / 방 찾기.
class FriendPlayScreen extends StatefulWidget {
  const FriendPlayScreen({super.key});

  @override
  State<FriendPlayScreen> createState() => _FriendPlayScreenState();
}

class _FriendPlayScreenState extends State<FriendPlayScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: context.read<AppSettings>().playerName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _confirmName() {
    final name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
    context.read<AppSettings>().setPlayerName(name);
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.playWithFriends,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Palette.textBrown)),
        backgroundColor: Palette.mint,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📶', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 20),
                TextField(
                  controller: _name,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: s.yourName,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final name = _confirmName();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => HostLobbyScreen(hostName: name)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    child: Text('🏠 ${s.createRoom}',
                        style: const TextStyle(fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    final name = _confirmName();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => JoinScreen(playerName: name)));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.textBrown,
                    side: const BorderSide(color: Palette.mintDark, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    child: Text('🔍 ${s.findRooms}',
                        style: const TextStyle(fontSize: 17)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 호스트 대기실: 방을 열고 참가자를 기다린다.
class HostLobbyScreen extends StatefulWidget {
  final String hostName;

  const HostLobbyScreen({super.key, required this.hostName});

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  late final NetHostController _host;

  @override
  void initState() {
    super.initState();
    KeepAwake.acquire(); // 화면이 꺼지면 방이 사라지므로 항상 켜 둔다
    _host = NetHostController(
      hostName: widget.hostName,
      simpleModeOn: context.read<AppSettings>().simpleMode,
    );
    _host.open();
  }

  @override
  void dispose() {
    KeepAwake.release();
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.roomOf(widget.hostName),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Palette.textBrown)),
        backgroundColor: Palette.mint,
      ),
      body: AnimatedBuilder(
        animation: _host,
        builder: (context, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var seat = 0; seat < _host.names.length; seat++)
                    _seatRow(seat),
                  const SizedBox(height: 12),
                  Text(s.waitingForPlayers,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black45)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _host.startGame();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            ChangeNotifierProvider<TableController>.value(
                          value: _host,
                          child: const GameScreen(),
                        ),
                      ));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Text(s.startWithAi,
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seatRow(int seat) {
    final name = _host.names[seat];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: name == null ? 0.4 : 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: name == null ? Colors.black12 : Palette.mint, width: 2),
      ),
      child: Row(
        children: [
          Text(seat == 0 ? '👑' : (name == null ? '🤖' : '🙂'),
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(name ?? 'AI',
              style: TextStyle(
                fontWeight: name == null ? FontWeight.normal : FontWeight.bold,
                color: name == null ? Colors.black38 : Palette.textBrown,
              )),
        ],
      ),
    );
  }
}

/// 방 찾기 + 참가 대기실.
class JoinScreen extends StatefulWidget {
  final String playerName;

  const JoinScreen({super.key, required this.playerName});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final RoomFinder _finder = RoomFinder();
  late final TextEditingController _name;
  NetClientController? _client;
  bool _inGame = false;

  @override
  void initState() {
    super.initState();
    KeepAwake.acquire(); // 대기/게임 중 화면 꺼짐(→ 연결 끊김) 방지
    _name = TextEditingController(text: widget.playerName);
    _finder.start();
  }

  @override
  void dispose() {
    KeepAwake.release();
    _name.dispose();
    _finder.dispose();
    _client?.removeListener(_onClientChanged);
    _client?.dispose();
    super.dispose();
  }

  void _join(RoomInfo room) {
    final name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
    context.read<AppSettings>().setPlayerName(name);
    final client = NetClientController();
    client.addListener(_onClientChanged);
    setState(() => _client = client);
    client.connect(room.address, room.port, name: name);
  }

  void _onClientChanged() {
    final client = _client;
    if (client == null || !mounted) return;

    if (client.status == NetClientStatus.playing && !_inGame) {
      _inGame = true;
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<TableController>.value(
              value: client,
              child: const GameScreen(),
            ),
          ))
          .then((_) => _inGame = false);
    } else if (client.status == NetClientStatus.disconnected) {
      final s = context.read<AppSettings>().strings;
      if (_inGame) {
        Navigator.of(context).pop(); // 게임 화면 닫기
        _inGame = false;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.connectionLost)));
      client.removeListener(_onClientChanged);
      client.dispose();
      setState(() => _client = null);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.findRooms,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Palette.textBrown)),
        backgroundColor: Palette.mint,
      ),
      body: _client == null ? _roomList(s) : _waitingRoom(s),
    );
  }

  Widget _roomList(Strings s) {
    return AnimatedBuilder(
      animation: _finder,
      builder: (context, _) {
        final rooms = _finder.rooms;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                controller: _name,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: s.yourName,
                  counterText: '',
                  isDense: true,
                  prefixIcon: const Icon(Icons.badge_outlined,
                      color: Palette.mintDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Palette.mintDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.searchingRooms,
                        style: const TextStyle(color: Palette.textBrown)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rooms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.noRoomsFound,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black45)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final room in rooms)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Palette.mint, width: 2),
                            ),
                            child: ListTile(
                              leading: const Text('🀄',
                                  style: TextStyle(fontSize: 26)),
                              title: Text(s.roomOf(room.name),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Palette.textBrown)),
                              subtitle: Text('${room.humans}/${room.max}'),
                              trailing: ElevatedButton(
                                onPressed: room.humans >= room.max
                                    ? null
                                    : () => _join(room),
                                child: Text(s.joinBtn),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _waitingRoom(Strings s) {
    final client = _client!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Palette.mintDark),
          const SizedBox(height: 20),
          Text(s.waitingHostStart,
              style: const TextStyle(color: Palette.textBrown)),
          const SizedBox(height: 16),
          for (final name in client.lobbyNames)
            if (name != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('🙂 $name',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Palette.textBrown)),
              ),
        ],
      ),
    );
  }
}
