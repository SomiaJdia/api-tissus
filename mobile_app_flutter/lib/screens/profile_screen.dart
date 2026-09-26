import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nom = '';
  String _email = '';
  String _token = '';
  bool _showChangePassword = false;
  final _ancienMdpCtrl = TextEditingController();
  final _nouveauMdpCtrl = TextEditingController();
  final _confirmMdpCtrl = TextEditingController();
  bool _loadingMdp = false;
  String _mdpMsg = '';
  String _mdpErr = '';
  bool _obscureAncien = true;
  bool _obscureNouveau = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  Future<void> _chargerProfil() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nom = prefs.getString('nom') ?? 'Etudiant';
      _email = prefs.getString('email') ?? '';
      _token = prefs.getString('token') ?? '';
    });
  }

  Future<void> _deconnexion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _changerMotDePasse() async {
    setState(() { _mdpMsg = ''; _mdpErr = ''; });
    if (_nouveauMdpCtrl.text != _confirmMdpCtrl.text) {
      setState(() { _mdpErr = 'Les mots de passe ne correspondent pas'; });
      return;
    }
    if (_nouveauMdpCtrl.text.length < 6) {
      setState(() { _mdpErr = 'Le mot de passe doit avoir au moins 6 caracteres'; });
      return;
    }
    setState(() { _loadingMdp = true; });
    try {
      final response = await http.post(
        Uri.parse(AppConfig.baseUrl + '/etudiant/changer-mot-de-passe'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({
          'ancien_mot_de_passe': _ancienMdpCtrl.text.trim(),
          'nouveau_mot_de_passe': _nouveauMdpCtrl.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        setState(() { _mdpMsg = 'Mot de passe modifie avec succes !'; _showChangePassword = false; });
        _ancienMdpCtrl.clear();
        _nouveauMdpCtrl.clear();
        _confirmMdpCtrl.clear();
      } else {
        setState(() { _mdpErr = jsonDecode(response.body)['detail'] ?? 'Erreur lors de la modification'; });
      }
    } catch (e) {
      setState(() { _mdpErr = 'Erreur reseau : $e'; });
    } finally {
      setState(() { _loadingMdp = false; });
    }
  }

  String _getInitiales() {
    if (_nom.isEmpty) return 'E';
    final parts = _nom.trim().split(' ');
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return _nom[0].toUpperCase();
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF7C3AED), size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ])),
    ]);
  }

  Widget _passwordField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF)),
        suffixIcon: GestureDetector(
          onTap: toggle,
          child: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9CA3AF)),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),
            // Avatar
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Center(child: Text(_getInitiales(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 20),
            Text(_nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text(_email, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(20)),
              child: const Text('Etudiant', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(height: 28),
            // Info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Column(children: [
                _infoRow(Icons.person_outline, 'Nom complet', _nom),
                const Divider(height: 24),
                _infoRow(Icons.mail_outline, 'Email', _email),
                const Divider(height: 24),
                _infoRow(Icons.school_outlined, 'Role', 'Etudiant'),
              ]),
            ),
            const SizedBox(height: 16),
            // Success message
            if (_mdpMsg.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF86EFAC))),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_mdpMsg, style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13))),
                ]),
              ),
            const SizedBox(height: 12),
            // Toggle button
            GestureDetector(
              onTap: () => setState(() { _showChangePassword = !_showChangePassword; _mdpErr = ''; _mdpMsg = ''; }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _showChangePassword ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.key, color: Color(0xFF7C3AED), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Modifier mon mot de passe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827)))),
                  Icon(_showChangePassword ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF9CA3AF)),
                ]),
              ),
            ),
            if (_showChangePassword) ...[  
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Changer le mot de passe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 16),
                  if (_mdpErr.isNotEmpty) ...[  
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_mdpErr, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _passwordField('Ancien mot de passe', _ancienMdpCtrl, _obscureAncien, () => setState(() => _obscureAncien = !_obscureAncien)),
                  const SizedBox(height: 12),
                  _passwordField('Nouveau mot de passe', _nouveauMdpCtrl, _obscureNouveau, () => setState(() => _obscureNouveau = !_obscureNouveau)),
                  const SizedBox(height: 12),
                  _passwordField('Confirmer le nouveau mot de passe', _confirmMdpCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: _loadingMdp ? null : _changerMotDePasse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loadingMdp
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _deconnexion,
                icon: const Icon(Icons.logout),
                label: const Text('Se deconnecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  foregroundColor: const Color(0xFFDC2626),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFFCA5A5))),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
