import 'package:billeasy/services/remote_config_service.dart';
import 'package:flutter/material.dart';
import 'package:billeasy/theme/app_colors.dart';

/// Supported languages (only those with complete native translations).
enum AppLanguage {
  english,
  hindi,
  tamil,
  gujarati,
  assamese,
}

/// Metadata for each language displayed on the selection screen.
class _LangMeta {
  const _LangMeta(this.lang, this.nativeLabel, this.englishLabel, this.emoji);
  final AppLanguage lang;
  final String nativeLabel;
  final String englishLabel;
  final String emoji;
}

const _allLanguages = <_LangMeta>[
  _LangMeta(AppLanguage.english, 'English', 'English', '\ud83c\uddec\ud83c\udde7'),
  _LangMeta(AppLanguage.hindi, '\u0939\u093f\u0928\u094d\u0926\u0940', 'Hindi', '\ud83c\uddee\ud83c\uddf3'),
  _LangMeta(AppLanguage.tamil, '\u0ba4\u0bae\u0bbf\u0bb4\u0bcd', 'Tamil', '\ud83c\udf3a'),
  _LangMeta(AppLanguage.gujarati, '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0', 'Gujarati', '\ud83c\udfdb\ufe0f'),
  _LangMeta(AppLanguage.assamese, '\u0985\u09b8\u09ae\u09c0\u09af\u09bc\u09be', 'Assamese', '\ud83c\udf3f'),
];

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key, required this.onLanguageSelected});

  final void Function(AppLanguage) onLanguageSelected;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  AppLanguage? _selected;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected != null) {
      widget.onLanguageSelected(_selected!);
    }
  }

  /// Filter languages based on Remote Config enabled list.
  List<_LangMeta> get _availableLanguages {
    final rc = RemoteConfigService.instance;
    final enabled = rc.enabledLanguages;
    if (enabled.isEmpty) return _allLanguages;
    return _allLanguages
        .where((m) => enabled.contains(m.lang.name))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final languages = _availableLanguages;

    return Scaffold(
      backgroundColor: context.cs.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // App icon badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: kSignatureGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [kWhisperShadow],
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Select Language',
                  style: TextStyle(
                    color: context.cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\u092d\u093e\u0937\u093e \u091a\u0941\u0928\u0947\u0902  \u2022  \u09ad\u09be\u09b7\u09be \u09ac\u09be\u099b\u0995  \u2022  \u0aad\u0abe\u0ab7\u0abe \u0aaa\u0ab8\u0a82\u0aa6 \u0a95\u0ab0\u0acb  \u2022  \u0bae\u0bca\u0bb4\u0bbf \u0ba4\u0bc7\u0bb0\u0bcd\u0ba8\u0bcd\u0ba4\u0bc6\u0b9f\u0bc1',
                  style: TextStyle(
                    color: context.cs.onSurfaceVariant.withAlpha(153),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Language cards in scrollable grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.3,
                    ),
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final meta = languages[index];
                      return _LanguageCard(
                        nativeLabel: meta.nativeLabel,
                        subLabel: meta.englishLabel,
                        emoji: meta.emoji,
                        isSelected: _selected == meta.lang,
                        onTap: () =>
                            setState(() => _selected = meta.lang),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Continue button
                AnimatedOpacity(
                  opacity: _selected != null ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 250),
                  child: GestureDetector(
                    onTap: _selected != null ? _confirm : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: kSignatureGradient,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: const [kWhisperShadow],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.nativeLabel,
    required this.subLabel,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  final String nativeLabel;
  final String subLabel;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? context.cs.primaryContainer : context.cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: kPrimary.withAlpha(80), width: 1.5)
              : null,
          boxShadow: isSelected ? const [kSubtleShadow] : [],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeLabel,
                    style: TextStyle(
                      color: context.cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: context.cs.onSurfaceVariant.withAlpha(153),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimary,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }
}
