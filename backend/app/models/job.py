import uuid
from datetime import datetime

class Job:
    # In-memory storage (replace with database later)
    _jobs = {}

    def __init__(self, job_id, status, created_at=None, result_url=None, error=None):
        self.job_id = job_id
        self.status = status
        self.created_at = created_at or datetime.now()
        self.result_url = result_url
        self.error = error

    @classmethod
    def create(cls, job_id, status):
        job = cls(job_id, status)
        cls._jobs[job_id] = job
        return job

    @classmethod
    def get(cls, job_id):
        return cls._jobs.get(job_id)
    @classmethod
    def update(cls, job_id, status, result_url=None, error=None):
        job = cls._jobs.get(job_id)
        if job:
            job.status = status
            job.result_url = result_url
            job.error = error