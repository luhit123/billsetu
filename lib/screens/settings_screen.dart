import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isUpdatingLanguage = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currentLanguage = strings.language;

    return Scaffold(
      appBar: AppBar(title: Text(strings.drawerSettings)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFF5FBFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF123C85), Color(0xFF0F7D83)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 20,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.settingsLanguageTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.settingsLanguageSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              strings.settingsCurrentLanguage(
                                _nativeLanguageLabel(currentLanguage),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _LanguageOptionTile(
                nativeLabel: 'English',
                helperLabel: 'English',
                isSelected: currentLanguage == AppLanguage.english,
                isBusy: _isUpdatingLanguage,
                onTap: () => _changeLanguage(AppLanguage.english),
              ),
              const SizedBox(height: 12),
              _LanguageOptionTile(
                nativeLabel: 'हिन्दी',
                helperLabel: 'Hindi',
                isSelected: currentLanguage == AppLanguage.hindi,
                isBusy: _isUpdatingLanguage,
                onTap: () => _changeLanguage(AppLanguage.hindi),
              ),
              const SizedBox(height: 12),
              _LanguageOptionTile(
                nativeLabel: 'অসমীয়া',
                helperLabel: 'Assamese',
                isSelected: currentLanguage == AppLanguage.assamese,
                isBusy: _isUpdatingLanguage,
                onTap: () => _changeLanguage(AppLanguage.assamese),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    final currentLanguage = AppStrings.of(context).language;
    if (_isUpdatingLanguage || currentLanguage == language) {
      return;
    }

    setState(() {
      _isUpdatingLanguage = true;
    });

    try {
      await LanguageProvider.setLanguage(context, language);

      if (!mounted) {
        return;
      }

      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              strings.settingsLanguageChanged(_nativeLanguageLabel(language)),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLanguage = false;
        });
      }
    }
  }

  String _nativeLanguageLabel(AppLanguage language) {
    return switch (language) {
      AppLanguage.english => 'English',
      AppLanguage.hindi => 'हिन्दी',
      AppLanguage.assamese => 'অসমীয়া',
    };
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.nativeLabel,
    required this.helperLabel,
    required this.isSelected,
    required this.isBusy,
    required this.onTap,
  });

  final String nativeLabel;
  final String helperLabel;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEAF8FF) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF123C85)
                  : const Color(0xFFD7E2F3),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withAlpha(18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE4F7F8),
                foregroundColor: const Color(0xFF0F7D83),
                child: const Icon(Icons.language_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helperLabel,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isBusy && isSelected)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: isSelected
                      ? const Color(0xFF123C85)
                      : Colors.blueGrey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
