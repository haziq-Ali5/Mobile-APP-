from flask_socketio import Namespace, emit
from app import socketio
import time
import threading
from flask_socketio import disconnect
from flask import current_app
import eventlet
from datetime import datetime
import base64
from firebase_admin import credentials, initialize_app, auth
import firebase_admin
import os
import subprocess
import uuid
from flask import Blueprint, request, jsonify, send_file, url_for
jobs_bp = Blueprint('jobs', __name__)

# Add WebSocket namespace
class JobsNamespace(Namespace):
    def __init__(self, namespace):
        super().__init__(namespace)
        self.active_monitors = {}
    def on_connect(self):
        emit('connection_response', {'status': 'connected'})
    def on_status_subscribe(self, data):
        job_id = data['job_id']
        sid = request.sid
    
        def status_check():
            try:
                while self.active_monitors.get(sid, {}).get('active', False):
                    upload_path = os.path.join(current_app.config['UPLOAD_DIR'], f"{job_id}.png")
                    if os.path.exists(upload_path):
                        emit('status_update', {
                            'job_id': job_id,
                            'status': 'received',
                            'message': 'Image received and processing started'
                        })
                    for ext in ['.png', '.jpg', '.jpeg']:
                        result_path = os.path.join(current_app.config['RESULT_DIR'], f"{job_id}.png")
                        if os.path.exists(result_path):
                            emit('status_update', {
                                'job_id': job_id,
                                'status': 'completed',
                                'result_url': f"/result/{job_id}"
                            })
                            return
                    
                        eventlet.sleep(2)
                    
            except Exception as e:
                current_app.logger.error(f"Status monitor error: {e}")
                emit('status_update', {
                    'job_id': job_id,
                    'status': 'failed',
                    'error': str(e)
                })

        self.active_monitors[sid] = {'active': True}
        eventlet.spawn(status_check)
    def on_disconnect(self):
        sid = request.sid
        if sid in self.active_monitors:
            self.active_monitors[sid]['active'] = False
            del self.active_monitors[sid]

jobs_namespace = JobsNamespace('/ws/jobs')

if not firebase_admin._apps:
    cred = credentials.Certificate(r"F:\BS CS\PDC\PROJECT\backend\firebase_key.json")
    initialize_app(cred)





@jobs_bp.route('/ws/status/<job_id>')
def websocket_proxy(job_id):
    # For direct WebSocket connections (compatibility layer)
    return "Use SocketIO client instead", 200
@jobs_bp.route('/jobs', methods=['POST'])
def submit_job():
    if 'images' not in request.files:
        return jsonify({'error': 'No images uploaded'}), 400

    files = request.files.getlist('images')
    if not files:
        return jsonify({'error': 'No files found'}), 400

    responses = []
    
    for file in files:
        job_id = str(uuid.uuid4())
        try:
            # Preserve original file extension
            original_ext = os.path.splitext(file.filename)[1].lower()
            if not original_ext:  # If no extension, default to .jpg
                original_ext = '.jpg'
                
            input_filename = f"{job_id}{original_ext}"
            input_path = os.path.join(current_app.config['UPLOAD_DIR'], input_filename)
            
            # Save file
            file.save(input_path)
            
            # Verify file exists
            if not os.path.exists(input_path):
                raise Exception(f"File not saved at {input_path}")

            # Pass the full filename to MPI worker
            subprocess.Popen([
                "mpiexec", "-n", "4",
                "python", "app/tasks/mpi_worker.py", 
                current_app.config['UPLOAD_DIR'],
                input_filename  # Pass full filename with extension
            ])
            
            responses.append({
                "job_id": job_id,
                "status": "received",
                "message": "Image received successfully"
            })
            
            socketio.emit('job_received', {
                'job_id': job_id,
                'message': 'Processing started'
            }, namespace='/ws/jobs')
            
        except Exception as e:
            current_app.logger.error(f"Error processing file: {str(e)}")
            responses.append({
                "job_id": job_id,
                "status": "failed",
                "error": str(e)
            })

    return jsonify(responses), 200
@jobs_bp.route('/status/<job_id>', methods=['GET'])
def check_status(job_id):
    result_path = os.path.join(current_app.config['RESULT_DIR'], f"{job_id}.png")
    if os.path.exists(result_path):
        return jsonify({"status": "done"})
    else:
        return jsonify({"status": "processing"})

@jobs_bp.route('/result/<job_id>', methods=['GET'])
def get_result(job_id):
    for ext in ['.png', '.jpg', '.jpeg']:
        test_path = os.path.join(current_app.config['RESULT_DIR'], f"{job_id}{ext}")
        print(f"Checking for result at: {test_path}")
        if os.path.exists(test_path):
            return send_file(test_path, mimetype=f'image/{ext[1:]}')
    
    return jsonify({"error": "Result not found"}), 404

@jobs_bp.route('/result/<job_id>/all', methods=['GET'])
def get_all_results(job_id):
    results = []
    for ext in ['.png', '.jpg', '.jpeg']:
        test_path = os.path.join(current_app.config['RESULT_DIR'], f"{job_id}{ext}")
        if os.path.exists(test_path):
            with open(test_path, 'rb') as f:
                results.append(base64.b64encode(f.read()).decode('utf-8'))
    
    if not results:
        return jsonify({"error": "No results found"}), 404
    
    return jsonify(results)
@jobs_bp.before_request
def ensure_dirs_exist():
    """Ensure upload and result directories exist for each request"""
    if 'UPLOAD_DIR' not in current_app.config:
        current_app.config['UPLOAD_DIR'] = os.path.join(current_app.instance_path, 'uploads')
    if 'RESULT_DIR' not in current_app.config:
        current_app.config['RESULT_DIR'] = os.path.join(current_app.instance_path, 'results')
    
    os.makedirs(current_app.config['UPLOAD_DIR'], exist_ok=True)
    os.makedirs(current_app.config['RESULT_DIR'], exist_ok=True)