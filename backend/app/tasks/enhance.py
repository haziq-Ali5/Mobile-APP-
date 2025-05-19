import os
import torch
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer
import cv2

def enhance_image_with_realesrgan(input_path, output_path):
    try:
        if not os.path.exists(input_path):
            raise FileNotFoundError(f"Input file does not exist: {input_path}")

        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64,
                        num_block=23, num_grow_ch=32, scale=4)

        model_path = 'F:/BS CS/PDC/PROJECT/backend/weights/RealESRGAN_x4plus.pth'
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found at: {model_path}")

        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        loadnet = torch.load(model_path, map_location=torch.device('cpu'))
    
        if 'params_ema' in loadnet:
            model.load_state_dict(loadnet['params_ema'], strict=True)
        elif 'params' in loadnet:
            model.load_state_dict(loadnet['params'], strict=True)
        else:
            model.load_state_dict(loadnet, strict=True)
    
        model.to(device)
        upsampler = RealESRGANer(
            scale=4,
            model_path=model_path,
            model=model,
            tile=400,
            tile_pad=10,
            pre_pad=0,
            half=False
        )

        print(f"Processing image: {input_path}")
        image = cv2.imread(input_path, cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError(f"cv2.imread() returned None for: {input_path}")

        output, _ = upsampler.enhance(image, outscale=4)
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        success = cv2.imwrite(output_path, output)
        if not success:
            raise RuntimeError(f"Failed to write output image: {output_path}")
        return output_path
    except Exception as e:
            # Clean up if error occurs
            if os.path.exists(input_path):
                os.remove(input_path)
            raise    