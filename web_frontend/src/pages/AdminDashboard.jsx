import { useState, useEffect } from 'react';
import axios from 'axios';
import { API_URL } from '../config';
import { useNavigate } from 'react-router-dom';

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

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState('profs'); // 'profs', 'etudiants', 'tissus'
  
  // États Professeurs & Édition
  const [profs, setProfs] = useState([]);
  const [nomProf, setNomProf] = useState('');
  const [emailProf, setEmailProf] = useState('');
  const [profMsg, setProfMsg] = useState('');
  const [profErr, setProfErr] = useState('');
  
  // Édition d'utilisateur (Prof ou Étudiant)
  const [editingUser, setEditingUser] = useState(null); // { id, nom, email, role }
  const [editNom, setEditNom] = useState('');
  const [editEmail, setEditEmail] = useState('');

  const handleDeleteUser = async (id, type) => {
    if (!window.confirm("Voulez-vous vraiment supprimer cet utilisateur ?")) return;
    try {
      await axios.delete(`${API_URL}/utilisateurs/${id}`);
      if (type === 'prof') chargerProfesseurs();
      else chargerEtudiants();
    } catch (e) {
      alert("Erreur lors de la suppression");
    }
  };

  const handleStartEdit = (u, type) => {
    setEditingUser({ ...u, type });
    setEditNom(u.nom);
    setEditEmail(u.email);
  };

  const handleSaveEditUser = async (e) => {
    e.preventDefault();
    try {
      await axios.put(`${API_URL}/utilisateurs/${editingUser.id}`, {
        nom: editNom,
        email: editEmail
      });
      setEditingUser(null);
      if (editingUser.type === 'prof') chargerProfesseurs();
      else chargerEtudiants();
    } catch (err) {
      alert(err.response?.data?.detail || "Erreur lors de la modification");
    }
  };
  
  // États Étudiants
  const [etudiants, setEtudiants] = useState([]);
  const [loadingEtudiants, setLoadingEtudiants] = useState(false);

  // États Tissus
  const [tissus, setTissus] = useState([]);
  const [tissuClasse, setTissuClasse] = useState('ADI');
  const [tissuDescription, setTissuDescription] = useState('');
  const [tissuFonction, setTissuFonction] = useState('');
  const [tissuLocalisation, setTissuLocalisation] = useState('');
  const [tissuMsg, setTissuMsg] = useState('');
  const [tissuErr, setTissuErr] = useState('');

  // CSV États
  const [csvLoading, setCsvLoading] = useState(false);
  const [csvResultModal, setCsvResultModal] = useState(null); // { crees: [], erreurs: [] }

  // Changement mot de passe première connexion
  const [doitChangerMdp, setDoitChangerMdp] = useState(false);
  const [nouveauMdp, setNouveauMdp] = useState('');
  const [confirmMdp, setConfirmMdp] = useState('');
  const [mdpErr, setMdpErr] = useState('');
  const [mdpLoading, setMdpLoading] = useState(false);

  const navigate = useNavigate();
  const token = localStorage.getItem('token');

  useEffect(() => {
    if (!token) {
      navigate('/login');
      return;
    }
    const doitChanger = localStorage.getItem('doit_changer_mot_de_passe') === 'true';
    if (doitChanger) {
      setDoitChangerMdp(true);
    }
    chargerProfesseurs();
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
      const res = await axios.post(`${API_URL}/admin/professeurs/csv`, formData, {
        headers: { 
          Authorization: `Bearer ${token}`,
          'Content-Type': 'multipart/form-data'
        }
      });
      setCsvResultModal(res.data);
      chargerProfesseurs();
    } catch (err) {
      alert(err.response?.data?.detail || "Erreur lors de l'import CSV");
    } finally {
      setCsvLoading(false);
      e.target.value = '';
    }
  };

  const handleLogout = () => {
    localStorage.clear();
    navigate('/login');
  };

  const chargerProfesseurs = async () => {
    try {
      const res = await axios.get(`${API_URL}/admin/professeurs`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setProfs(res.data);
    } catch (e) {
      console.error("Erreur chargement profs:", e);
    }
  };

  const chargerEtudiants = async () => {
    setLoadingEtudiants(true);
    try {
      const res = await axios.get(`${API_URL}/admin/etudiants`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setEtudiants(res.data);
    } catch (e) {
      console.error("Erreur chargement étudiants:", e);
    } finally {
      setLoadingEtudiants(false);
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

  const handleAddProf = async (e) => {
    e.preventDefault();
    setProfMsg('');
    setProfErr('');
    
    try {
      const res = await axios.post(`${API_URL}/admin/professeurs`, {
        nom: nomProf,
        email: emailProf
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      setProfMsg(res.data.message);
      setNomProf('');
      setEmailProf('');
      chargerProfesseurs();
    } catch (err) {
      setProfErr(err.response?.data?.detail || "Erreur lors de l'ajout");
    }
  };

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

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* En-tête */}
      <header className="bg-white shadow-sm border-b sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-4 py-4 flex justify-between items-center">
          <div className="flex items-center space-x-3">
            <div className="bg-indigo-600 text-white p-2 rounded-lg font-bold text-lg">🔬</div>
            <div>
              <h1 className="text-xl font-bold text-gray-800">Espace Administrateur</h1>
              <p className="text-xs text-gray-500">Plateforme de Classification de Tissus</p>
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
            onClick={() => setActiveTab('profs')}
            className={`py-4 font-semibold text-sm border-b-2 transition-all flex items-center space-x-2 ${
              activeTab === 'profs' 
                ? 'border-indigo-600 text-indigo-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <span>👨‍🏫 Professeurs</span>
            <span className="bg-gray-100 text-gray-700 text-xs px-2 py-0.5 rounded-full">{profs.length}</span>
          </button>
          
          <button 
            onClick={() => setActiveTab('etudiants')}
            className={`py-4 font-semibold text-sm border-b-2 transition-all flex items-center space-x-2 ${
              activeTab === 'etudiants' 
                ? 'border-indigo-600 text-indigo-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <span>🎓 Étudiants</span>
            <span className="bg-gray-100 text-gray-700 text-xs px-2 py-0.5 rounded-full">{etudiants.length}</span>
          </button>

        </div>
      </div>

      {/* Contenu Principal */}
      <main className="max-w-6xl mx-auto px-4 py-8 flex-1 w-full">
        
        {/* ================= ONGLET PROFESSEURS ================= */}
        {activeTab === 'profs' && (
          <div className="grid lg:grid-cols-3 gap-8">
            {/* Formulaire d'ajout */}
            <div className="lg:col-span-1 bg-white p-6 rounded-2xl shadow-sm border border-gray-100 h-fit">
              <h2 className="text-lg font-bold text-gray-800 mb-2">Ajouter un Professeur</h2>
              <p className="text-xs text-gray-500 mb-6">Inscrire un professeur pour qu'il puisse gérer ses étudiants.</p>
              
              {profMsg && <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 rounded-xl text-sm">{profMsg}</div>}
              {profErr && <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-xl text-sm">{profErr}</div>}
              
              <form onSubmit={handleAddProf} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Nom complet</label>
                  <input 
                    type="text" 
                    required 
                    value={nomProf} 
                    onChange={(e) => setNomProf(e.target.value)}
                    placeholder="Pr. Dupont"
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                  />
                </div>
                
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1">Email institutionnel (@etu.uae.ac.ma)</label>
                  <input 
                    type="email" 
                    required 
                    value={emailProf} 
                    onChange={(e) => setEmailProf(e.target.value)}
                    placeholder="prof@etu.uae.ac.ma"
                    className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none" 
                  />
                </div>
                
                <button 
                  type="submit" 
                  className="w-full bg-indigo-600 text-white text-sm font-semibold py-2.5 px-4 rounded-xl hover:bg-indigo-700 transition-colors shadow-sm"
                >
                  Ajouter le professeur
                </button>
              </form>

              <div className="mt-6 pt-6 border-t border-gray-100">
                <h3 className="text-xs font-bold text-gray-700 uppercase mb-2">Import en masse (Fichier CSV)</h3>
                <p className="text-xs text-gray-500 mb-3">
                  Format : colonnes <code className="bg-gray-100 px-1 py-0.5 rounded text-indigo-600">Nom, Email</code> (les mots de passe seront générés et envoyés automatiquement par email).
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

            {/* Liste des Professeurs */}
            <div className="lg:col-span-2 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-lg font-bold text-gray-800">Liste des Professeurs Inscrits</h2>
                <button onClick={chargerProfesseurs} className="text-xs text-indigo-600 hover:underline">Actualiser</button>
              </div>

              {profs.length === 0 ? (
                <div className="text-center py-12 text-gray-400 text-sm">
                  Aucun professeur enregistré pour le moment.
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-sm">
                    <thead>
                      <tr className="border-b text-gray-400 text-xs uppercase">
                        <th className="pb-3 font-semibold">Nom</th>
                        <th className="pb-3 font-semibold">Email</th>
                        <th className="pb-3 font-semibold">Date d'inscription</th>
                        <th className="pb-3 font-semibold text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {profs.map((p) => (
                        <tr key={p.id} className="hover:bg-gray-50">
                          <td className="py-3 font-medium text-gray-800">{p.nom}</td>
                          <td className="py-3 text-gray-600">{p.email}</td>
                          <td className="py-3 text-gray-400 text-xs">{p.date_creation || 'N/A'}</td>
                          <td className="py-3 text-right">
                            <div className="flex justify-end space-x-2">
                              <button 
                                onClick={() => handleStartEdit(p, 'prof')} 
                                title="modifier"
                                className="p-1.5 text-gray-500 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                              >
                                ✏️
                              </button>
                              <button 
                                onClick={() => handleDeleteUser(p.id, 'prof')} 
                                title="supprimer"
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

        {/* ================= ONGLET ÉTUDIANTS ================= */}
        {activeTab === 'etudiants' && (
          <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <div className="flex justify-between items-center mb-6">
              <div>
                <h2 className="text-lg font-bold text-gray-800">Tous les Étudiants Inscrits</h2>
                <p className="text-xs text-gray-500">Comptes créés par les professeurs pour l'application mobile.</p>
              </div>
              <button onClick={chargerEtudiants} className="text-xs text-indigo-600 hover:underline">Actualiser</button>
            </div>

            {loadingEtudiants ? (
              <div className="text-center py-12 text-gray-400 text-sm">Chargement...</div>
            ) : etudiants.length === 0 ? (
              <div className="text-center py-12 text-gray-400 text-sm">
                Aucun étudiant n'a encore été inscrit par les professeurs.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead>
                    <tr className="border-b text-gray-400 text-xs uppercase">
                      <th className="pb-3 font-semibold">ID</th>
                      <th className="pb-3 font-semibold">Nom de l'étudiant</th>
                      <th className="pb-3 font-semibold">Email</th>
                      <th className="pb-3 font-semibold">Date de création</th>
                      <th className="pb-3 font-semibold">Statut</th>
                      <th className="pb-3 font-semibold text-right">Gestion</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {etudiants.map((e) => (
                      <tr key={e.id} className="hover:bg-gray-50">
                        <td className="py-3 text-gray-400 text-xs font-mono">#{e.id}</td>
                        <td className="py-3 font-medium text-gray-800">{e.nom}</td>
                        <td className="py-3 text-gray-600">{e.email}</td>
                        <td className="py-3 text-gray-400 text-xs">{e.date_creation || 'N/A'}</td>
                        <td className="py-3">
                          <span className="bg-green-100 text-green-700 text-xs font-semibold px-2.5 py-0.5 rounded-full">
                            Actif
                          </span>
                        </td>
                        <td className="py-3 text-right">
                          <span className="text-xs text-gray-400 italic">
                            Géré par les professeurs
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        

      </main>

      {/* Modal de Modification d'utilisateur */}
      {editingUser && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-xl border border-gray-100">
            <h3 className="text-lg font-bold text-gray-800 mb-1">
              Modifier {editingUser.type === 'prof' ? 'le Professeur' : "l'Étudiant"}
            </h3>
            <p className="text-xs text-gray-500 mb-4">Modifiez le nom et l'adresse email de l'utilisateur.</p>
            
            <form onSubmit={handleSaveEditUser} className="space-y-4">
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
                  onClick={() => setEditingUser(null)} 
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
              Résultat de l'import CSV (Professeurs)
            </h3>
            <p className="text-xs text-gray-500 mb-4">
              {csvResultModal.total_crees} professeur(s) créé(s) avec succès.
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
              {csvResultModal.crees.map((p, idx) => (
                <div key={idx} className="p-3 flex justify-between items-center hover:bg-gray-50">
                  <div>
                    <div className="font-semibold text-gray-800">{p.nom}</div>
                    <div className="text-gray-500">{p.email}</div>
                  </div>
                  <div className="bg-green-50 border border-green-200 px-2.5 py-1 rounded-md text-green-700 font-medium">
                    Importation faite avec succ?s
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
