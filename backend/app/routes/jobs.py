from firebase_admin import credentials, initialize_app, auth
import firebase_admin
import os
import subprocess
import uuid
from flask import Blueprint, request, jsonify, send_file, url_for

if not firebase_admin._apps:
    cred = credentials.Certificate(r"F:\BS CS\PDC\PROJECT\backend\firebase_key.json")
    initialize_app(cred)

jobs_bp = Blueprint('jobs', __name__)

UPLOAD_DIR = 'uploads'
RESULT_DIR = 'results'
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(RESULT_DIR, exist_ok=True)

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
        input_path = os.path.join(UPLOAD_DIR, f"{job_id}.png")
        file.save(input_path)

        subprocess.Popen([
            "mpiexec", "-n", "4",
            "python", "app/tasks/mpi_worker.py", UPLOAD_DIR, job_id
        ])

        responses.append({
            "job_id": job_id,
            "status": "processing",
            "result_url": url_for('jobs.get_result', job_id=job_id, _external=True)
        })

    return jsonify(responses), 200

@jobs_bp.route('/status/<job_id>', methods=['GET'])
def check_status(job_id):
    result_path = os.path.join(RESULT_DIR, f"{job_id}.png")
    if os.path.exists(result_path):
        return jsonify({"status": "done"})
    else:
        return jsonify({"status": "processing"})

@jobs_bp.route('/result/<job_id>', methods=['GET'])
def get_result(job_id):
    result_path = os.path.join(RESULT_DIR, f"{job_id}.png")
    if os.path.exists(result_path):
        return send_file(result_path, mimetype='image/png')
    else:
        return jsonify({"error": "Result not ready"}), 404
