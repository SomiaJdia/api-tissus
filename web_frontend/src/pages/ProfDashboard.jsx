import { useState, useEffect } from 'react';
import axios from 'axios';
import { API_URL } from '../config';
import { useNavigate } from 'react-router-dom';

export default function ProfDashboard() {
  const navigate = useNavigate();
  const token = localStorage.getItem('token');

  const [activeTab, setActiveTab] = useState('etudiants'); // 'etudiants' ou 'tissus'
  const [nom, setNom] = useState('');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [mdpPopup, setMdpPopup] = useState(null); // { nom, email, mdp }
  
  const [etudiants, setEtudiants] = useState([]);
  const [tissus, setTissus] = useState([]);

  const CLASSES_TISSUS = [
    { code: 'ADI', label: 'ADI - Tissu Adipeux' },
    { code: 'BACK', label: 'BACK - Arrière-plan' },
    { code: 'DEB', label: 'DEB - Débris / Nécrose' },
    { code: 'LYM', label: 'LYM - Lymphocytes' },
    { code: 'MUC', label: 'MUC - Mucus' },
    { code: 'MUS', label: 'MUS - Muscle lisse' },
    { code: 'NORM', label: 'NORM - Muqueuse normale' },
    { code: 'STR', label: 'STR - Stroma / Tissu conjonctif' },
    { code: 'TUM', label: 'TUM - Épithélium tumoral' },
  ];

  // États Formulaire Tissus pour le Prof
  const [tissuClasse, setTissuClasse] = useState('ADI');
  const [tissuDescription, setTissuDescription] = useState('');
  const [tissuFonction, setTissuFonction] = useState('');
  const [tissuLocalisation, setTissuLocalisation] = useState('');
  const [tissuMsg, setTissuMsg] = useState('');
  const [tissuErr, setTissuErr] = useState('');

  const handleSaveTissu = async (e) => {
    e.preventDefault();
    setTissuMsg('');
    setTissuErr('');

    try {
      const res = await axios.post(`${API_URL}/info-tissu`, {
        nom_classe: tissuClasse,
        description: tissuDescription,
        fonction: tissuFonction,
        localisation: tissuLocalisation
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setTissuMsg(res.data.message);
      chargerTissus();
    } catch (err) {
      setTissuErr(err.response?.data?.detail || "Erreur lors de l'enregistrement du tissu");
    }
  };

  const handleEditTissu = (t) => {
    setTissuClasse(t.nom_classe);
    setTissuDescription(t.description || '');
    setTissuFonction(t.fonction || '');
    setTissuLocalisation(t.localisation || '');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDeleteTissu = async (id, nomClasse) => {
    if (!window.confirm(`Voulez-vous vraiment supprimer la fiche du tissu '${nomClasse}' ?`)) return;
    try {
      await axios.delete(`${API_URL}/info-tissu/${id}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      chargerTissus();
    } catch (err) {
      alert(err.response?.data?.detail || "Erreur lors de la suppression du tissu");
    }
  };

  
  // CSV États
  const [csvLoading, setCsvLoading] = useState(false);
  const [csvResultModal, setCsvResultModal] = useState(null); // { crees: [], erreurs: [] }

  // Étudiant en cours d'édition
  const [editingStudent, setEditingStudent] = useState(null);
  const [editNom, setEditNom] = useState('');
  const [editEmail, setEditEmail] = useState('');

  // Changement mot de passe première connexion
  const [doitChangerMdp, setDoitChangerMdp] = useState(false);
  const [nouveauMdp, setNouveauMdp] = useState('');
  const [confirmMdp, setConfirmMdp] = useState('');
  const [mdpErr, setMdpErr] = useState('');
  const [mdpLoading, setMdpLoading] = useState(false);

  useEffect(() => {
    if (!token) {
      navigate('/login');
      return;
    }
    const doitChanger = localStorage.getItem('doit_changer_mot_de_passe') === 'true';
    if (doitChanger) {
      setDoitChangerMdp(true);
    }
    chargerEtudiants();
    chargerTissus();
  }, []);

  const handlePremierChangementMdp = async (e) => {
    e.preventDefault();
    setMdpErr('');
    if (nouveauMdp.length < 6) {
      setMdpErr("Le mot de passe doit contenir au moins 6 caractères.");
      return;
    }
    if (nouveauMdp !== confirmMdp) {
      setMdpErr("Les mots de passe ne correspondent pas.");
      return;
    }
    setMdpLoading(true);
    try {
      await axios.post(`${API_URL}/premier-changement-mot-de-passe`, {
        nouveau_mot_de_passe: nouveauMdp
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      localStorage.setItem('doit_changer_mot_de_passe', 'false');
      setDoitChangerMdp(false);
      alert("Votre mot de passe a été mis à jour avec succès !");
    } catch (err) {
      setMdpErr(err.response?.data?.detail || "Erreur lors du changement de mot de passe");
    } finally {
      setMdpLoading(false);
    }
  };

  const handleCsvUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setCsvLoading(true);
    const formData = new FormData();
    formData.append('file', file);
    try {
      const res = await axios.post(`${API_URL}/prof/etudiants/csv`, formData, {
        headers: { 
          Authorization: `Bearer ${token}`,
          'Content-Type': 'multipart/form-data'
        }
      });
      setCsvResultModal(res.data);
      chargerEtudiants();
    } catch (err) {
      alert(err.response?.data?.detail || "Erreur lors de l'import CSV");
    } finally {
      setCsvLoading(false);
      e.target.value = '';
    }
  };

  const handleDeleteStudent = async (id) => {
    if (!window.confirm("Voulez-vous vraiment supprimer cet étudiant ?")) return;
    try {
      await axios.delete(`${API_URL}/utilisateurs/${id}`);
      chargerEtudiants();
    } catch (e) {
      alert("Erreur lors de la suppression");
    }
  };

  const handleStartEditStudent = (e) => {
    setEditingStudent(e);
    setEditNom(e.nom);
    setEditEmail(e.email);
  };

  const handleSaveEditStudent = async (e) => {
    e.preventDefault();
    try {
      await axios.put(`${API_URL}/utilisateurs/${editingStudent.id}`, {
        nom: editNom,
        email: editEmail
      });
      setEditingStudent(null);
      chargerEtudiants();
    } catch (err) {
      alert(err.response?.data?.detail || "Erreur lors de la modification");
    }
  };

  const handleLogout = () => {
    localStorage.clear();
    navigate('/login');
  };

  const chargerEtudiants = async () => {
    try {
      const res = await axios.get(`${API_URL}/prof/etudiants`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setEtudiants(res.data);
    } catch (e) {
      console.error("Erreur chargement étudiants:", e);
    }
  };

  const chargerTissus = async () => {
    try {
      const res = await axios.get(`${API_URL}/info-tissus`);
      setTissus(res.data);
    } catch (e) {
      console.error("Erreur chargement tissus:", e);
    }
  };

  const handleAddStudent = async (e) => {
    e.preventDefault();
    setMessage('');
    setError('');
    setLoading(true);
    
    const tokenActuel = localStorage.getItem('token');
    if (!tokenActuel) {
      navigate('/login');
      return;
    }

    try {
      const response = await axios.post(`${API_URL}/prof/etudiants`, {
        nom,
        email
      }, {
        headers: {
          Authorization: `Bearer ${tokenActuel}`
        }
      });
      
      const mdpMatch = response.data.message.match(/Mot de passe généré : ([^\)]+)\)/);
      const mdpGenere = mdpMatch ? mdpMatch[1] : null;
      if (mdpGenere) {
        setMdpPopup({ nom, email, mdp: mdpGenere });
      } else {
        setMessage(response.data.message);
      }
      setNom('');
      setEmail('');
      chargerEtudiants();
    } catch (err) {
      console.error("Erreur backend:", err.response);
      if (err.response?.status === 401) {
        localStorage.clear();
        navigate('/login');
        return;
      }
      const detailErr = err.response?.data?.detail;
      setError(typeof detailErr === 'string' ? detailErr : "Erreur lors de l'ajout de l'étudiant");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* En-tête */}
      <header className="bg-white shadow-sm border-b sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-4 py-4 flex justify-between items-center">
          <div className="flex items-center space-x-3">
            <div className="bg-indigo-600 text-white p-2 rounded-lg font-bold text-lg">🔬</div>
            <div>
              <h1 className="text-xl font-bold text-gray-800">Espace Professeur</h1>
              <p className="text-xs text-gray-500">Gestion des Étudiants et Consultation des Tissus</p>
            </div>
          </div>
          <button 
            onClick={handleLogout} 
            className="px-4 py-2 text-sm text-red-600 border border-red-200 hover:bg-red-50 rounded-lg font-medium transition-colors"
          >
            Déconnexion
          </button>
        </div>
      </header>

      {/* Navigation par Onglets */}
      <div className="bg-white border-b">
        <div className="max-w-6xl mx-auto px-4 flex space-x-8">
          <button 
            onClick={() => setActiveTab('etudiants')}
            className={`py-4 font-semibold text-sm border-b-2 transition-all flex items-center space-x-2 ${
              activeTab === 'etudiants' 
                ? 'border-indigo-600 text-indigo-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <span>🎓 Mes Étudiants</span>
            <span className="bg-gray-100 text-gray-700 text-xs px-2 py-0.5 rounded-full">{etudiants.length}</span>
          </button>

          <button 
            onClick={() => setActiveTab('tissus')}
            className={`py-4 font-semibold text-sm border-b-2 transition-all flex items-center space-x-2 ${
              activeTab === 'tissus' 
                ? 'border-indigo-600 text-indigo-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <span>🧬 Fiches Tissus</span>
            <span className="bg-gray-100 text-gray-700 text-xs px-2 py-0.5 rounded-full">{tissus.length}/9</span>
          </button>
        </div>
      </div>
      
      {/* Contenu */}
      <main className="max-w-6xl mx-auto px-4 py-8 flex-1 w-full">
        
        {/* ================= ONGLET ÉTUDIANTS ================= */}
        {activeTab === 'etudiants' && (
          <div className="grid lg:grid-cols-3 gap-8">
            {/* Colonne Ajout d'étudiant */}
            <div className="lg:col-span-1 bg-white p-6 rounded-2xl shadow-sm border border-gray-100 h-fit">
              <h2 className="text-lg font-bold text-gray-800 mb-2">Inscrire un Étudiant</h2>
              <p className="text-xs text-gray-500 mb-6">
                Le mot de passe sera généré et envoyé automatiquement par email à l'étudiant pour son accès mobile.
              </p>
              
              {message && <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 rounded-xl text-sm">{message}</div>}
              {error && <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-xl text-sm">{error}</div>}
              
              <form onSubmit={handleAddStudent} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Nom complet</label>
                  <input 
                    type="text" 
                    required 
                    value={nom} 
                    onChange={(e) => setNom(e.target.value)}
                    placeholder="ex: Yassine Alami"
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                  />
                </div>
                
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Email de l'étudiant (@etu.uae.ac.ma)</label>
                  <input 
                    type="email" 
                    required 
                    value={email} 
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="etudiant@etu.uae.ac.ma"
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                  />
                </div>
                
                <button 
                  type="submit" 
                  disabled={loading} 
                  className="w-full bg-indigo-600 text-white text-sm font-semibold py-2.5 px-4 rounded-xl hover:bg-indigo-700 transition-colors disabled:opacity-50 shadow-sm"
                >
                  {loading ? "Génération & Envoi..." : "Inscrire l'étudiant"}
                </button>
              </form>

              <div className="mt-6 pt-6 border-t border-gray-100">
                <h3 className="text-xs font-bold text-gray-700 uppercase mb-2">Import en masse (Fichier CSV)</h3>
                <p className="text-xs text-gray-500 mb-3">
                  Format : colonnes <code className="bg-gray-100 px-1 py-0.5 rounded text-indigo-600">Nom, Email</code> (identifiants envoyés automatiquement par email).
                </p>
                <label className={`w-full flex items-center justify-center space-x-2 border-2 border-dashed border-indigo-200 hover:border-indigo-400 bg-indigo-50/40 hover:bg-indigo-50 text-indigo-700 text-xs font-semibold py-3 px-4 rounded-xl cursor-pointer transition-colors ${csvLoading ? 'opacity-50 cursor-not-allowed' : ''}`}>
                  <span>📁</span>
                  <span>{csvLoading ? "Importation en cours..." : "Lire à partir d'un fichier CSV"}</span>
                  <input 
                    type="file" 
                    accept=".csv" 
                    disabled={csvLoading}
                    onChange={handleCsvUpload} 
                    className="hidden" 
                  />
                </label>
              </div>
            </div>

            {/* Colonne Liste des étudiants */}
            <div className="lg:col-span-2 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
              <div className="flex justify-between items-center mb-6">
                <div>
                  <h2 className="text-lg font-bold text-gray-800">Liste des Étudiants Inscrits</h2>
                  <p className="text-xs text-gray-500">Étudiants ayant accès à l'application mobile de diagnostic.</p>
                </div>
                <button onClick={chargerEtudiants} className="text-xs text-indigo-600 hover:underline">Actualiser</button>
              </div>

              {etudiants.length === 0 ? (
                <div className="text-center py-12 text-gray-400 text-sm">
                  Aucun étudiant enregistré pour le moment. Utilisez le formulaire à gauche pour inscrire vos étudiants.
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-sm">
                    <thead>
                      <tr className="border-b text-gray-400 text-xs uppercase">
                        <th className="pb-3 font-semibold">Nom</th>
                        <th className="pb-3 font-semibold">Email</th>
                        <th className="pb-3 font-semibold">Date d'ajout</th>
                        <th className="pb-3 font-semibold">Statut</th>
                        <th className="pb-3 font-semibold text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {etudiants.map((e) => (
                        <tr key={e.id} className="hover:bg-gray-50">
                          <td className="py-3 font-medium text-gray-800">{e.nom}</td>
                          <td className="py-3 text-gray-600">{e.email}</td>
                          <td className="py-3 text-gray-400 text-xs">{e.date_creation || 'N/A'}</td>
                          <td className="py-3">
                            <span className="bg-green-100 text-green-700 text-xs font-semibold px-2.5 py-0.5 rounded-full">
                              Inscrit
                            </span>
                          </td>
                          <td className="py-3 text-right">
                            <div className="flex justify-end space-x-2">
                              <button 
                                onClick={() => handleStartEditStudent(e)} 
                                title="Modifier"
                                className="p-1.5 text-gray-500 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                              >
                                ✏️
                              </button>
                              <button 
                                onClick={() => handleDeleteStudent(e.id)} 
                                title="Supprimer"
                                className="p-1.5 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                              >
                                🗑️
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        )}

        {/* ================= ONGLET FICHES TISSUS ================= */}
        {activeTab === 'tissus' && (
          <div className="grid lg:grid-cols-3 gap-8">
            {/* Formulaire d'édition / création */}
            <div className="lg:col-span-1 bg-white p-6 rounded-2xl shadow-sm border border-gray-100 h-fit">
              <h2 className="text-lg font-bold text-gray-800 mb-2">Gérer les Fiches Tissus</h2>
              <p className="text-xs text-gray-500 mb-6">Ajouter ou modifier les détails pédagogiques consultables par les étudiants.</p>

              {tissuMsg && <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 rounded-xl text-sm">{tissuMsg}</div>}
              {tissuErr && <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-xl text-sm">{tissuErr}</div>}

              <form onSubmit={handleSaveTissu} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Type de tissu</label>
                  <select 
                    value={tissuClasse} 
                    onChange={(e) => setTissuClasse(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
                  >
                    {CLASSES_TISSUS.map((c) => (
                      <option key={c.code} value={c.code}>{c.label}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Description pédagogique</label>
                  <textarea 
                    rows={3} 
                    required 
                    value={tissuDescription} 
                    onChange={(e) => setTissuDescription(e.target.value)}
                    placeholder="Description biologique et caractéristiques histologiques..."
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none resize-none" 
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Fonction principale</label>
                  <input 
                    type="text" 
                    value={tissuFonction} 
                    onChange={(e) => setTissuFonction(e.target.value)}
                    placeholder="ex: Sécrétion, Protection, Isolation..."
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Localisation anatomique</label>
                  <input 
                    type="text" 
                    value={tissuLocalisation} 
                    onChange={(e) => setTissuLocalisation(e.target.value)}
                    placeholder="ex: Paroi intestinale, Épiderme..."
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                  />
                </div>

                <button 
                  type="submit" 
                  className="w-full bg-indigo-600 text-white text-sm font-semibold py-2.5 px-4 rounded-xl hover:bg-indigo-700 transition-colors shadow-sm"
                >
                  Enregistrer la fiche
                </button>
              </form>
            </div>

            {/* Liste des Fiches enregistrées */}
            <div className="lg:col-span-2 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
              <div className="flex justify-between items-center mb-6">
                <div>
                  <h2 className="text-lg font-bold text-gray-800">Fiches Pédagogiques Enregistrées ({tissus.length}/9)</h2>
                  <p className="text-xs text-gray-500">Informations consultables par les étudiants sur l'application mobile.</p>
                </div>
                <button onClick={chargerTissus} className="text-xs text-indigo-600 hover:underline">Actualiser</button>
              </div>

              {tissus.length === 0 ? (
                <div className="text-center py-12 text-gray-400 text-sm">
                  Aucune fiche enregistrée. Remplissez le formulaire pour renseigner la première fiche.
                </div>
              ) : (
                <div className="grid md:grid-cols-2 gap-4">
                  {tissus.map((t) => (
                    <div key={t.id} className="p-4 border border-gray-200 rounded-xl bg-gray-50/50 space-y-2 flex flex-col justify-between">
                      <div className="space-y-2">
                        <div className="flex justify-between items-center">
                          <span className="bg-indigo-600 text-white font-bold text-xs px-2.5 py-0.5 rounded-md">
                            {t.nom_classe}
                          </span>
                          <div className="flex items-center space-x-2">
                            <button 
                              onClick={() => handleEditTissu(t)} 
                              className="text-xs text-indigo-600 hover:underline font-medium"
                            >
                              Modifier
                            </button>
                            <span className="text-gray-300">|</span>
                            <button 
                              onClick={() => handleDeleteTissu(t.id, t.nom_classe)} 
                              className="text-xs text-red-600 hover:underline font-medium"
                            >
                              Supprimer
                            </button>
                          </div>
                        </div>
                        <p className="text-xs text-gray-700">{t.description}</p>
                        <div className="text-xs text-gray-500 border-t pt-2 space-y-1">
                          <div><strong>Fonction :</strong> {t.fonction || '-'}</div>
                          <div><strong>Localisation :</strong> {t.localisation || '-'}</div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </main>

      {/* Modal Modification Étudiant */}
      {editingStudent && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-xl border border-gray-100">
            <h3 className="text-lg font-bold text-gray-800 mb-1">
              Modifier l'Étudiant
            </h3>
            <p className="text-xs text-gray-500 mb-4">Modifiez le nom et l'adresse email de l'étudiant.</p>
            
            <form onSubmit={handleSaveEditStudent} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Nom complet</label>
                <input 
                  type="text" 
                  required 
                  value={editNom} 
                  onChange={(e) => setEditNom(e.target.value)}
                  className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Email (@etu.uae.ac.ma)</label>
                <input 
                  type="email" 
                  required 
                  value={editEmail} 
                  onChange={(e) => setEditEmail(e.target.value)}
                  className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                />
              </div>

              <div className="flex space-x-3 pt-2">
                <button 
                  type="button" 
                  onClick={() => setEditingStudent(null)} 
                  className="flex-1 px-4 py-2 text-sm font-semibold text-gray-600 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors"
                >
                  Annuler
                </button>
                <button 
                  type="submit" 
                  className="flex-1 px-4 py-2 text-sm font-semibold text-white bg-indigo-600 rounded-xl hover:bg-indigo-700 transition-colors shadow-sm"
                >
                  Enregistrer
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Résultat Import CSV */}
      {csvResultModal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl p-6 w-full max-w-lg shadow-xl border border-gray-100 max-h-[85vh] flex flex-col">
            <h3 className="text-lg font-bold text-gray-800 mb-1">
              Résultat de l'import CSV (Étudiants)
            </h3>
            <p className="text-xs text-gray-500 mb-4">
              {csvResultModal.total_crees} étudiant(s) inscrit(s) avec succès.
            </p>

            {csvResultModal.erreurs && csvResultModal.erreurs.length > 0 && (
              <div className="mb-4 p-3 bg-amber-50 border border-amber-200 text-amber-800 rounded-xl text-xs space-y-1">
                <div className="font-bold">Avertissements / Erreurs ({csvResultModal.erreurs.length}) :</div>
                <ul className="list-disc list-inside space-y-0.5 max-h-28 overflow-y-auto">
                  {csvResultModal.erreurs.map((err, i) => (
                    <li key={i}>{err}</li>
                  ))}
                </ul>
              </div>
            )}

            <div className="flex-1 overflow-y-auto mb-4 border rounded-xl divide-y text-xs">
              {csvResultModal.crees.map((e, idx) => (
                <div key={idx} className="p-3 flex justify-between items-center hover:bg-gray-50">
                  <div>
                    <div className="font-semibold text-gray-800">{e.nom}</div>
                    <div className="text-gray-500">{e.email}</div>
                  </div>
                  <div className="bg-indigo-50 border border-indigo-200 px-2.5 py-1 rounded-md text-indigo-700 font-mono font-bold">
                    {e.mot_de_passe}
                  </div>
                </div>
              ))}
            </div>

            <button
              onClick={() => setCsvResultModal(null)}
              className="w-full py-2.5 text-sm font-semibold text-white bg-indigo-600 rounded-xl hover:bg-indigo-700 transition-colors shadow-sm"
            >
              Fermer
            </button>
          </div>
        </div>
      )}

      {/* Pop-up Obligatoire de Première Connexion (Changement de mot de passe) */}
      {doitChangerMdp && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl border border-gray-100">
            <div className="w-12 h-12 bg-amber-100 text-amber-600 rounded-full flex items-center justify-center text-xl mb-3">
              🔒
            </div>
            <h3 className="text-lg font-bold text-gray-800 mb-1">
              Première connexion requise
            </h3>
            <p className="text-xs text-gray-500 mb-4">
              Pour des raisons de sécurité, vous devez définir votre propre mot de passe personnel avant de continuer.
            </p>

            {mdpErr && (
              <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-xl text-xs">
                {mdpErr}
              </div>
            )}

            <form onSubmit={handlePremierChangementMdp} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Nouveau mot de passe</label>
                <input 
                  type="password" 
                  required 
                  value={nouveauMdp} 
                  onChange={(e) => setNouveauMdp(e.target.value)}
                  placeholder="Minimum 6 caractères"
                  className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-700 mb-1">Confirmer le mot de passe</label>
                <input 
                  type="password" 
                  required 
                  value={confirmMdp} 
                  onChange={(e) => setConfirmMdp(e.target.value)}
                  placeholder="Confirmez le mot de passe"
                  className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                />
              </div>

              <button 
                type="submit" 
                disabled={mdpLoading}
                className="w-full py-2.5 text-sm font-semibold text-white bg-indigo-600 rounded-xl hover:bg-indigo-700 transition-colors shadow-sm disabled:opacity-50"
              >
                {mdpLoading ? "Enregistrement..." : "Définir mon mot de passe et continuer"}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}