import '../logic/score.dart';

/// 지원 언어. 기기 언어가 목록에 없으면 영어.
enum AppLang { ko, zh, en }

AppLang langFromCode(String code) => switch (code) {
      'ko' => AppLang.ko,
      'zh' => AppLang.zh,
      _ => AppLang.en,
    };

/// 언어 선택 버튼에 쓰는 자기 언어 표기 (항상 고정).
const Map<AppLang, String> langNativeNames = {
  AppLang.ko: '한국어',
  AppLang.zh: '中文',
  AppLang.en: 'English',
};

Strings stringsOf(AppLang lang) => switch (lang) {
      AppLang.ko => _ko,
      AppLang.zh => _zh,
      AppLang.en => _en,
    };

/// 화면 문자열 모음. 템플릿의 {자리표시자}는 메서드가 채운다.
class Strings {
  // 홈
  final String tagline;
  final String playWithAi;
  final String playWithFriends;
  final String howToPlayBtn;
  final String languageLabel;
  final String beginnerTitle;
  final String beginnerSubtitle;

  // 친구와 하기 (LAN)
  final String yourName;
  final String createRoom;
  final String findRooms;
  final String _roomFmt; // {name}
  final String startWithAi;
  final String waitingForPlayers;
  final String searchingRooms;
  final String noRoomsFound;
  final String joinBtn;
  final String waitingHostStart;
  final String waitingHostNext;
  final String connectionLost;
  final String reconnecting;
  final String _decidingFmt; // {name}
  final String _playerLeftFmt; // {name}
  final String _playerRejoinedFmt; // {name}
  final String roomFull;

  // 게임 화면
  final List<String> playerNames;
  final String homeTooltip;
  final String muteTooltip;
  final String unmuteTooltip;
  final String _roundFmt; // {c}, {t}
  final String _wallLeftFmt; // {n}
  final String waitingLabel;
  final String chooseDiscard;
  final String canComplete;
  final String completeBtn;
  final String claimQuestion;
  final String passBtn;
  final String _pointsFmt; // {n}
  final String _winsFmt; // {n}

  // 결과
  final String drawTitle;
  final String iWonTitle;
  final String _otherWonFmt; // {name}
  final String _ronSubFmt; // {name}, {pts}
  final String _tsumoSubFmt; // {pts}
  final String _simpleRonFmt; // {name}
  final String simpleTsumoSub;
  final String finalRanking;
  final String fourthPlace;
  final String newMatch;
  final String toMain;
  final String _nextRoundFmt; // {c}, {t}

  // 영수증
  final String receiptTitle;
  final String subtotalLabel;
  final String totalLabel;

  // 보너스
  final Map<ScoreBonus, String> _bonusNames;
  final Map<ScoreBonus, String> _bonusDetails; // lastCatch에 {n}
  final Map<ScoreBonus, String> bonusRewards;

  // 설명서
  final String manualTitle;
  final String goalTitle;
  final String goalBody;
  final String straightName;
  final String straightDesc;
  final String tripleName;
  final String tripleDesc;
  final String headName;
  final String headDesc;
  final String flowTitle;
  final String flowBody;
  final String claimTitle;
  final String claimBody;
  final String completeTitle;
  final String completeBody;
  final String scoreTitle;
  final String _scoreBodyFmt; // {start}, {rounds}, {base}
  final String bonusTitle;
  final String bonusIntro;
  final String plusHeader;
  final String timesHeader;
  final String tilesTitle;
  final String tilesBody;
  final String meldLabel;
  final String headLabel;

