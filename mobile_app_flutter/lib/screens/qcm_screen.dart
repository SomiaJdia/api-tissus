import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
class QcmScreen extends StatefulWidget {
  final String classeTissu;
  final int? analyseId;
  const QcmScreen({Key? key, required this.classeTissu, this.analyseId}) : super(key: key);
  @override
  _QcmScreenState createState() => _QcmScreenState();
}

class _QcmScreenState extends State<QcmScreen> {
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _finished = false;

  static const Map<String, List<Map<String, dynamic>>> _qcmData = {
    'ADI': [
      {'question': "Qu'est-ce que le tissu adipeux ?", 'options': ["Tissu osseux", "Tissu de stockage de graisse", "Tissu musculaire", "Tissu nerveux"], 'correct': 1},
      {'question': "Quelle est la principale fonction du tissu adipeux ?", 'options': ["Contraction", "Conduction nerveuse", "Stockage d'energie et isolation thermique", "Production de sang"], 'correct': 2},
      {'question': "Les cellules du tissu adipeux s'appellent ?", 'options': ["Neurones", "Adipocytes", "Myocytes", "Osteocytes"], 'correct': 1},
    ],
    'BACK': [
      {'question': "Que represente la classe BACK ?", 'options': ["Tumeur maligne", "Fond / Arriere-plan sans tissu", "Tissu adipeux", "Muqueuse"], 'correct': 1},
      {'question': "Le fond d'image en histologie est generalement de quelle couleur ?", 'options': ["Rose vif", "Bleu fonce", "Blanc ou tres clair", "Vert"], 'correct': 2},
      {'question': "Comment eviter la classe BACK lors d'une analyse ?", 'options': ["En zoomant davantage", "En centrant l'image sur le tissu", "En changeant de colorant", "En augmentant la resolution"], 'correct': 1},
    ],
    'DEB': [
      {'question': "Que signifie DEB en histologie ?", 'options': ["Debris cellulaires ou zones de necrose", "Tissu musculaire degenere", "Tissu de depart", "Depot de lipides"], 'correct': 0},
      {'question': "La necrose cellulaire est caracterisee par ?", 'options': ["Une division cellulaire rapide", "Une mort cellulaire non programmee", "Une croissance tumorale", "Une inflammation chronique"], 'correct': 1},
      {'question': "Les debris cellulaires sont souvent associes a ?", 'options': ["La sante tissulaire", "La mitose", "Une pathologie ou une lesion", "La regeneration normale"], 'correct': 2},
    ],
    'LYM': [
      {'question': "Les lymphocytes appartiennent a ?", 'options': ["Au systeme digestif", "Au systeme immunitaire", "Au systeme osseux", "Au systeme nerveux"], 'correct': 1},
      {'question': "Quelle est la fonction principale des lymphocytes ?", 'options': ["Transport d'oxygene", "Contraction musculaire", "Defense immunitaire", "Filtration des dechets"], 'correct': 2},
      {'question': "Un tissu riche en lymphocytes indique ?", 'options': ["Une zone de graisse", "Une reponse immunitaire ou inflammation", "Un tissu sain", "Du tissu conjonctif"], 'correct': 1},
    ],
    'MUC': [
      {'question': "Qu'est-ce que le mucus ?", 'options': ["Une proteine contractile", "Une secretion visqueuse protectrice", "Un type de cellule osseuse", "Un pigment cellulaire"], 'correct': 1},
      {'question': "Les cellules productrices de mucus s'appellent ?", 'options': ["Cellules de Paneth", "Cellules caliciformes", "Cellules de Leydig", "Cellules de Kupffer"], 'correct': 1},
      {'question': "Le mucus protege principalement ?", 'options': ["Le tissu osseux", "Le muscle cardiaque", "Les muqueuses digestives et respiratoires", "Les neurones"], 'correct': 2},
    ],
    'MUS': [
      {'question': "Le muscle lisse se trouve dans ?", 'options': ["Les membres squelettiques", "Le coeur uniquement", "Les organes internes (intestins, vaisseaux)", "Le cerveau"], 'correct': 2},
      {'question': "Le muscle lisse est controle par ?", 'options': ["La volonte consciente", "Le systeme nerveux autonome", "Le cervelet", "Le cortex moteur"], 'correct': 1},
      {'question': "Caracteristique histologique du muscle lisse ?", 'options': ["Stries transversales visibles", "Noyaux multiples peripheriques", "Cellules fusiformes avec noyau central", "Pas de noyau"], 'correct': 2},
    ],
    'NORM': [
      {'question': "NORM represente ?", 'options': ["Tissu tumoral normal", "Muqueuse colique normale saine", "Tissu adipeux normal", "Stroma normal"], 'correct': 1},
      {'question': "La muqueuse normale du colon est tapissee de ?", 'options': ["Epithelium pavimenteux", "Epithelium cylindrique avec des cryptes", "Epithelium pseudostratifie", "Tissu osseux"], 'correct': 1},
      {'question': "Comment distinguer une muqueuse normale d'une muqueuse tumorale ?", 'options': ["Par sa couleur rouge", "Par une architecture glandulaire reguliere", "Par l'absence de cellules", "Par la presence de graisse"], 'correct': 1},
    ],
    'STR': [
      {'question': "Le stroma est principalement compose de ?", 'options': ["Cellules musculaires", "Tissu conjonctif et fibroblastes", "Neurones", "Cellules adipeuses"], 'correct': 1},
      {'question': "Le role du stroma tumoral est ?", 'options': ["Produire des hormones", "Proteger et soutenir les cellules tumorales", "Eliminer les cellules mortes", "Conduire les signaux nerveux"], 'correct': 1},
      {'question': "Le collagene est produit par ?", 'options': ["Les lymphocytes", "Les fibroblastes", "Les adipocytes", "Les neurones"], 'correct': 1},
    ],
    'TUM': [
      {'question': "TUM represente ?", 'options': ["Tissu musculaire", "Epithelium tumoral colorectal", "Tissu uretral musculaire", "Tissu ulcere muqueux"], 'correct': 1},
      {'question': "Les cellules tumorales se caracterisent par ?", 'options': ["Une division cellulaire controlee", "Une proliferation incontrolee", "Une apoptose acceleree", "Une absence de noyau"], 'correct': 1},
      {'question': "Quel marqueur histologique suggere une malignite ?", 'options': ["Noyaux reguliers et petits", "Architecture glandulaire normale", "Pleomorphisme nucleaire et mitoses atypiques", "Abondant cytoplasme"], 'correct': 2},
    ],
  };

