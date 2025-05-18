import uuid
import os
from flask import current_app

def save_file(file):
    filename = f"{uuid.uuid4()}.{file.filename.split('.')[-1]}"
    file_path = os.path.join(current_app.config['UPLOAD_FOLDER'], filename)
    file.save(file_path)
    return filename