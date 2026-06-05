import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';

String normalizeProfilePhotoUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) {
    return '';
  }
  if (value.startsWith('gs://')) {
    return value;
  }
  if (value.startsWith('//')) {
    return 'https:$value';
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return '';
}

class ProfilePhotoAvatar extends StatefulWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.photoUrl,
    this.fallbackInitial = '?',
    this.radius = 18,
    this.previewWidth,
    this.previewHeight,
  });

  final String photoUrl;
  final String fallbackInitial;
  final double radius;
  final double? previewWidth;
  final double? previewHeight;

  bool get isPreview => previewWidth != null && previewHeight != null;

  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};

  static bool _isFirebaseStorageUrl(String url) {
    return url.startsWith('gs://') ||
        url.contains('firebasestorage.googleapis.com');
  }

  @override
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar> {
  Uint8List? _photoBytes;
  bool _loading = true;
  bool _useCachedNetworkImage = false;
  bool _useNetworkImage = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _photoBytes = null;
      _loading = true;
      _useCachedNetworkImage = false;
      _useNetworkImage = false;
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    final String url = widget.photoUrl;

    if (url.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final cached = ProfilePhotoAvatar._memoryCache[url];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _photoBytes = cached;
          _loading = false;
        });
      }
      return;
    }

    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _loading = false;
          _useNetworkImage = true;
        });
      }
      return;
    }

    if (ProfilePhotoAvatar._isFirebaseStorageUrl(url)) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final data = await ref.getData(3 * 1024 * 1024);
        if (!mounted) {
          return;
        }
        if (data != null && data.isNotEmpty) {
          ProfilePhotoAvatar._memoryCache[url] = data;
          setState(() {
            _photoBytes = data;
            _loading = false;
          });
          return;
        }
      } catch (_) {
        // Fall through to CachedNetworkImage.
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _useCachedNetworkImage = true;
    });
  }

  Widget _buildInitialAvatar() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        widget.fallbackInitial,
        style: TextStyle(
          color: ColorConst.primaryBlue,
          fontWeight: FontWeight.w700,
          fontSize: widget.radius * 0.65,
        ),
      ),
    );
  }

  Widget _previewFrame({required Widget child}) {
    return Container(
      width: widget.previewWidth,
      height: widget.previewHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorConst.borderSoft),
        color: const Color(0xFFF7F9FF),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildErrorPreview() {
    return _previewFrame(
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: ColorConst.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator({double? size}) {
    return SizedBox(
      width: size,
      height: size,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildMemoryImage() {
    if (widget.isPreview) {
      return _previewFrame(
        child: Image.memory(
          _photoBytes!,
          fit: BoxFit.cover,
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFEAF0FF),
      backgroundImage: MemoryImage(_photoBytes!),
    );
  }

  Widget _buildNetworkImage() {
    Widget buildImage({double? width, double? height}) {
      return Image.network(
        widget.photoUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _buildLoadingIndicator(size: width ?? height);
        },
        errorBuilder: (context, error, stackTrace) {
          if (widget.isPreview) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: ColorConst.textSecondary,
              ),
            );
          }
          return _buildInitialAvatar();
        },
      );
    }

    if (widget.isPreview) {
      return _previewFrame(child: buildImage());
    }

    final double size = widget.radius * 2;
    return ClipOval(
      child: buildImage(width: size, height: size),
    );
  }

  Widget _buildCachedNetworkImage() {
    if (widget.isPreview) {
      return _previewFrame(
        child: CachedNetworkImage(
          imageUrl: widget.photoUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildLoadingIndicator(),
          errorWidget: (context, url, error) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: ColorConst.textSecondary,
              ),
            );
          },
        ),
      );
    }

    final double size = widget.radius * 2;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFEAF0FF),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildLoadingIndicator(size: size),
          errorWidget: (context, url, error) => _buildInitialAvatar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrl.isEmpty) {
      return widget.isPreview ? _buildErrorPreview() : _buildInitialAvatar();
    }

    if (_photoBytes != null) {
      return _buildMemoryImage();
    }

    if (_loading) {
      return widget.isPreview
          ? _previewFrame(child: _buildLoadingIndicator())
          : _buildLoadingIndicator(size: widget.radius * 2);
    }

    if (_useNetworkImage) {
      return _buildNetworkImage();
    }

    if (_useCachedNetworkImage) {
      return _buildCachedNetworkImage();
    }

    return widget.isPreview ? _buildErrorPreview() : _buildInitialAvatar();
  }
}
