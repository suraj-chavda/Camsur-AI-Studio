import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/section_header.dart';
import '../../core/theme/app_icons.dart';

class SupportView extends StatefulWidget {
  const SupportView({super.key});

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  static const _faqs = [
    (
      'How do credits work?',
      'Each AI tool costs credits shown on the tool card. Top up anytime from Wallet.'
    ),
    (
      'Are my photos private?',
      'Uploads are tied to your account and used only to generate your results.'
    ),
    (
      'Which tools are available?',
      'Headshots, LinkedIn, Indian Passport, Background Remover — more coming soon.'
    ),
    (
      'Can I save or share results?',
      'Yes — use Share or Save on any completed creation from History or the result screen.'
    ),
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final filtered = _faqs
        .where((f) {
          if (_query.trim().isEmpty) return true;
          final q = _query.toLowerCase();
          return f.$1.toLowerCase().contains(q) ||
              f.$2.toLowerCase().contains(q);
        })
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Help & Support'),
      ),
      body: AdaptiveContainer(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.xxl),
          children: [
            AppCard(
              lite: true,
              elevated: false,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: context.texts.bodyMedium?.copyWith(
                  color: AppColors.text(b),
                ),
                decoration: InputDecoration(
                  hintText: 'Search help…',
                  hintStyle: context.texts.bodyMedium?.copyWith(
                    color: AppColors.textMuted(b),
                  ),
                  prefixIcon: Icon(
                    AppIcons.search,
                    color: AppColors.textMuted(b),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.section),
            const SectionHeader(title: 'FAQs'),
            const SizedBox(height: AppSpace.listGap),
            if (filtered.isEmpty)
              AppCard(
                lite: true,
                elevated: true,
                child: Text(
                  'No matching articles',
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(b),
                  ),
                ),
              )
            else
              ...filtered.asMap().entries.map((e) {
                return FadeSlideIn(
                  index: e.key,
                  maxAnimated: 6,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: _FaqTile(
                      question: e.value.$1,
                      answer: e.value.$2,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return AppCard(
      lite: true,
      elevated: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _open = !_open);
              },
              borderRadius: AppRadius.lgAll,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: context.texts.titleSmall?.copyWith(
                          color: AppColors.text(b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        AppIcons.chevronDown,
                        color: AppColors.textMuted(b),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      0,
                      AppSpace.md,
                      AppSpace.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          height: 1,
                          color: AppColors.border(b).withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          widget.answer,
                          style: context.texts.bodyMedium?.copyWith(
                            color: AppColors.textSecondary(b),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