  const Strings({
    required this.tagline,
    required this.playWithAi,
    required this.playWithFriends,
    required this.howToPlayBtn,
    required this.languageLabel,
    required this.beginnerTitle,
    required this.beginnerSubtitle,
    required this.yourName,
    required this.createRoom,
    required this.findRooms,
    required this._roomFmt,
    required this.startWithAi,
    required this.waitingForPlayers,
    required this.searchingRooms,
    required this.noRoomsFound,
    required this.joinBtn,
    required this.waitingHostStart,
    required this.waitingHostNext,
    required this.connectionLost,
    required this.reconnecting,
    required this._decidingFmt,
    required this._playerLeftFmt,
    required this._playerRejoinedFmt,
    required this.roomFull,
    required this.playerNames,
    required this.homeTooltip,
    required this.muteTooltip,
    required this.unmuteTooltip,
    required this._roundFmt,
    required this._wallLeftFmt,
    required this.waitingLabel,
    required this.chooseDiscard,
    required this.canComplete,
    required this.completeBtn,
    required this.claimQuestion,
    required this.passBtn,
    required this._pointsFmt,
    required this._winsFmt,
    required this.drawTitle,
    required this.iWonTitle,
    required this._otherWonFmt,
    required this._ronSubFmt,
    required this._tsumoSubFmt,
    required this._simpleRonFmt,
    required this.simpleTsumoSub,
    required this.finalRanking,
    required this.fourthPlace,
    required this.newMatch,
    required this.toMain,
    required this._nextRoundFmt,
    required this.receiptTitle,
    required this.subtotalLabel,
    required this.totalLabel,
    required this._bonusNames,
    required this._bonusDetails,
    required this.bonusRewards,
    required this.manualTitle,
    required this.goalTitle,
    required this.goalBody,
    required this.straightName,
    required this.straightDesc,
    required this.tripleName,
    required this.tripleDesc,
    required this.headName,
    required this.headDesc,
    required this.flowTitle,
    required this.flowBody,
    required this.claimTitle,
    required this.claimBody,
    required this.completeTitle,
    required this.completeBody,
    required this.scoreTitle,
    required this._scoreBodyFmt,
    required this.bonusTitle,
    required this.bonusIntro,
    required this.plusHeader,
    required this.timesHeader,
    required this.tilesTitle,
    required this.tilesBody,
    required this.meldLabel,
    required this.headLabel,
  });

  String roomOf(String name) => _roomFmt.replaceAll('{name}', name);

  String decidingOf(String name) => _decidingFmt.replaceAll('{name}', name);

  String playerLeft(String name) => _playerLeftFmt.replaceAll('{name}', name);

  String playerRejoined(String name) =>
      _playerRejoinedFmt.replaceAll('{name}', name);

  String roundOf(int current, int total) =>
      _roundFmt.replaceAll('{c}', '$current').replaceAll('{t}', '$total');

  String wallLeft(int n) => _wallLeftFmt.replaceAll('{n}', '$n');

  /// [formatted]는 천 단위 구분이 끝난 숫자 문자열.
  String points(String formatted) => _pointsFmt.replaceAll('{n}', formatted);

  String wins(int n) => _winsFmt.replaceAll('{n}', '$n');

  String otherWon(String name) => _otherWonFmt.replaceAll('{name}', name);

  String ronSub(String name, String pts) =>
      _ronSubFmt.replaceAll('{name}', name).replaceAll('{pts}', pts);

  String tsumoSub(String pts) => _tsumoSubFmt.replaceAll('{pts}', pts);

  String simpleRonSub(String name) => _simpleRonFmt.replaceAll('{name}', name);

  String nextRound(int current, int total) =>
      _nextRoundFmt.replaceAll('{c}', '$current').replaceAll('{t}', '$total');

  String bonusName(ScoreBonus b, [int count = 1]) =>
      count > 1 ? '${_bonusNames[b]!} ×$count' : _bonusNames[b]!;

  String bonusDetail(ScoreBonus b) =>
      _bonusDetails[b]!.replaceAll('{n}', '$lastCatchWallCount');

  String scoreBody(String start, int rounds, int base) => _scoreBodyFmt
      .replaceAll('{start}', start)
      .replaceAll('{rounds}', '$rounds')
      .replaceAll('{base}', '$base');
}

