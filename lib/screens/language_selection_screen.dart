import 'package:flutter/material.dart';
import 'package:billeasy/theme/app_colors.dart';

enum AppLanguage { english, hindi, assamese, gujarati, tamil }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 56),

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

                const SizedBox(height: 32),

                // Title
                const Text(
                  'Select Language',
                  style: TextStyle(
                    color: kOnSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '\u09ad\u09be\u09b7\u09be \u09ac\u09be\u099b\u0995  \u2022  \u092d\u093e\u0937\u093e \u091a\u0941\u0928\u0947\u0902  \u2022  \u0aad\u0abe\u0ab7\u0abe \u0aaa\u0ab8\u0a82\u0aa6 \u0a95\u0ab0\u0acb  \u2022  \u0bae\u0bca\u0bb4\u0bbf \u0ba4\u0bc7\u0bb0\u0bcd\u0ba8\u0bcd\u0ba4\u0bc6\u0b9f\u0bc1',
                  style: TextStyle(
                    color: kTextTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 36),

                // Language cards
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _LanguageCard(
                          nativeLabel: 'English',
                          subLabel: 'English',
                          emoji: '\ud83c\uddec\ud83c\udde7',
                          isSelected: _selected == AppLanguage.english,
                          onTap: () =>
                              setState(() => _selected = AppLanguage.english),
                        ),
                        const SizedBox(height: 14),
                        _LanguageCard(
                          nativeLabel: '\u0939\u093f\u0928\u094d\u0926\u0940',
                          subLabel: 'Hindi',
                          emoji: '\ud83c\uddee\ud83c\uddf3',
                          isSelected: _selected == AppLanguage.hindi,
                          onTap: () =>
                              setState(() => _selected = AppLanguage.hindi),
                        ),
                        const SizedBox(height: 14),
                        _LanguageCard(
                          nativeLabel: '\u0985\u09b8\u09ae\u09c0\u09af\u09bc\u09be',
                          subLabel: 'Assamese',
                          emoji: '\ud83c\udf3f',
                          isSelected: _selected == AppLanguage.assamese,
                          onTap: () =>
                              setState(() => _selected = AppLanguage.assamese),
                        ),
                        const SizedBox(height: 14),
                        _LanguageCard(
                          nativeLabel: '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0',
                          subLabel: 'Gujarati',
                          emoji: '\ud83c\udfdb\ufe0f',
                          isSelected: _selected == AppLanguage.gujarati,
                          onTap: () =>
                              setState(() => _selected = AppLanguage.gujarati),
                        ),
                        const SizedBox(height: 14),
                        _LanguageCard(
                          nativeLabel: '\u0ba4\u0bae\u0bbf\u0bb4\u0bcd',
                          subLabel: 'Tamil',
                          emoji: '\ud83c\udf3a',
                          isSelected: _selected == AppLanguage.tamil,
                          onTap: () =>
                              setState(() => _selected = AppLanguage.tamil),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

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

                const SizedBox(height: 40),
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryContainer : kSurfaceLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [kSubtleShadow]
              : [],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nativeLabel,
                  style: const TextStyle(
                    color: kOnSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subLabel,
                  style: const TextStyle(
                    color: kTextTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? kPrimary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? kPrimary
                      : kTextTertiary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
