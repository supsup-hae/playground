import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';

/// 상황별 묶음: C1–C7 에 넣을 레시피 id. 비운 칸(null)은 카메라 슬롯을 그대로 둔다.
final class Loadout {
  Loadout({
    required this.id,
    required this.name,
    required List<String?> slots,
    required this.updatedAt,
    this.deletedAt,
  }) : slots = List.unmodifiable(slots) {
    if (slots.length != FujiProp.slotCount) {
      throw ArgumentError.value(slots, 'slots', 'C1–C7 7칸이 아님');
    }
  }

  /// 슬롯이 7칸이 아니거나 칸에 문자열·null 이 아닌 값이 있으면 [FormatException].
  factory Loadout.fromJson(Object? json) {
    if (json
        case {
          'id': final String id,
          'name': final String name,
          'slots': final List<dynamic> slots,
          'updatedAt': final String updatedAt,
        }
        when id.isNotEmpty &&
            slots.length == FujiProp.slotCount &&
            slots.every((s) => s == null || s is String)) {
      return Loadout(
        id: id,
        name: name,
        slots: slots.cast<String?>(),
        updatedAt: parseUtc(updatedAt),
        deletedAt: switch (json['deletedAt']) {
          null => null,
          final String text => parseUtc(text),
          final other => throw FormatException('deletedAt 형식 오류', other),
        },
      );
    }
    throw FormatException('세트 형식 오류', json);
  }

  final String id;
  final String name;

  /// 슬롯 1–7 순서의 레시피 id.
  final List<String?> slots;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Loadout copyWith({
    String? name,
    List<String?>? slots,
    required DateTime updatedAt,
  }) => Loadout(
    id: id,
    name: name ?? this.name,
    slots: slots ?? this.slots,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  Loadout markDeleted(DateTime now) =>
      Loadout(id: id, name: name, slots: slots, updatedAt: now, deletedAt: now);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slots': slots,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
}