const _ko = Strings(
  tagline: '마작 조이 — 짝 맞추기의 재미만 남긴 심플 마작',
  playWithAi: 'AI와 하기',
  playWithFriends: '친구와 하기',
  howToPlayBtn: '게임 설명서 📖',
  languageLabel: '언어',
  beginnerTitle: '초보자 모드',
  beginnerSubtitle: '점수 없이 짝 맞추기만 즐겨요',
  yourName: '내 이름',
  createRoom: '방 만들기',
  findRooms: '방 찾기',
  roomFmt: '{name}의 방',
  startWithAi: '시작하기 (빈자리는 AI)',
  waitingForPlayers: '같은 Wi-Fi의 친구를 기다리는 중...',
  searchingRooms: '같은 Wi-Fi에서 방을 찾는 중...',
  noRoomsFound: '아직 방이 없어요. 친구가 방을 만들면 여기에 나타나요.',
  joinBtn: '참가',
  waitingHostStart: '방장이 시작하기를 기다리는 중...',
  waitingHostNext: '방장을 기다리는 중...',
  connectionLost: '연결이 끊어졌어요',
  reconnecting: '연결이 불안정해요 — 다시 연결하는 중...',
  decidingFmt: '{name} 고르는 중...',
  playerLeftFmt: '👋 {name}님이 나갔어요 — AI가 이어서 둘게요',
  playerRejoinedFmt: '🎉 {name}님이 돌아왔어요!',
  roomFull: '방이 가득 찼어요',
  playerNames: ['나', '토끼', '곰돌이', '야옹이'],
  homeTooltip: '메인으로',
  muteTooltip: '소리 끄기',
  unmuteTooltip: '소리 켜기',
  roundFmt: '{c}판 / {t}',
  wallLeftFmt: '남은 패 {n}장',
  waitingLabel: '✨ 기다리는 패: ',
  chooseDiscard: '버릴 패를 골라주세요',
  canComplete: '완성할 수 있어요!',
  completeBtn: '완성! 🎉',
  claimQuestion: '이 패, 가져갈까요?',
  passBtn: '패스',
  pointsFmt: '{n}점',
  winsFmt: '{n}승',
  drawTitle: '유국 — 이번 판은 무승부',
  iWonTitle: '완성! 내가 이겼어요!',
  otherWonFmt: '{name}가 완성했어요',
  ronSubFmt: '{name}가 버린 패로 완성 — {pts} 전액 지불',
  tsumoSubFmt: '스스로 뽑아서 완성 — 셋이서 {pts}을 나눠 지불',
  simpleRonFmt: '{name}가 버린 패로 완성!',
  simpleTsumoSub: '스스로 뽑아서 완성!',
  finalRanking: '🏁 최종 순위',
  fourthPlace: '4위',
  newMatch: '새 대국',
  toMain: '메인으로',
  nextRoundFmt: '다음 판 ({c}/{t})',
  receiptTitle: '🧾 점수 영수증',
  subtotalLabel: '소계',
  totalLabel: '총점 🎉',
  bonusNames: {
    ScoreBonus.base: '기본 완성',
    ScoreBonus.weatherSet: '날씨 세트',
    ScoreBonus.selfDraw: '내가 뽑았다!',
    ScoreBonus.allStraight: '올 스트레이트',
    ScoreBonus.lastCatch: '라스트 캐치',
    ScoreBonus.solo: '혼자 힘으로',
    ScoreBonus.halfHalf: '하프 앤 하프',
    ScoreBonus.allTriple: '올 트리플',
    ScoreBonus.oneColor: '원 컬러',
    ScoreBonus.allWeather: '올 웨더',
  },
  bonusDetails: {
    ScoreBonus.base: '몸통 4개 + 머리 1개',
    ScoreBonus.weatherSet: '같은 날씨 패 3장 몸통',
    ScoreBonus.selfDraw: '스스로 뽑은 패로 완성',
    ScoreBonus.allStraight: '몸통 4개가 전부 연속 숫자',
    ScoreBonus.lastCatch: '남은 패 {n}장 이하에서 극적 완성',
    ScoreBonus.solo: '뺏어오기 없이 완성',
    ScoreBonus.halfHalf: '숫자 패 한 종류 + 날씨 패',
    ScoreBonus.allTriple: '몸통 4개가 전부 같은 패 3장',
    ScoreBonus.oneColor: '한 종류의 숫자 패로만 완성',
    ScoreBonus.allWeather: '전부 날씨 패로만 완성!',
  },
  bonusRewards: {
    ScoreBonus.weatherSet: '하나당 +50점',
    ScoreBonus.selfDraw: '+100점',
    ScoreBonus.allStraight: '+200점',
    ScoreBonus.lastCatch: '+200점',
    ScoreBonus.solo: '×2',
    ScoreBonus.halfHalf: '×2',
    ScoreBonus.allTriple: '×3',
    ScoreBonus.oneColor: '×5',
  },
  manualTitle: '게임 설명서',
  goalTitle: '🎯 목표',
  goalBody: '패 14장을 "몸통 4개 + 머리 1개"로 만들면 승리!\n'
      '족보도 역도 없어요. 이 한 가지 조합만 기억하면 됩니다.',
  straightName: '스트레이트 (몸통)',
  straightDesc: '같은 종류 연속 숫자 3개',
  tripleName: '트리플 (몸통)',
  tripleDesc: '똑같은 패 3개',
  headName: '머리',
  headDesc: '똑같은 패 2개',
  flowTitle: '🔄 진행',
  flowBody: '내 차례가 되면 덱에서 1장 뽑고, 필요 없는 패 1장을 골라 버립니다.\n'
      '패가 완성에 가까워지면 화면에 ✨기다리는 패✨가 표시돼요.',
  claimTitle: '⚡ 뺏어오기',
  claimBody: '누가 버리든 그 패로 몸통을 완성할 수 있다면 가져올 수 있어요!\n'
      '가져온 몸통은 모두에게 공개되고, 대신 내 패 1장을 버립니다.',
  completeTitle: '🏆 완성',
  completeBody: '내가 뽑은 패로든, 남이 버린 패로든 3-3-3-3-2가 갖춰지는 순간 완성을 선언하세요.',
  scoreTitle: '💰 점수',
  scoreBodyFmt: '모두 {start}점으로 시작해 {rounds}판을 겨룹니다.\n\n'
      '• 완성하면 점수 영수증이 나와요: 기본 {base}점 + 보너스!\n'
      '• 남이 버린 패로 완성 → 그 패를 버린 사람이 전액 지불!\n'
      '• 스스로 뽑아서 완성 → 나머지 세 명이 똑같이 나눠 지불.\n'
      '• 0점 이하로 떨어진 사람이 나오면 대국이 바로 끝납니다.',
  bonusTitle: '🌟 보너스',
  bonusIntro: '먼저 더하고, 그다음 곱해요!',
  plusHeader: '더하기 보너스',
  timesHeader: '곱하기 보너스',
  tilesTitle: '🀄 타일 안내',
  tilesBody: '숫자 패 3종(귤🍊 · 곰🐻 · 꽃🌸)은 1~9가 각 4장씩 있어요.\n'
      '날씨 패 7종은 숫자가 없어서 트리플/머리로만 쓸 수 있습니다.',
  meldLabel: '몸통',
  headLabel: '머리',
);

