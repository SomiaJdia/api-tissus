import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../config.dart';
import 'qcm_screen.dart';

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final String classePredite;
  final double confiance;
  final int? analyseId;

  const ResultScreen({
    Key? key,
    required this.imagePath,
    required this.classePredite,
    required this.confiance,
    this.analyseId,
  }) : super(key: key);

  void _showMoreInfo(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/info-tissu/$classePredite'));
      Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        final info = jsonDecode(response.body);
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info['nom_classe'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(info['description'] ?? 'Aucune description disponible'),
                const SizedBox(height: 12),
                const Text('Fonction', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(info['fonction'] ?? '-'),
                const SizedBox(height: 12),
                const Text('Localisation', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(info['localisation'] ?? '-'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                )
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informations non disponibles pour ce tissu.')));
      }
    } catch (e) {
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur réseau: $e')));
    }
  }

  static const Map<String, String> labelsComplets = {
    'ADI': 'Tissu Adipeux',
    'BACK': 'Arrière-plan',
    'DEB': 'Débris / Nécrose',
    'LYM': 'Lymphocytes',
    'MUC': 'Mucus',
    'MUS': 'Muscle lisse',
    'NORM': 'Muqueuse normale',
    'STR': 'Stroma / Conjonctif',
    'TUM': 'Épithélium tumoral',
  };

  @override
  Widget build(BuildContext context) {
    final nomComplet = labelsComplets[classePredite] ?? classePredite;

    return Scaffold(
      appBar: AppBar(title: const Text('Résultat de l\'analyse')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.file(File(imagePath), width: double.infinity, height: 300, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('Tissu détecté :', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text(
                    nomComplet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Text(
                      'Classe : $classePredite',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo.shade800),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Confiance : ${confiance.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Plus d\'infos', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: () => _showMoreInfo(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.quiz),
                      label: const Text('Faire le QCM', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QcmScreen(classeTissu: classePredite, analyseId: analyseId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Nouvelle analyse'),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

