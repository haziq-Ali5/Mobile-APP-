import os
import torch
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer
import cv2

def enhance_image_with_realesrgan(input_path, output_path):
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file does not exist: {input_path}")

    model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64,
                    num_block=23, num_grow_ch=32, scale=4)

    model_path = 'F:/BS CS/PDC/PROJECT/backend/weights/RealESRGAN_x4plus.pth'
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found at: {model_path}")

    try:
        loadnet = torch.load(model_path, map_location=torch.device('cpu'))
    except Exception as e:
        raise RuntimeError(f"Failed to load model: {e}")

    try:
        if 'params_ema' in loadnet:
            model.load_state_dict(loadnet['params_ema'], strict=True)
        elif 'params' in loadnet:
            model.load_state_dict(loadnet['params'], strict=True)
        else:
            model.load_state_dict(loadnet, strict=True)
    except Exception as e:
        raise RuntimeError(f"Failed to load model state dict: {e}")

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

    try:
        output, _ = upsampler.enhance(image, outscale=4)
    except Exception as e:
        raise RuntimeError(f"Image enhancement failed: {e}")

    try:
        cv2.imwrite(output_path, output)
    except Exception as e:
        raise RuntimeError(f"Failed to save output image: {e}")

    return output_path