const _en = Strings(
  tagline: 'Mahjong Joy — simple mahjong, just the fun of matching',
  playWithAi: 'Play with AI',
  playWithFriends: 'Play with Friends',
  howToPlayBtn: 'How to Play 📖',
  languageLabel: 'Language',
  beginnerTitle: 'Beginner Mode',
  beginnerSubtitle: 'No scoring — just match and win',
  yourName: 'Your Name',
  createRoom: 'Create Room',
  findRooms: 'Find Rooms',
  roomFmt: "{name}'s Room",
  startWithAi: 'Start (AI fills empty seats)',
  waitingForPlayers: 'Waiting for friends on this Wi-Fi...',
  searchingRooms: 'Searching for rooms on this Wi-Fi...',
  noRoomsFound: 'No rooms yet. They appear here when a friend creates one.',
  joinBtn: 'Join',
  waitingHostStart: 'Waiting for the host to start...',
  waitingHostNext: 'Waiting for the host...',
  connectionLost: 'Connection lost',
  reconnecting: 'Connection unstable — reconnecting...',
  decidingFmt: '{name} is deciding...',
  playerLeftFmt: '👋 {name} left — AI will take over',
  playerRejoinedFmt: '🎉 {name} is back!',
  roomFull: 'The room is full',
  playerNames: ['Me', 'Rabbit', 'Teddy', 'Kitty'],
  homeTooltip: 'Main menu',
  muteTooltip: 'Mute',
  unmuteTooltip: 'Unmute',
  roundFmt: 'Round {c} / {t}',
  wallLeftFmt: '{n} tiles left',
  waitingLabel: '✨ Waiting for: ',
  chooseDiscard: 'Choose a tile to discard',
  canComplete: 'You can win!',
  completeBtn: 'Win! 🎉',
  claimQuestion: 'Take this tile?',
  passBtn: 'Pass',
  pointsFmt: '{n} pts',
  winsFmt: '{n} wins',
  drawTitle: 'Draw — nobody won this round',
  iWonTitle: 'Complete! I won!',
  otherWonFmt: '{name} won the round',
  ronSubFmt: "Won on {name}'s discard — {name} pays {pts}",
  tsumoSubFmt: 'Self-drawn win — the other three split {pts}',
  simpleRonFmt: "Won on {name}'s discard!",
  simpleTsumoSub: 'Self-drawn win!',
  finalRanking: '🏁 Final Ranking',
  fourthPlace: '4th',
  newMatch: 'New Match',
  toMain: 'Main Menu',
  nextRoundFmt: 'Next Round ({c}/{t})',
  receiptTitle: '🧾 Score Receipt',
  subtotalLabel: 'Subtotal',
  totalLabel: 'Total 🎉',
  bonusNames: {
    ScoreBonus.base: 'Base Win',
    ScoreBonus.weatherSet: 'Weather Set',
    ScoreBonus.selfDraw: 'Self-Draw!',
    ScoreBonus.allStraight: 'All Straights',
    ScoreBonus.lastCatch: 'Last Catch',
    ScoreBonus.solo: 'All By Myself',
    ScoreBonus.halfHalf: 'Half & Half',
    ScoreBonus.allTriple: 'All Triples',
    ScoreBonus.oneColor: 'One Color',
    ScoreBonus.allWeather: 'All Weather',
  },
  bonusDetails: {
    ScoreBonus.base: '4 sets + 1 pair',
    ScoreBonus.weatherSet: 'Three of the same weather tile',
    ScoreBonus.selfDraw: 'Won with a tile you drew yourself',
    ScoreBonus.allStraight: 'All 4 sets are straights',
    ScoreBonus.lastCatch: 'Won with {n} or fewer tiles left',
    ScoreBonus.solo: 'No claimed tiles',
    ScoreBonus.halfHalf: 'One number suit + weather tiles',
    ScoreBonus.allTriple: 'All 4 sets are triples',
    ScoreBonus.oneColor: 'One number suit only',
    ScoreBonus.allWeather: 'Weather tiles only!',
  },
  bonusRewards: {
    ScoreBonus.weatherSet: '+50 pts each',
    ScoreBonus.selfDraw: '+100 pts',
    ScoreBonus.allStraight: '+200 pts',
    ScoreBonus.lastCatch: '+200 pts',
    ScoreBonus.solo: '×2',
    ScoreBonus.halfHalf: '×2',
    ScoreBonus.allTriple: '×3',
    ScoreBonus.oneColor: '×5',
  },
  manualTitle: 'How to Play',
  goalTitle: '🎯 Goal',
  goalBody: 'Arrange 14 tiles into "4 sets + 1 pair" and you win!\n'
      'No hands or combos to memorize — this one shape is all you need.',
  straightName: 'Straight (set)',
  straightDesc: '3 consecutive numbers of one suit',
  tripleName: 'Triple (set)',
  tripleDesc: '3 identical tiles',
  headName: 'Pair',
  headDesc: '2 identical tiles',
  flowTitle: '🔄 Turns',
  flowBody: 'On your turn, draw one tile from the deck and discard one you '
      "don't need.\nWhen you're close to winning, your ✨waiting tiles✨ "
      'appear on screen.',
  claimTitle: '⚡ Claiming',
  claimBody: 'If a discarded tile completes one of your sets, you can take '
      'it — no matter who discarded it!\nThe claimed set is revealed to '
      'everyone, and you discard one tile in return.',
  completeTitle: '🏆 Winning',
  completeBody: 'The moment you have 3-3-3-3-2 — from your own draw or '
      "someone's discard — declare your win!",
  scoreTitle: '💰 Scoring',
  scoreBodyFmt: 'Everyone starts with {start} pts and plays {rounds} rounds.'
      '\n\n'
      '• Win a round and a score receipt appears: base {base} pts + bonuses!\n'
      '• Win on a discard → the discarder pays the full amount!\n'
      '• Self-drawn win → the other three split the payment.\n'
      '• The match ends immediately if anyone drops to 0.',
  bonusTitle: '🌟 Bonuses',
  bonusIntro: 'Add first, then multiply!',
  plusHeader: 'Plus bonuses',
  timesHeader: 'Multiplier bonuses',
  tilesTitle: '🀄 Tiles',
  tilesBody: 'The 3 number suits (orange 🍊 · bear 🐻 · flower 🌸) run 1–9 '
      'with 4 of each.\nThe 7 weather tiles have no numbers, so they only '
      'work as triples or pairs.',
  meldLabel: 'set',
  headLabel: 'pair',
);

