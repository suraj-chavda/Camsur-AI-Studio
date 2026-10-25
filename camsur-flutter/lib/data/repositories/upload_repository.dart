import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/generation_model.dart';

class UploadRepository {
  UploadRepository(this._api);

  final ApiClient _api;

  Future<UploadResult> image(File file) async {
    final name = file.path.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(file.path, filename: name),
    });
    return _api.postForm(
      ApiConstants.uploadImage,
      formData: form,
      parser: (d) => UploadResult.fromJson(d as Map<String, dynamic>),
    );
  }
}
