/// 마작 타일 모델.
///
/// 내부 로직은 전통 마작의 수패 3종(만/통/삭) + 자패 구조를 그대로 쓰고,
/// UI에서 과일/동물/날씨 심볼로 매핑한다 (기획안 "Tile Assets" 참고).
enum Suit {
  man, // 수패 1 → UI: 과일
  pin, // 수패 2 → UI: 동물
  sou, // 수패 3 → UI: 꽃
  honor, // 자패 → UI: 날씨 (해, 구름, 달 등)
}

/// 자패의 rank 의미 (1~7).
enum HonorType { east, south, west, north, white, green, red }

class Tile implements Comparable<Tile> {
  final Suit suit;

  /// 수패: 1~9, 자패: 1~7 (HonorType 순서).
  final int rank;

  const Tile(this.suit, this.rank)
      : assert(rank >= 1),
        assert(suit == Suit.honor ? rank <= 7 : rank <= 9);

  bool get isHonor => suit == Suit.honor;

  HonorType? get honorType => isHonor ? HonorType.values[rank - 1] : null;

  /// 34종 타일을 0~33으로 인코딩한 값. 정렬·판정 로직의 기본 키.
  int get key => suit.index * 9 + (rank - 1);

  static Tile fromKey(int key) =>
      Tile(Suit.values[key ~/ 9], (key % 9) + 1);

  /// 존재하는 타일 종류 수 (수패 27 + 자패 7).
  static const int kindCount = 34;

  static bool isValidKey(int key) =>
      key >= 0 && key < 36 && (key < 27 || key - 27 < 7);

  @override
  int compareTo(Tile other) => key - other.key;

  @override
  bool operator ==(Object other) =>
      other is Tile && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => key;

  @override
  String toString() {
    if (isHonor) {
      const names = ['동', '남', '서', '북', '백', '발', '중'];
      return names[rank - 1];
    }
    const suitNames = {Suit.man: 'm', Suit.pin: 'p', Suit.sou: 's'};
    return '$rank${suitNames[suit]}';
  }
}
