from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import tensorflow as tf
import numpy as np
from PIL import Image
import io
import os
import secrets
import string
import csv
from database import get_db, creer_tables, Utilisateur, DOMAINE_AUTORISE, DOMAINE_ETUDIANT, InfoTissu, HistoriqueAnalyse
from auth import hacher_mot_de_passe, verifier_mot_de_passe, creer_token, verifier_token_prof, verifier_token_admin, verifier_token_etudiant, verifier_token_authentifie
from email_service import envoyer_email_identifiants
from minio_service import uploader_image_tissu, initialiser_bucket
from sqlalchemy.orm import Session
from fastapi import Depends, HTTPException
from pydantic import BaseModel


app = FastAPI()
creer_tables()
initialiser_bucket()

# Creation automatique du compte admin au demarrage s'il n'existe pas encore
try:
    with SessionLocal() as db_init:
        if not db_init.query(Utilisateur).filter(Utilisateur.role == "admin").first():
            db_init.add(Utilisateur(
                nom="Administrateur",
                email="admin@etu.uae.ac.ma",
                mot_de_passe=hacher_mot_de_passe("admin123"),
                role="admin",
                doit_changer_mot_de_passe=False
            ))
            db_init.commit()
            print("Compte Admin cree automatiquement au demarrage !")
except Exception as e:
    print(f"Avertissement initialisation admin: {e}")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

model = tf.keras.models.load_model("modele_tissus_from_scratch_final_tissu.keras")

class_names = ['ADI', 'BACK', 'DEB', 'LYM', 'MUC', 'MUS', 'NORM', 'STR', 'TUM']

class AdminAjoutProfData(BaseModel):
    nom: str
    email: str

class ProfAjoutEtudiantData(BaseModel):
    nom: str
    email: str

class ConnexionData(BaseModel):
    email: str
    mot_de_passe: str

class ChangerMotDePasseEtudiantData(BaseModel):
    ancien_mot_de_passe: str
    nouveau_mot_de_passe: str

class PremierChangementMotDePasseData(BaseModel):
    nouveau_mot_de_passe: str

def generer_mot_de_passe(longueur=10):
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(longueur))

@app.post("/admin/professeurs")
def ajouter_professeur(
    data: AdminAjoutProfData, 
    db: Session = Depends(get_db),
    admin_connecte: dict = Depends(verifier_token_admin)
):
    if not data.email.endswith(DOMAINE_AUTORISE):
        raise HTTPException(status_code=400, detail=f"L'email doit être institutionnel ({DOMAINE_AUTORISE})")
    
    existant = db.query(Utilisateur).filter(Utilisateur.email == data.email).first()
    if existant:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")
    
    # Générer mot de passe automatique pour le prof
    mot_de_passe_genere = generer_mot_de_passe()
    
    nouvel_utilisateur = Utilisateur(
        nom=data.nom,
        email=data.email,
        mot_de_passe=hacher_mot_de_passe(mot_de_passe_genere),
        role="prof",
        doit_changer_mot_de_passe=True
    )
    db.add(nouvel_utilisateur)
    db.commit()
    
    # Envoi de l'email automatique avec les identifiants
    envoyer_email_identifiants(data.email, data.nom, mot_de_passe_genere)
    
    return {"message": "Professeur créé avec succès, identifiants envoyés par email", "email": data.email}

@app.post("/prof/etudiants")
def ajouter_etudiant(
    data: ProfAjoutEtudiantData, 
    db: Session = Depends(get_db),
    prof_connecte: dict = Depends(verifier_token_prof)
):
    email_propre = data.email.strip().lower()
    nom_propre = data.nom.strip()

    if not email_propre.endswith(DOMAINE_ETUDIANT):
        raise HTTPException(status_code=400, detail=f"L'email doit se terminer par {DOMAINE_ETUDIANT}")

    # Générer le mot de passe avant d'insérer
    mot_de_passe_genere = generer_mot_de_passe()
    
    existant = db.query(Utilisateur).filter(Utilisateur.email == email_propre).first()
    if existant:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")
    
    nouvel_utilisateur = Utilisateur(
        nom=nom_propre,
        email=email_propre,
        mot_de_passe=hacher_mot_de_passe(mot_de_passe_genere),
        role="etudiant",
        doit_changer_mot_de_passe=True
    )
    db.add(nouvel_utilisateur)
    db.commit()
    
    # Envoi de l'email (non-bloquant si le serveur SMTP est indisponible)
    try:
        envoyer_email_identifiants(data.email, data.nom, mot_de_passe_genere)
    except Exception as e:
        print(f"Avertissement : L'email n'a pas pu être envoyé ({e})")
    
    return {"message": f"Étudiant créé avec succès ! (Mot de passe généré : {mot_de_passe_genere})", "email": data.email}


