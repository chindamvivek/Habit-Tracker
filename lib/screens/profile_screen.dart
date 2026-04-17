import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habit_tracker/services/api_key_service.dart';

/// Full-featured Settings screen.
///
/// Currently houses:
///  • User info / sign-out
///  • Gemini API key configuration
class SettingsScreen extends StatefulWidget {
  final User user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kPrimary = Color(0xFF4E55E0);

  final _keyController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  bool _hasSavedKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    try {
      final key = await ApiKeyService.instance.getApiKey();
      if (!mounted) return;
      setState(() {
        _hasSavedKey = key != null;
        // Pre-fill the placeholder so the user knows a key exists
        _keyController.text = key ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _showMessage(
        'Cannot read secure storage. Please fully restart the app. Error: $e',
        isError: true,
      );
    }
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      _showMessage('Please enter a valid API key.', isError: true);
      return;
    }
    setState(() => _saving = true);
    await ApiKeyService.instance.saveApiKey(key);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _hasSavedKey = true;
    });
    _showMessage('API key saved ✓', isError: false);
  }

  Future<void> _deleteKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove API Key?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You will need to re-enter your Gemini API key to generate AI plans.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiKeyService.instance.deleteApiKey();
    if (!mounted) return;
    setState(() {
      _hasSavedKey = false;
      _keyController.clear();
    });
    _showMessage('API key removed.', isError: false);
  }

  void _showMessage(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red.shade700
            : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App bar ──────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: const Color(0xFFF2F3F5),
              surfaceTintColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.black),
              title: const Text(
                'Settings',
                style: TextStyle(
                  color: Color(0xFF1D1D1F),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              floating: true,
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Account card ─────────────────────────────────────
                  _SectionHeader(title: 'Account'),
                  const SizedBox(height: 8),
                  _Card(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: _kPrimary.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: _kPrimary,
                            ),
                          ),
                          title: Text(
                            widget.user.displayName ?? 'User',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            widget.user.email ?? '',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.45),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── AI Settings card ──────────────────────────────────
                  _SectionHeader(title: 'AI Plan Settings'),
                  const SizedBox(height: 8),
                  _Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4E55E0),
                                            Color(0xFF8B5CF6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Gemini API Key',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          _hasSavedKey
                                              ? '✓ Key saved'
                                              : 'Not configured',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _hasSavedKey
                                                ? const Color(0xFF22C55E)
                                                : Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Info chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kPrimary.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: _kPrimary.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Get a free key at aistudio.google.com. Uses model gemini-2.5-flash.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _kPrimary.withValues(
                                              alpha: 0.8,
                                            ),
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // API key input
                                TextField(
                                  controller: _keyController,
                                  obscureText: _obscure,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'AIzaS...',
                                    hintStyle: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: _kPrimary.withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: Colors.black45,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Save / Delete buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 46,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _kPrimary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: _saving ? null : _saveKey,
                                          child: _saving
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text(
                                                  'Save Key',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    if (_hasSavedKey) ...[
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        height: 46,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(
                                              color: Colors.red,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: _deleteKey,
                                          child: const Text(
                                            'Remove',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── App info ──────────────────────────────────────────
                  _SectionHeader(title: 'About'),
                  const SizedBox(height: 8),
                  _Card(
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.info_outline_rounded,
                          label: 'Version',
                          value: '1.0.0',
                        ),
                        const Divider(height: 1, indent: 56),
                        _InfoTile(
                          icon: Icons.bolt_rounded,
                          label: 'AI Model',
                          value: 'gemini-2.5-flash',
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.black.withValues(alpha: 0.35),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF4E55E0).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF4E55E0), size: 18),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Colors.black.withValues(alpha: 0.45),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
