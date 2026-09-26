// Configuration de l'URL du Backend API
// En production, pointe directement vers FastAPI Cloud
export const API_URL = import.meta.env.VITE_API_URL || 'https://api-tissus.fastapicloud.dev';