@app.get("/admin/professeurs")
def lister_professeurs(db: Session = Depends(get_db), admin_connecte: dict = Depends(verifier_token_admin)):
    profs = db.query(Utilisateur).filter(Utilisateur.role == "prof").order_by(Utilisateur.date_creation.desc()).all()
    return [{"id": p.id, "nom": p.nom, "email": p.email, "date_creation": p.date_creation.strftime("%Y-%m-%d %H:%M") if p.date_creation else ""} for p in profs]

@app.get("/admin/etudiants")
def lister_etudiants_admin(db: Session = Depends(get_db), admin_connecte: dict = Depends(verifier_token_admin)):
    etudiants = db.query(Utilisateur).filter(Utilisateur.role == "etudiant").order_by(Utilisateur.date_creation.desc()).all()
    return [{"id": e.id, "nom": e.nom, "email": e.email, "date_creation": e.date_creation.strftime("%Y-%m-%d %H:%M") if e.date_creation else ""} for e in etudiants]

@app.get("/prof/etudiants")
def lister_etudiants_prof(db: Session = Depends(get_db), prof_connecte: dict = Depends(verifier_token_prof)):
    etudiants = db.query(Utilisateur).filter(Utilisateur.role == "etudiant").order_by(Utilisateur.date_creation.desc()).all()
    return [{"id": e.id, "nom": e.nom, "email": e.email, "date_creation": e.date_creation.strftime("%Y-%m-%d %H:%M") if e.date_creation else ""} for e in etudiants]

class ModificationUtilisateurData(BaseModel):
    nom: str
    email: str