const _zh = Strings(
  tagline: '麻将乐 — 只留下配对乐趣的简单麻将',
  playWithAi: '和AI玩',
  playWithFriends: '和朋友玩',
  howToPlayBtn: '游戏说明 📖',
  languageLabel: '语言',
  beginnerTitle: '新手模式',
  beginnerSubtitle: '不计分，只享受配对',
  yourName: '我的名字',
  createRoom: '创建房间',
  findRooms: '查找房间',
  roomFmt: '{name}的房间',
  startWithAi: '开始（空位由AI补上）',
  waitingForPlayers: '正在等待同一Wi-Fi的朋友...',
  searchingRooms: '正在同一Wi-Fi中查找房间...',
  noRoomsFound: '还没有房间。朋友创建房间后会显示在这里。',
  joinBtn: '加入',
  waitingHostStart: '等待房主开始...',
  waitingHostNext: '等待房主...',
  connectionLost: '连接断开了',
  reconnecting: '连接不稳定 — 正在重新连接...',
  decidingFmt: '{name}正在选择...',
  playerLeftFmt: '👋 {name}退出了 — 由AI接管',
  playerRejoinedFmt: '🎉 {name}回来了！',
  roomFull: '房间已满',
  playerNames: ['我', '兔子', '小熊', '小猫'],
  homeTooltip: '回主页',
  muteTooltip: '关闭声音',
  unmuteTooltip: '打开声音',
  roundFmt: '第{c}局 / {t}',
  wallLeftFmt: '剩余 {n} 张',
  waitingLabel: '✨ 听牌: ',
  chooseDiscard: '请选择要打出的牌',
  canComplete: '可以和牌啦！',
  completeBtn: '和了！🎉',
  claimQuestion: '要这张牌吗？',
  passBtn: '过',
  pointsFmt: '{n}分',
  winsFmt: '{n}胜',
  drawTitle: '流局 — 本局平局',
  iWonTitle: '和了！我赢啦！',
  otherWonFmt: '{name}和牌了',
  ronSubFmt: '用{name}打出的牌和牌 — {name}全额支付{pts}',
  tsumoSubFmt: '自摸和牌 — 其余三人平分支付{pts}',
  simpleRonFmt: '用{name}打出的牌和牌！',
  simpleTsumoSub: '自摸和牌！',
  finalRanking: '🏁 最终排名',
  fourthPlace: '第4名',
  newMatch: '再来一局',
  toMain: '回主页',
  nextRoundFmt: '下一局 ({c}/{t})',
  receiptTitle: '🧾 得分小票',
  subtotalLabel: '小计',
  totalLabel: '总分 🎉',
  bonusNames: {
    ScoreBonus.base: '基本和牌',
    ScoreBonus.weatherSet: '天气组',
    ScoreBonus.selfDraw: '自摸！',
    ScoreBonus.allStraight: '全顺子',
    ScoreBonus.lastCatch: '最后一搏',
    ScoreBonus.solo: '全靠自己',
    ScoreBonus.halfHalf: '一半一半',
    ScoreBonus.allTriple: '全刻子',
    ScoreBonus.oneColor: '一色到底',
    ScoreBonus.allWeather: '全天气',
  },
  bonusDetails: {
    ScoreBonus.base: '4组 + 1对',
    ScoreBonus.weatherSet: '3张相同的天气牌',
    ScoreBonus.selfDraw: '用自己摸的牌和牌',
    ScoreBonus.allStraight: '4组全是连续数字',
    ScoreBonus.lastCatch: '剩余{n}张以内惊险和牌',
    ScoreBonus.solo: '没有吃碰，独立完成',
    ScoreBonus.halfHalf: '一种数字牌 + 天气牌',
    ScoreBonus.allTriple: '4组全是相同的3张',
    ScoreBonus.oneColor: '只用一种数字牌',
    ScoreBonus.allWeather: '全部用天气牌和牌！',
  },
  bonusRewards: {
    ScoreBonus.weatherSet: '每组+50分',
    ScoreBonus.selfDraw: '+100分',
    ScoreBonus.allStraight: '+200分',
    ScoreBonus.lastCatch: '+200分',
    ScoreBonus.solo: '×2',
    ScoreBonus.halfHalf: '×2',
    ScoreBonus.allTriple: '×3',
    ScoreBonus.oneColor: '×5',
  },
  manualTitle: '游戏说明',
  goalTitle: '🎯 目标',
  goalBody: '把14张牌组成"4组 + 1对"就赢了！\n没有复杂的番种，只要记住这一个组合。',
  straightName: '顺子（组）',
  straightDesc: '同种类连续的3个数字',
  tripleName: '刻子（组）',
  tripleDesc: '3张相同的牌',
  headName: '对子',
  headDesc: '2张相同的牌',
  flowTitle: '🔄 流程',
  flowBody: '轮到你时，从牌堆摸1张，再打出1张不需要的牌。\n快要和牌时，屏幕会显示✨听牌✨。',
  claimTitle: '⚡ 吃碰',
  claimBody: '不管谁打出的牌，只要能凑成你的一组，就可以拿过来！\n'
      '拿来的组会亮给大家看，然后你打出1张牌。',
  completeTitle: '🏆 和牌',
  completeBody: '不管是自己摸的还是别人打的，凑齐3-3-3-3-2的瞬间就宣布和牌吧！',
  scoreTitle: '💰 计分',
  scoreBodyFmt: '所有人以{start}分起步，共打{rounds}局。\n\n'
      '• 和牌后会出现得分小票：基础{base}分 + 奖励！\n'
      '• 用别人打出的牌和牌 → 打牌的人全额支付！\n'
      '• 自摸 → 其余三人平分支付。\n'
      '• 有人跌到0分以下，比赛立即结束。',
  bonusTitle: '🌟 奖励',
  bonusIntro: '先加，再乘！',
  plusHeader: '加分奖励',
  timesHeader: '倍数奖励',
  tilesTitle: '🀄 牌型介绍',
  tilesBody: '数字牌有3种（橘子🍊 · 小熊🐻 · 花🌸），1~9各4张。\n'
      '7种天气牌没有数字，只能用作刻子或对子。',
  meldLabel: '组',
  headLabel: '对',
);
