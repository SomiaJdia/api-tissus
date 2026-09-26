import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  // --- Premier changement mot de passe ---
  String _tokenTemp = '';
  final _nouveauMdpCtrl = TextEditingController();
  final _confirmMdpCtrl = TextEditingController();
  bool _loadingMdp = false;
  String _mdpErr = '';
  bool _obscureNouv = true;
  bool _obscureConf = true;

  Future<void> _login() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final response = await http.post(
        Uri.parse(AppConfig.baseUrl + '/connexion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim().toLowerCase(),
          'mot_de_passe': _passwordController.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['role'] == 'etudiant') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['access_token']);
          await prefs.setString('nom', data['nom'] ?? '');
          await prefs.setString('email', _emailController.text.trim().toLowerCase());
          await prefs.setBool('doit_changer_mot_de_passe', data['doit_changer_mot_de_passe'] == true);

          if (data['doit_changer_mot_de_passe'] == true) {
            setState(() { _tokenTemp = data['access_token']; });
            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => _buildPremierMdpDialog(ctx),
              );
            }
          } else {
            if (mounted) Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          setState(() { _errorMessage = "L'acces mobile est reserve aux etudiants."; });
        }
      } else {
        setState(() { _errorMessage = jsonDecode(response.body)['detail'] ?? 'Email ou mot de passe incorrect'; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Erreur reseau. Verifiez votre connexion.'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _soumettreNouveauMdp(BuildContext dialogCtx) async {
    setState(() { _mdpErr = ''; });
    if (_nouveauMdpCtrl.text.trim().length < 6) {
      setState(() { _mdpErr = 'Le mot de passe doit avoir au moins 6 caracteres.'; });
      return;
    }
    if (_nouveauMdpCtrl.text.trim() != _confirmMdpCtrl.text.trim()) {
      setState(() { _mdpErr = 'Les mots de passe ne correspondent pas.'; });
      return;
    }
    setState(() { _loadingMdp = true; });
    try {
      final response = await http.post(
        Uri.parse(AppConfig.baseUrl + '/premier-changement-mot-de-passe'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_tokenTemp'},
        body: jsonEncode({'nouveau_mot_de_passe': _nouveauMdpCtrl.text.trim()}),
      );
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('doit_changer_mot_de_passe', false);
        _nouveauMdpCtrl.clear();
        _confirmMdpCtrl.clear();
        Navigator.of(dialogCtx).pop();
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() { _mdpErr = jsonDecode(response.body)['detail'] ?? 'Erreur lors du changement.'; });
      }
    } catch (e) {
      setState(() { _mdpErr = 'Erreur reseau.'; });
    } finally {
      setState(() { _loadingMdp = false; });
    }
  }

  Widget _buildPremierMdpDialog(BuildContext dialogCtx) {
    return StatefulBuilder(builder: (ctx, setDialogState) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_reset, color: Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Changement de mot de passe requis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)))),
            ]),
            const SizedBox(height: 8),
            const Text('Bienvenue ! Veuillez definir votre propre mot de passe pour continuer.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 20),
            if (_mdpErr.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_mdpErr, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nouveauMdpCtrl,
              obscureText: _obscureNouv,
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF)),
                suffixIcon: GestureDetector(
                  onTap: () { setState(() => _obscureNouv = !_obscureNouv); setDialogState(() {}); },
                  child: Icon(_obscureNouv ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9CA3AF)),
                ),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmMdpCtrl,
              obscureText: _obscureConf,
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF)),
                suffixIcon: GestureDetector(
                  onTap: () { setState(() => _obscureConf = !_obscureConf); setDialogState(() {}); },
                  child: Icon(_obscureConf ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9CA3AF)),
                ),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _loadingMdp ? null : () => _soumettreNouveauMdp(dialogCtx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loadingMdp
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Valider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.biotech, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text('HistoClassAI', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), letterSpacing: 0.5)),
              const SizedBox(height: 6),
              const Text("L'IA au service de l'histologie", style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_errorMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text('Adresse Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'etudiant@etu.uae.ac.ma',
                      hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                      prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF9CA3AF)),
                      filled: true, fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Mot de passe', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const Text('Mot de passe oublie ?', style: TextStyle(fontSize: 13, color: Color(0xFF7C3AED), fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Votre mot de passe',
                      hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF)),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9CA3AF)),
                      ),
                      filled: true, fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
