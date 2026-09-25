from database import SessionLocal, Utilisateur, creer_tables
from auth import hacher_mot_de_passe

creer_tables()

db = SessionLocal()

admin_existant = db.query(Utilisateur).filter(Utilisateur.role == "admin").first()

if not admin_existant:
    admin = Utilisateur(
        nom="Administrateur",
        email="admin@etu.uae.ac.ma",
        mot_de_passe=hacher_mot_de_passe("admin123"),
        role="admin"
    )
    db.add(admin)
    db.commit()
    print("Compte admin créé avec succès !")
else:
    print("Un compte admin existe déjà.")

db.close()