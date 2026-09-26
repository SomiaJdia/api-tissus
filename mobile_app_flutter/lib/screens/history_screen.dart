import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historique = [];
  bool _loading = true;
  String _error = '';

  final Map<String, Color> _classeColors = {
    'ADI': const Color(0xFFF59E0B),
    'BACK': const Color(0xFF6B7280),
    'DEB': const Color(0xFFEF4444),
    'LYM': const Color(0xFF8B5CF6),
    'MUC': const Color(0xFF06B6D4),
    'MUS': const Color(0xFF10B981),
    'NORM': const Color(0xFF3B82F6),
    'STR': const Color(0xFFF97316),
    'TUM': const Color(0xFFDC2626),
  };

  final Map<String, String> _classeLabels = {
    'ADI': 'Tissu Adipeux',
    'BACK': 'Arriere-plan',
    'DEB': 'Debris / Necrose',
    'LYM': 'Lymphocytes',
    'MUC': 'Mucus',
    'MUS': 'Muscle lisse',
    'NORM': 'Muqueuse normale',
    'STR': 'Stroma',
    'TUM': 'Epithelium tumoral',
  };

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() { _error = 'Non authentifie. Veuillez vous reconnecter.'; _loading = false; });
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/historique'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _historique = data is List ? data : []; _loading = false; });
      } else if (response.statusCode == 401) {
        setState(() { _error = 'Session expiree. Reconnectez-vous.'; _loading = false; });
      } else {
        setState(() { _error = 'Erreur serveur (code ${response.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Erreur reseau : $e'; _loading = false; });
    }
  }

  Future<void> _supprimerAnalyse(int id, String classe) async {
    final bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette analyse ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text('Voulez-vous vraiment supprimer l\'analyse du tissu $classe de votre historique ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/historique/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _historique.removeWhere((item) => item['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analyse supprimee avec succes.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur reseau : $e')),
        );
      }
    }
  }

  Future<void> _viderToutHistorique() async {
    final bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Vider tout l\'historique ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('Cette action supprimera definitivement toutes vos analyses passees. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tout vider'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/historique'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _historique.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tout l\'historique a ete vide.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: AppBar(
        title: const Text('Historique des Analyses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (_historique.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Color(0xFFDC2626)),
              tooltip: 'Vider tout l\'historique',
              onPressed: _viderToutHistorique,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }
    if (_error.isNotEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off, size: 60, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _chargerHistorique,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
          child: const Text('Reessayer', style: TextStyle(color: Colors.white)),
        ),
      ]));
    }
    if (_historique.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.history, size: 80, color: Color(0xFFD1D5DB)),
        const SizedBox(height: 16),
        const Text('Aucune analyse effectuee', style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 8),
        const Text('Analysez une image pour la voir apparaitre ici', style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB))),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _chargerHistorique,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualiser'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
        ),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _chargerHistorique,
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historique.length,
        itemBuilder: (context, index) {
          final item = _historique[index];
          final id = item['id'] as int;
          final classe = item['classe_predite'] ?? '?';
          final couleur = _classeColors[classe] ?? const Color(0xFF6B7280);
          final label = _classeLabels[classe] ?? classe;
          final confiance = (item['confiance'] ?? 0.0).toDouble();
          final date = item['date_analyse'] ?? '';

          return Dismissible(
            key: Key('hist_$id'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Supprimer cette analyse ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  content: Text('Voulez-vous vraiment supprimer l\'analyse du tissu $label ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token') ?? '';
                await http.delete(
                  Uri.parse('${AppConfig.baseUrl}/historique/$id'),
                  headers: {'Authorization': 'Bearer $token'},
                );
              } catch (_) {}
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(classe, style: TextStyle(color: couleur, fontWeight: FontWeight.bold, fontSize: 12))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ])),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('${confiance.toStringAsFixed(1)}%', style: TextStyle(color: couleur, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    if (item['score_qcm'] != null) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              'QCM: ${item['score_qcm']}/${item['total_qcm']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF9CA3AF)),
                  tooltip: 'Supprimer',
                  splashRadius: 20,
                  onPressed: () => _supprimerAnalyse(id, label),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
