# 1. Image de base Python 3.11 légère (requis par keras >= 3.13)
FROM python:3.11-slim

# 2. Variables d'environnement pour optimiser l'exécution de Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8000

# 3. Répertoire de travail dans le conteneur
WORKDIR /app

# 4. Installation des paquets système nécessaires pour TensorFlow et le traitement d'images
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 5. Copie et installation des dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 6. Copie de l'ensemble du code backend et du modèle de classification IA
COPY . .

# 7. Exposition du port de l'API
EXPOSE 8000

# 8. Commande de démarrage avec uvicorn (adaptée pour le cloud grâce à la variable $PORT)
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
