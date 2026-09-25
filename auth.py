from passlib.context import CryptContext
from jose import jwt , JWTError
from datetime import datetime, timedelta
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = "cle_secrete"
ALGORITHM = "HS256"
EXPIRATION_TOKEN_MINUTES = 60 * 24  # le token reste valide 24h

def hacher_mot_de_passe(mot_de_passe: str) -> str:
    return pwd_context.hash(mot_de_passe)

def verifier_mot_de_passe(mot_de_passe: str, mot_de_passe_hache: str) -> bool:
    return pwd_context.verify(mot_de_passe, mot_de_passe_hache)

def creer_token(email: str, role: str) -> str:
    expiration = datetime.utcnow() + timedelta(minutes=EXPIRATION_TOKEN_MINUTES)
    data = {"sub": email, "role": role, "exp": expiration}
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def verifier_token_prof(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        role = payload.get("role")
        
        if role != "prof":
            raise HTTPException(status_code=403, detail="Seul un professeur peut effectuer cette action")
        
        return {"email": email, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")

def verifier_token_admin(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        role = payload.get("role")
        
        if role != "admin":
            raise HTTPException(status_code=403, detail="Seul un administrateur peut effectuer cette action")
        
        return {"email": email, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")

def verifier_token_authentifie(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        role = payload.get("role")
        if not email:
            raise HTTPException(status_code=401, detail="Token invalide")
        return {"email": email, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")

def verifier_token_etudiant(credentials: HTTPAuthorizationCredentials = Depends(security)):
    user = verifier_token_authentifie(credentials)
    if user["role"] != "etudiant":
        raise HTTPException(status_code=403, detail="Seul un étudiant peut effectuer cette action")
    return user