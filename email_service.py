import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

load_dotenv()

# Configuration SMTP depuis le fichier .env
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")

def envoyer_email_identifiants(email_destinataire: str, nom: str, mot_de_passe_genere: str, role: str = ""):
    print(f"--- ENVOI D'EMAIL D'ACCES ---")
    print(f"Destinataire : {email_destinataire} ({nom})")
    
    if not SMTP_USER or not SMTP_PASSWORD:
        print("Erreur: Les variables d'environnement SMTP_USER et SMTP_PASSWORD ne sont pas definies.")
        return

    msg = MIMEMultipart()
    msg['From'] = SMTP_USER
    msg['To'] = email_destinataire
    msg['Subject'] = "Vos identifiants de connexion - Plateforme HistoClassAI"
    
    body = (
        f"Bonjour {nom},\n\n"
        f"Votre compte a été créé avec succès sur la plateforme HistoClassAI.\n\n"
        f"Voici vos identifiants pour vous connecter et découvrir l'application :\n"
        f"Email : {email_destinataire}\n"
        f"Mot de passe temporaire : {mot_de_passe_genere}\n\n"
        f"Lors de votre première connexion, il vous sera demandé de modifier votre mot de passe.\n\n"
        f"Cordialement,\n"
        f"L'équipe HistoClassAI"
    )
        
    msg.attach(MIMEText(body, 'plain', 'utf-8'))
    
    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        text = msg.as_string()
        server.sendmail(SMTP_USER, email_destinataire, text)
        server.quit()
        print("Email envoyé avec succès !")
    except Exception as e:
        print(f"Erreur lors de l'envoi de l'email : {e}")
