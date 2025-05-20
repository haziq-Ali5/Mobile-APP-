import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'super-secret-key')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'jwt-super-secret')
    UPLOAD_DIR = os.path.join(os.getcwd(), 'uploads')

    @staticmethod
    def init_app(app):
        os.makedirs(app.config['UPLOAD_DIR'], exist_ok=True)