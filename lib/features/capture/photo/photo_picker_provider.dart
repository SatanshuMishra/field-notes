import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_picker_photo_picker.dart';
import 'photo_picker.dart';

final Provider<PhotoPicker> photoPickerProvider =
    Provider<PhotoPicker>((Ref ref) => ImagePickerPhotoPicker());