  List<Map<String, dynamic>> get _questions => _qcmData[widget.classeTissu] ?? _qcmData['NORM']!;

  void _selectAnswer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_questionIndex]['correct']) _score++;
    });
  }

  Future<void> _enregistrerScore() async {
    if (widget.analyseId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/historique/qcm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'analyse_id': widget.analyseId,
          'score': _score,
          'total': _questions.length,
        }),
      );
    } catch (e) {
      debugPrint('Erreur sauvegarde score QCM : $e');
    }
  }

  void _nextQuestion() {
    if (_questionIndex < _questions.length - 1) {
      setState(() { _questionIndex++; _selectedAnswer = null; _answered = false; });
    } else {
      _enregistrerScore();
      setState(() { _finished = true; });
    }
  }

  Color _optionColor(int index) {
    if (!_answered) return Colors.white;
    final correct = _questions[_questionIndex]['correct'];
    if (index == correct) return const Color(0xFF10B981);
    if (index == _selectedAnswer) return const Color(0xFFEF4444);
    return Colors.white;
  }

  Color _optionTextColor(int index) {
    if (!_answered) return const Color(0xFF374151);
    final correct = _questions[_questionIndex]['correct'];
    if (index == correct || index == _selectedAnswer) return Colors.white;
    return const Color(0xFF374151);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      final total = _questions.length;
      final pct = (_score / total * 100).round();
      final color = pct >= 66 ? const Color(0xFF10B981) : pct >= 33 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
      final message = pct >= 66 ? 'Excellent !' : pct >= 33 ? 'Pas mal !' : 'A reviser...';
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Center(child: Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(height: 24),
                Text(message, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 8),
                Text('$_score / $total bonnes reponses', style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                Text('Tissu : ${widget.classeTissu}', style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Retour aux resultats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    final question = _questions[_questionIndex];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('QCM - ${widget.classeTissu}', style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('${_questionIndex + 1}/${_questions.length}', style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_questionIndex + 1) / _questions.length,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
              child: Text(question['question'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF111827), height: 1.4)),
            ),
            const SizedBox(height: 20),
            ...List.generate((question['options'] as List).length, (i) {
              return GestureDetector(
                onTap: () => _selectAnswer(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _optionColor(i),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: !_answered ? const Color(0xFFE5E7EB) : _optionColor(i), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: _answered ? _optionColor(i).withOpacity(0.8) : const Color(0xFFF3F4F6), shape: BoxShape.circle),
                      child: Center(child: Text(['A','B','C','D'][i], style: TextStyle(fontWeight: FontWeight.bold, color: _answered ? Colors.white : const Color(0xFF6B7280), fontSize: 13))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(question['options'][i], style: TextStyle(fontSize: 15, color: _optionTextColor(i), fontWeight: FontWeight.w500))),
                    if (_answered && i == question['correct']) const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    if (_answered && i == _selectedAnswer && i != question['correct']) const Icon(Icons.cancel, color: Colors.white, size: 20),
                  ]),
                ),
              );
            }),
            const Spacer(),
            if (_answered)
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  child: Text(_questionIndex < _questions.length - 1 ? 'Question suivante' : 'Voir mon score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
