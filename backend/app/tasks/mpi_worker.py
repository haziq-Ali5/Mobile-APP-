from mpi4py import MPI
import sys
import os
from enhance import enhance_image_with_realesrgan

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

def process_image(image_path):
    try:
        output_path = image_path.replace("uploads", "results")
        enhance_image_with_realesrgan(image_path, output_path)
        print(f"Rank {rank} processed {image_path}")
    except Exception as e:
        print(f"Rank {rank} failed to process {image_path}: {e}")

if rank == 0:
    input_dir = sys.argv[1]
    job_id = sys.argv[2]
    image_path = os.path.join(input_dir, f"{job_id}.png")
    paths = [image_path] * size
    chunks = [paths[i::size] for i in range(size)]
else:
    chunks = None

my_chunk = comm.scatter(chunks, root=0)
for path in my_chunk:
    process_image(path)
