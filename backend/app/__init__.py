from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_socketio import SocketIO
from .config import Config
import os

# Initialize extensions
socketio = SocketIO(
    cors_allowed_origins="*",
    async_mode='gevent',  
    logger=True,
    engineio_logger=False
)
jwt = JWTManager()

def create_app():
    app = Flask(__name__, static_folder='static')
    
    # Load configuration
    app.config.from_object(Config)
    Config.init_app(app)
    
    # Configure upload directories
    app.config['UPLOAD_DIR'] = os.path.join(app.instance_path, 'uploads')
    app.config['RESULT_DIR'] = os.path.join(app.instance_path, 'results')
    print(f"Upload directory: {app.config['UPLOAD_DIR']}")
    print(f"Result directory: {app.config['RESULT_DIR']}")
    
    # Create directories if they don't exist
    os.makedirs(app.config['UPLOAD_DIR'], exist_ok=True)
    os.makedirs(app.config['RESULT_DIR'], exist_ok=True)

    # Configure CORS
    CORS(app, resources={r"/*": {"origins": "*"}})
    
    # Initialize extensions with app
    jwt.init_app(app)
    socketio.init_app(app)

    # Register blueprints
    from .routes.auth import auth_bp
    from .routes.jobs import jobs_bp
    app.register_blueprint(auth_bp)
    app.register_blueprint(jobs_bp)

    # Register SocketIO namespace - FIXED THIS LINE
    from .routes.jobs import jobs_namespace
    socketio.on_namespace   (jobs_namespace)
    # Register error handlers
    return app