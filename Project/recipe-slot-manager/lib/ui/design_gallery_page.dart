import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/change_row.dart';
import 'package:recipe_slot_manager/design/dial_scale.dart';
import 'package:recipe_slot_manager/design/knob_selector.dart';
import 'package:recipe_slot_manager/design/slot_badge.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 디자인 토큰과 컴포넌트를 한 화면에 놓고 조작해 보는 화면.
class DesignGalleryPage extends StatefulWidget {
  const DesignGalleryPage({super.key});

  @override
  State<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends State<DesignGalleryPage> {
  var _highlight = 1.5;
  var _kelvin = 5500.0;
  var _grain = 'weak-small';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        // 기기마다 실제 논리 크기를 확인하려고 둔다 (좁은 화면 기준 크기를 정할 때 쓴다).
        Text(
          '화면 ${size.width.toStringAsFixed(0)} × '
          '${size.height.toStringAsFixed(0)} dp, 배율 ${ratio.toStringAsFixed(1)}',
          style: AppType.label,
        ),
        const SizedBox(height: AppSpacing.lg),
        _section('색', [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (name, color) in const [
                ('background', AppColors.background),
                ('surface', AppColors.surface),
                ('surfaceRaised', AppColors.surfaceRaised),
                ('line', AppColors.line),
                ('text', AppColors.text),
                ('textMuted', AppColors.textMuted),
                ('accent', AppColors.accent),
                ('danger', AppColors.danger),
                ('success', AppColors.success),
                ('brandRed', AppColors.brandRed),
                ('silver', AppColors.silver),
              ])
                _Swatch(name: name, color: color),
            ],
          ),
        ]),
        _section('다이얼', [
          DialScale(
            label: '하이라이트',
            value: _highlight,
            min: -2,
            max: 4,
            step: 0.5,
            onChanged: (v) => setState(() => _highlight = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          DialScale(
            label: '색온도',
            value: _kelvin,
            min: 2500,
            max: 10000,
            step: 10,
            format: (v) => '${v.toInt()}K',
            onChanged: (v) => setState(() => _kelvin = v),
          ),
        ]),
        _section('노브', [
          KnobSelector<String>(
            label: '그레인 효과',
            options: const [
              ('off', '끔'),
              ('weak-small', '약·소'),
              ('strong-small', '강·소'),
              ('weak-large', '약·대'),
              ('strong-large', '강·대'),
            ],
            value: _grain,
            onChanged: (v) => setState(() => _grain = v),
          ),
        ]),
        _section('사용자 설정', [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var slot = 1; slot <= 7; slot++)
                SlotBadge(slot: slot, active: slot == 3),
            ],
          ),
        ]),
        _section('비교', const [
          ChangeRow(
            label: '필름 시뮬레이션',
            before: 'Classic Neg.',
            after: 'Nostalgic Neg.',
          ),
          ChangeRow(label: '하이라이트', before: '-1', after: '+0.5'),
          ChangeRow(label: '색농도', before: '+2', after: '+2'),
        ]),
        _section('버튼', [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              FilledButton(onPressed: () {}, child: const Text('C1–C7에 저장')),
              OutlinedButton(onPressed: () {}, child: const Text('비교')),
              const OutlinedButton(onPressed: null, child: Text('비활성')),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(), style: AppType.label),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.line),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(name, style: AppType.label),
      ],
    );
  }
}
