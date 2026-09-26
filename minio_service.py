import os
import io
import uuid
import hmac
import hashlib
from datetime import datetime, timezone
import requests
from dotenv import load_dotenv

load_dotenv()

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "tissus-images")
MINIO_SECURE = os.getenv("MINIO_SECURE", "False").lower() in ("true", "1", "yes")

def _get_scheme():
    return "https" if MINIO_SECURE else "http"

def _sign(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

def _get_signature_key(key: str, date_stamp: str, region_name: str, service_name: str) -> bytes:
    k_date = _sign(('AWS4' + key).encode('utf-8'), date_stamp)
    k_region = _sign(k_date, region_name)
    k_service = _sign(k_region, service_name)
    k_signing = _sign(k_service, 'aws4_request')
    return k_signing

def _build_auth_headers(method: str, path: str, payload_bytes: bytes = b"", content_type: str = "") -> dict:
    now = datetime.now(timezone.utc)
    amz_date = now.strftime('%Y%m%dT%H%M%SZ')
    date_stamp = now.strftime('%Y%m%d')
    region = "us-east-1"
    service = "s3"
    
    host = MINIO_ENDPOINT.split("/")[0]
    payload_hash = hashlib.sha256(payload_bytes).hexdigest()
    
    headers_dict = {
        'host': host,
        'x-amz-date': amz_date,
        'x-amz-content-sha256': payload_hash,
    }
    if content_type:
        headers_dict['content-type'] = content_type

    signed_headers_list = sorted(headers_dict.keys())
    signed_headers = ';'.join(signed_headers_list)
    
    canonical_headers = "".join([f"{k}:{headers_dict[k]}\n" for k in signed_headers_list])
    canonical_request = f"{method}\n{path}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    
    algorithm = 'AWS4-HMAC-SHA256'
    credential_scope = f"{date_stamp}/{region}/{service}/aws4_request"
    string_to_sign = f"{algorithm}\n{amz_date}\n{credential_scope}\n{hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()}"
    
    signing_key = _get_signature_key(MINIO_SECRET_KEY, date_stamp, region, service)
    signature = hmac.new(signing_key, string_to_sign.encode('utf-8'), hashlib.sha256).hexdigest()
    
    authorization_header = f"{algorithm} Credential={MINIO_ACCESS_KEY}/{credential_scope}, SignedHeaders={signed_headers}, Signature={signature}"
    
    req_headers = {
        'x-amz-date': amz_date,
        'x-amz-content-sha256': payload_hash,
        'Authorization': authorization_header
    }
    if content_type:
        req_headers['Content-Type'] = content_type
    return req_headers

def initialiser_bucket() -> bool:
    # Ignorer si MINIO_ENDPOINT n'est pas accessible ou par d?faut en cloud
    if 'localhost' in MINIO_ENDPOINT and os.getenv('DATABASE_URL'):
        return False
    try:
        url = f"{_get_scheme()}://{MINIO_ENDPOINT}/{MINIO_BUCKET}"
        # 1. Vérifier si le bucket existe (HEAD)
        head_headers = _build_auth_headers("HEAD", f"/{MINIO_BUCKET}")
        r = requests.head(url, headers=head_headers, timeout=2)
        if r.status_code == 200:
            return True
        elif r.status_code == 404:
            # 2. Créer le bucket (PUT)
            put_headers = _build_auth_headers("PUT", f"/{MINIO_BUCKET}")
            r_put = requests.put(url, headers=put_headers, timeout=3)
            if r_put.status_code in (200, 204):
                print(f"[MinIO] Bucket '{MINIO_BUCKET}' initialisé.")
                return True
        return True
    except Exception as e:
        print(f"[MinIO Info] MinIO n'est pas encore démarré ({e}). Le stockage s'activera dès son lancement.")
        return False

def uploader_image_tissu(image_bytes: bytes, nom_classe: str = "INCONNU", extension: str = "jpg") -> str | None:
    if 'localhost' in MINIO_ENDPOINT and os.getenv('DATABASE_URL'):
        return None
    try:
        horodatage = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        identifiant = uuid.uuid4().hex[:8]
        nom_objet = f"{horodatage}_{nom_classe}_{identifiant}.{extension}"
        
        path = f"/{MINIO_BUCKET}/{nom_objet}"
        url = f"{_get_scheme()}://{MINIO_ENDPOINT}{path}"
        content_type = "image/jpeg" if extension in ("jpg", "jpeg") else f"image/{extension}"
        
        headers = _build_auth_headers("PUT", path, payload_bytes=image_bytes, content_type=content_type)
        r = requests.put(url, data=image_bytes, headers=headers, timeout=3)
        
        if r.status_code in (200, 204):
            print(f"[MinIO] Image '{nom_objet}' sauvegardée avec succès.")
            return nom_objet
        else:
            print(f"[MinIO] Échec upload (Code {r.status_code})")
            return None
    except Exception as e:
        print(f"[MinIO Info] Impossible d'uploader sur MinIO : {e}")
        return None
