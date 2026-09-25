from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime

DATABASE_URL = "sqlite:///./app_tissus.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

DOMAINE_AUTORISE = "@etu.uae.ac.ma"
DOMAINE_ETUDIANT = "@etu.uae.ac.ma"

class Utilisateur(Base):
    __tablename__ = "utilisateurs"
    
    id = Column(Integer, primary_key=True, index=True)
    nom = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    mot_de_passe = Column(String, nullable=False)
    role = Column(String, nullable=False)
    date_creation = Column(DateTime, default=datetime.utcnow)
    doit_changer_mot_de_passe = Column(Boolean, default=True)

class HistoriqueAnalyse(Base):
    __tablename__ = "historique_analyses"
    
    id = Column(Integer, primary_key=True, index=True)
    utilisateur_id = Column(Integer, ForeignKey("utilisateurs.id"), nullable=True)
    classe_predite = Column(String, nullable=False)
    confiance = Column(Float, nullable=False)
    image_minio = Column(String, nullable=True)
    score_qcm = Column(Integer, nullable=True)
    total_qcm = Column(Integer, nullable=True)
    date_analyse = Column(DateTime, default=datetime.utcnow)

class InfoTissu(Base):
    __tablename__ = "info_tissus"
    
    id = Column(Integer, primary_key=True, index=True)
    nom_classe = Column(String, unique=True, nullable=False)
    description = Column(String)
    fonction = Column(String)
    localisation = Column(String)

def creer_tables():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()