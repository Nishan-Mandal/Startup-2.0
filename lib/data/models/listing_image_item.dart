import 'dart:io';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:uuid/uuid.dart';

// Listing me images ko reorder & rearrange karne ke liye unified wrapper class
class ListingImageItem {
  final String id;
  final File? localFile;
  final ImageFile? remoteImage;

  ListingImageItem.local(File file)
      : id = file.path,
        localFile = file,
        remoteImage = null;

  ListingImageItem.remote(ImageFile image)
      : id = image.fileId.isNotEmpty
            ? image.fileId
            : (image.thumbUrl.isNotEmpty ? image.thumbUrl : const Uuid().v4()),
        localFile = null,
        remoteImage = image;

  bool get isRemote => remoteImage != null;

  // Order descriptor string jo ListingDetailScreen ko pass hoti hai
  String get keyString => isRemote ? 'remote:$id' : 'local:${localFile!.path}';
}

