from mpi4py import MPI
import sys
import os
from enhance import enhance_image_with_realesrgan

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

def process_image(image_path):
    try:
        # Create results directory if it doesn't exist
        output_dir = image_path.replace("uploads", "results")
        os.makedirs(os.path.dirname(output_dir), exist_ok=True)
        
        # Convert to PNG for output while preserving input extension
        base_path = os.path.splitext(image_path)[0]
        output_path = f"{base_path.replace('uploads', 'results')}.png"
        
        # Verify input file exists
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Input file does not exist: {image_path}")
            
        # Process the image
        enhance_image_with_realesrgan(image_path, output_path)
        
        # Verify output was created
        if not os.path.exists(output_path):
            raise RuntimeError(f"Output file was not created: {output_path}")
            
        print(f"Rank {rank} successfully processed {image_path}")
        return True
        
    except Exception as e:
        print(f"Rank {rank} failed to process {image_path}: {str(e)}")
        return False

if __name__ == "__main__":
    if rank == 0:
        input_dir = sys.argv[1]
        input_filename = sys.argv[2]  # Get full filename with extension
        
        # Construct full input path
        image_path = os.path.join(input_dir, input_filename)
        
        # Verify the file exists before distributing work
        if not os.path.exists(image_path):
            print(f"Master rank failed: Input file does not exist: {image_path}")
            # Send termination signal to all ranks
            chunks = [None] * size
        else:
            # Create work chunks (just processing the same image in this case)
            chunks = [[image_path]] * size
    else:
        chunks = None

    # Scatter the work chunks
    my_chunk = comm.scatter(chunks, root=0)
    
    # Process if we got valid work
    if my_chunk is not None:
        for path in my_chunk:
            process_image(path)