@app.put("/utilisateurs/{user_id}")
def modifier_utilisateur(user_id: int, data: ModificationUtilisateurData, db: Session = Depends(get_db)):
    u = db.query(Utilisateur).filter(Utilisateur.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    if not data.email.endswith(DOMAINE_AUTORISE):
        raise HTTPException(status_code=400, detail=f"L'email doit se terminer par {DOMAINE_AUTORISE}")
    u.nom = data.nom
    u.email = data.email
    db.commit()
    return {"message": "Utilisateur mis à jour avec succès"}

@app.delete("/utilisateurs/{user_id}")
def supprimer_utilisateur(user_id: int, db: Session = Depends(get_db)):
    u = db.query(Utilisateur).filter(Utilisateur.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    db.delete(u)
    db.commit()
    return {"message": "Utilisateur supprimé avec succès"}

@app.post("/admin/professeurs/csv")
async def importer_professeurs_csv(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin_connecte: dict = Depends(verifier_token_admin)
):
    contents = await file.read()
    try:
        decoded = contents.decode("utf-8")
    except UnicodeDecodeError:
        decoded = contents.decode("latin-1")
        
    reader = csv.reader(io.StringIO(decoded))
    profs_crees = []
    erreurs = []
    
    first_row = True
    for row in reader:
        if not row or len(row) < 2:
            continue
        nom = row[0].strip()
        email = row[1].strip().lower()
        
        # Ignorer l'entête éventuel (nom, email)
        if first_row and ("nom" in nom.lower() or "email" in email.lower()):
            first_row = False
            continue
        first_row = False
        
        if not email.endswith(DOMAINE_AUTORISE):
            erreurs.append(f"{email}: Domaine non autorisé (doit finir par {DOMAINE_AUTORISE})")
            continue
            
        existant = db.query(Utilisateur).filter(Utilisateur.email == email).first()
        if existant:
            erreurs.append(f"{email}: Cet email existe déjà")
            continue
            
        mdp = generer_mot_de_passe()
        prof = Utilisateur(
            nom=nom,
            email=email,
            mot_de_passe=hacher_mot_de_passe(mdp),
            role="prof",
            doit_changer_mot_de_passe=True
        )
        db.add(prof)
        db.commit()
        
        try:
            envoyer_email_identifiants(email, nom, mdp)
        except Exception as e:
            print(f"Erreur envoi email pour {email}: {e}")
            
        profs_crees.append({"nom": nom, "email": email})
        
    return {
        "crees": profs_crees,
        "erreurs": erreurs,
        "total_crees": len(profs_crees)
    }

@app.post("/prof/etudiants/csv")
async def importer_etudiants_csv(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    prof_connecte: dict = Depends(verifier_token_prof)
):
    contents = await file.read()
    try:
        decoded = contents.decode("utf-8")
    except UnicodeDecodeError:
        decoded = contents.decode("latin-1")
        
    reader = csv.reader(io.StringIO(decoded))
    etudiants_crees = []
    erreurs = []
    
    first_row = True
    for row in reader:
        if not row or len(row) < 2:
            continue
        nom = row[0].strip()
        email = row[1].strip().lower()
        
        # Ignorer l'entête éventuel
        if first_row and ("nom" in nom.lower() or "email" in email.lower()):
            first_row = False
            continue
        first_row = False
        
        if not email.endswith(DOMAINE_ETUDIANT):
            erreurs.append(f"{email}: Domaine non autorisé (doit finir par {DOMAINE_ETUDIANT})")
            continue
            
        existant = db.query(Utilisateur).filter(Utilisateur.email == email).first()
        if existant:
            erreurs.append(f"{email}: Cet email existe déjà")
            continue
            
        mdp = generer_mot_de_passe()
        etudiant = Utilisateur(
            nom=nom,
            email=email,
            mot_de_passe=hacher_mot_de_passe(mdp),
            role="etudiant",
            doit_changer_mot_de_passe=True
        )
        db.add(etudiant)
        db.commit()
        
        try:
            envoyer_email_identifiants(email, nom, mdp)
        except Exception as e:
            print(f"Erreur envoi email pour {email}: {e}")
            
        etudiants_crees.append({"nom": nom, "email": email, "mot_de_passe": mdp})
        
    return {
        "crees": etudiants_crees,
        "erreurs": erreurs,
        "total_crees": len(etudiants_crees)
    }

@app.post("/premier-changement-mot-de-passe")
def premier_changement_mot_de_passe(
    data: PremierChangementMotDePasseData,
    db: Session = Depends(get_db),
    utilisateur_connecte: dict = Depends(verifier_token_authentifie)
):
    u = db.query(Utilisateur).filter(Utilisateur.email == utilisateur_connecte["email"]).first()
    if not u:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    if len(data.nouveau_mot_de_passe.strip()) < 6:
        raise HTTPException(status_code=400, detail="Le mot de passe doit contenir au moins 6 caractères")
        
    u.mot_de_passe = hacher_mot_de_passe(data.nouveau_mot_de_passe.strip())
    u.doit_changer_mot_de_passe = False
    db.commit()
    return {"message": "Mot de passe mis à jour avec succès"}

@app.post("/connexion")
def connexion(data: ConnexionData, db: Session = Depends(get_db)):
    utilisateur = db.query(Utilisateur).filter(Utilisateur.email == data.email).first()
    
    if not utilisateur or not verifier_mot_de_passe(data.mot_de_passe, utilisateur.mot_de_passe):
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")
    
    token = creer_token(utilisateur.email, utilisateur.role)
    
    return {
        "access_token": token,
        "role": utilisateur.role,
        "nom": utilisateur.nom,
        "doit_changer_mot_de_passe": bool(utilisateur.doit_changer_mot_de_passe)
    } 

@app.post("/predict")
async def predict(file: UploadFile = File(...), db: Session = Depends(get_db), etudiant_connecte: dict = Depends(verifier_token_etudiant)):
    contents = await file.read()
    img = Image.open(io.BytesIO(contents)).convert("RGB")
    img = img.resize((224, 224))
    
    img_array = np.array(img)
    img_array = np.expand_dims(img_array, axis=0)
    
    predictions = model.predict(img_array)
    class_index = np.argmax(predictions[0])
    classe_predite = class_names[class_index]
    confidence = float(predictions[0][class_index]) * 100
    
    # 1. Sauvegarde de l'image dans MinIO
    extension = file.filename.split(".")[-1] if file.filename and "." in file.filename else "jpg"
    image_minio_nom = uploader_image_tissu(contents, nom_classe=classe_predite, extension=extension)
    
    # 2. Enregistrement dans l'historique
    try:
        utilisateur = db.query(Utilisateur).filter(Utilisateur.email == etudiant_connecte["email"]).first()
        historique = HistoriqueAnalyse(
            utilisateur_id=utilisateur.id if utilisateur else None,
            classe_predite=classe_predite,
            confiance=round(confidence, 2),
            image_minio=image_minio_nom
        )
        db.add(historique)
        db.commit()
    except Exception as e:
        print(f"Erreur d'enregistrement dans l'historique : {e}")

    return {
        "analyse_id": historique.id if 'historique' in locals() and historique else None,
        "classe_predite": classe_predite,
        "confiance": round(confidence, 2),
        "image_minio": image_minio_nom
    }

class InfoTissuData(BaseModel):
    nom_classe: str
    description: str
    fonction: str
    localisation: str

@app.post("/info-tissu")
def ajouter_ou_modifier_info_tissu(
    data: InfoTissuData, 
    db: Session = Depends(get_db),
    prof_connecte: dict = Depends(verifier_token_prof)
):
    existant = db.query(InfoTissu).filter(InfoTissu.nom_classe == data.nom_classe).first()
    if existant:
        existant.description = data.description
        existant.fonction = data.fonction
        existant.localisation = data.localisation
        db.commit()
        return {"message": f"Informations pour le tissu '{data.nom_classe}' mises à jour"}
    
    info = InfoTissu(
        nom_classe=data.nom_classe,
        description=data.description,
        fonction=data.fonction,
        localisation=data.localisation
    )
    db.add(info)
    db.commit()
    return {"message": f"Informations pour le tissu '{data.nom_classe}' ajoutées avec succès"}

@app.delete("/info-tissu/{tissu_id}")
def supprimer_info_tissu(
    tissu_id: int,
    db: Session = Depends(get_db),
    prof_connecte: dict = Depends(verifier_token_prof)
):
    tissu = db.query(InfoTissu).filter(InfoTissu.id == tissu_id).first()
    if not tissu:
        raise HTTPException(status_code=404, detail="Fiche de tissu non trouv?e")
    db.delete(tissu)
    db.commit()
    return {"message": "Fiche de tissu supprim?e avec succ?s"}

@app.get("/info-tissus")
def lister_tous_les_tissus(db: Session = Depends(get_db)):
    tissus = db.query(InfoTissu).all()
    return [
        {
            "id": t.id,
            "nom_classe": t.nom_classe,
            "description": t.description,
            "fonction": t.fonction,
            "localisation": t.localisation
        }
        for t in tissus
    ]

@app.get("/info-tissu/{nom_classe}")
def obtenir_info_tissu(nom_classe: str, db: Session = Depends(get_db)):
    info = db.query(InfoTissu).filter(InfoTissu.nom_classe == nom_classe).first()
    if not info:
        raise HTTPException(status_code=404, detail="Information non trouvée pour ce type de tissu")
    return {
        "nom_classe": info.nom_classe,
        "description": info.description,
        "fonction": info.fonction,
        "localisation": info.localisation
    }

@app.post("/etudiant/changer-mot-de-passe")
def changer_mot_de_passe_etudiant(
    data: ChangerMotDePasseEtudiantData,
    db: Session = Depends(get_db),
    etudiant_connecte: dict = Depends(verifier_token_etudiant)
):
    utilisateur = db.query(Utilisateur).filter(Utilisateur.email == etudiant_connecte["email"]).first()
    if not utilisateur:
        raise HTTPException(status_code=404, detail="Étudiant non trouvé")
    if not verifier_mot_de_passe(data.ancien_mot_de_passe, utilisateur.mot_de_passe):
        raise HTTPException(status_code=400, detail="Ancien mot de passe incorrect")
    if len(data.nouveau_mot_de_passe.strip()) < 6:
        raise HTTPException(status_code=400, detail="Le mot de passe doit contenir au moins 6 caractères")
    utilisateur.mot_de_passe = hacher_mot_de_passe(data.nouveau_mot_de_passe.strip())
    db.commit()
    return {"message": "Mot de passe modifié avec succès"}

@app.get("/")
def home():
    return {"message": "API de classification de tissus - en ligne"}


class ScoreQcmData(BaseModel):
    analyse_id: int
    score: int
    total: int

@app.post("/historique/qcm")
def enregistrer_score_qcm(
    data: ScoreQcmData,
    db: Session = Depends(get_db),
    etudiant_connecte: dict = Depends(verifier_token_etudiant)
):
    utilisateur = db.query(Utilisateur).filter(Utilisateur.email == etudiant_connecte["email"]).first()
    if not utilisateur:
        raise HTTPException(status_code=404, detail="?tudiant non trouv?")
    
    analyse = db.query(HistoriqueAnalyse).filter(
        HistoriqueAnalyse.id == data.analyse_id,
        HistoriqueAnalyse.utilisateur_id == utilisateur.id
    ).first()
    
    if not analyse:
        raise HTTPException(status_code=404, detail="Analyse non trouv?e")
    
    analyse.score_qcm = data.score
    analyse.total_qcm = data.total
    db.commit()
    return {"message": "Score QCM enregistr? avec succ?s"}

@app.get('/historique')
def lister_historique(db: Session = Depends(get_db), etudiant_connecte: dict = Depends(verifier_token_etudiant)):
    utilisateur = db.query(Utilisateur).filter(Utilisateur.email == etudiant_connecte["email"]).first()
    if not utilisateur:
        raise HTTPException(status_code=404, detail="Étudiant non trouvé")

    analyses = db.query(HistoriqueAnalyse).filter(HistoriqueAnalyse.utilisateur_id == utilisateur.id).order_by(HistoriqueAnalyse.date_analyse.desc()).limit(50).all()
    return [{'id': a.id, 'classe_predite': a.classe_predite, 'confiance': a.confiance, 'image_minio': a.image_minio, 'score_qcm': a.score_qcm, 'total_qcm': a.total_qcm, 'date_analyse': a.date_analyse.strftime('%Y-%m-%d %H:%M') if a.date_analyse else ''} for a in analyses]

@app.delete('/historique/{analyse_id}')
def supprimer_analyse_historique(
    analyse_id: int,
    db: Session = Depends(get_db),
    etudiant_connecte: dict = Depends(verifier_token_etudiant)
):
    utilisateur = db.query(Utilisateur).filter(Utilisateur.email == etudiant_connecte["email"]).first()
    if not utilisateur:
        raise HTTPException(status_code=404, detail="?tudiant non trouv?")

    analyse = db.query(HistoriqueAnalyse).filter(
        HistoriqueAnalyse.id == analyse_id,
        HistoriqueAnalyse.utilisateur_id == utilisateur.id
    ).first()

    if not analyse:
        raise HTTPException(status_code=404, detail="Analyse non trouv?e")

    db.delete(analyse)
    db.commit()
    return {"message": "Analyse supprim?e avec succ?s"}

@app.delete('/historique')
def vider_tout_historique(
    db: Session = Depends(get_db),
    etudiant_connecte: dict = Depends(verifier_token_etudiant)
):
    utilisateur = db.query(Utilisateur).filter(Utilisateur.email == etudiant_connecte["email"]).first()
    if not utilisateur:
        raise HTTPException(status_code=404, detail="?tudiant non trouv?")

    db.query(HistoriqueAnalyse).filter(HistoriqueAnalyse.utilisateur_id == utilisateur.id).delete()
    db.commit()
    return {"message": "Tout l'historique a ?t? vid? avec succ?s"}

if __name__ == '__main__':
    import uvicorn
    import os
    port = int(os.environ.get('PORT', 8000))
    uvicorn.run(app, host='0.0.0.0', port=port)
