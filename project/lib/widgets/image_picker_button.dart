import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerButton extends StatelessWidget {
  final void Function(File?, Uint8List) onImagePicked;
  const ImagePickerButton({super.key, required this.onImagePicked});

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final bytes = await picked.readAsBytes();

      File? file;
      if (!kIsWeb) {
        file = File(picked.path);
      }

      onImagePicked(file, bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.image),
      label: const Text('Upload Image'),
      onPressed: () => _pickImage(context),
    );
  }
}
