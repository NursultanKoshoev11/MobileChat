import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../app/api_config.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../data/session_store.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

/// How long ago [time] was, in the current language.
///
/// Posts and comments show their age rather than a wall-clock time, which only
/// made sense for something published today. Anything older than a week falls
/// back to a plain date.
String koomRelativeTime(AppText text, DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.inMinutes < 1) return text.justNow;
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} ${text.minuteShort}';
  }
  if (difference.inHours < 24) return '${difference.inHours} ${text.hourShort}';
  if (difference.inDays < 7) return '${difference.inDays} ${text.dayShort}';
  final day = time.day.toString().padLeft(2, '0');
  final month = time.month.toString().padLeft(2, '0');
  return '$day.$month.${time.year}';
}

Uint8List? _decodeBase64(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final data = raw.contains(',') ? raw.split(',').last : raw;
  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

String _sizeLabel(int bytes) {
  if (bytes <= 0) return '';
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).round()} KB';
}

Future<Map<String, String>?> _imageAuthHeaders(String url) =>
    mediaAuthHeaders(url);

/// Returns an Authorization header for [url] only when the URL has exactly the
/// same origin as the configured API base. Tokens are always refreshed against
/// [baseUrl], never against an origin derived from the media URL, so a foreign
/// media link can never receive or trigger use of the user's credentials.
Future<Map<String, String>?> mediaAuthHeaders(
  String url, {
  String baseUrl = kApiBaseUrl,
  SessionStore sessionStore = const SessionStore(),
}) async {
  if (!isSameApiOrigin(url, baseUrl: baseUrl)) return null;
  await ensureFreshStoredAccessToken(
    baseUrl: baseUrl,
    sessionStore: sessionStore,
    timeout: const Duration(seconds: 15),
  );
  final session = await sessionStore.read();
  if (session == null || session.accessToken.isEmpty) return null;
  return {'Authorization': 'Bearer ${session.accessToken}'};
}

class PublicRequestMediaView extends StatelessWidget {
  const PublicRequestMediaView({
    super.key,
    required this.content,
    this.compact = true,
    this.onRemovePhoto,
    this.onRemoveVideo,
  });

  final PublicRequestContent content;
  final bool compact;
  final ValueChanged<PublicRequestPhoto>? onRemovePhoto;
  final ValueChanged<PublicRequestVideo>? onRemoveVideo;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: colors.textMuted);
    final photos = content.photos
        .where((p) =>
            p.base64Data.trim().isNotEmpty || p.url.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    final videos = content.videos
        .where((v) =>
            v.base64Data.trim().isNotEmpty ||
            v.url.trim().isNotEmpty ||
            v.fileId.trim().isNotEmpty)
        .toList(growable: false);
    if (photos.isEmpty && videos.isEmpty) return const SizedBox.shrink();
    final tileSize = compact ? 92.0 : 116.0;
    return Column(
      key: const ValueKey('public_request_media_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty) ...[
          Text('${text.photosLabel} (${photos.length}/3)', style: labelStyle),
          const SizedBox(height: KoomSpacing.sm),
          SizedBox(
            key: const ValueKey('public_request_media_photos'),
            height: tileSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: KoomSpacing.sm),
              itemBuilder: (context, index) {
                final photo = photos[index];
                final remoteUrl = photo.url.trim();
                final bytes =
                    remoteUrl.isEmpty ? _decodeBase64(photo.base64Data) : null;
                if (remoteUrl.isEmpty && bytes == null) {
                  return const SizedBox.shrink();
                }
                return Stack(children: [
                  GestureDetector(
                    onTap: () {
                      if (remoteUrl.isNotEmpty) {
                        openPublicRequestRemotePhoto(context, remoteUrl);
                      } else if (bytes != null) {
                        openPublicRequestPhoto(context, bytes);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: KoomRadii.smAll,
                      child: remoteUrl.isNotEmpty
                          ? _AuthenticatedNetworkImage(
                              url: remoteUrl,
                              width: tileSize,
                              height: tileSize,
                            )
                          : Image.memory(
                              bytes!,
                              width: tileSize,
                              height: tileSize,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                  ),
                  if (onRemovePhoto != null)
                    Positioned(
                      top: KoomSpacing.xs,
                      right: KoomSpacing.xs,
                      child: InkWell(
                        onTap: () => onRemovePhoto!(photo),
                        child: Container(
                          padding: const EdgeInsets.all(KoomSpacing.xs),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ),
        ],
        if (videos.isNotEmpty) ...[
          if (photos.isNotEmpty) const SizedBox(height: KoomSpacing.md),
          Text(text.videosLabel, style: labelStyle),
          const SizedBox(height: KoomSpacing.sm),
          ...videos.map((video) => Padding(
                padding: const EdgeInsets.only(bottom: KoomSpacing.sm),
                child: PublicRequestVideoTile(
                  video: video,
                  onRemove: onRemoveVideo == null
                      ? null
                      : () => onRemoveVideo!(video),
                ),
              )),
        ],
      ],
    );
  }
}

class _AuthenticatedNetworkImage extends StatelessWidget {
  const _AuthenticatedNetworkImage({required this.url, required this.width, required this.height});

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>?>(
      future: _imageAuthHeaders(url),
      builder: (context, snapshot) {
        final headers = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            headers == null) {
          // Placeholder in the shape of the thumbnail it replaces.
          return KoomSkeleton(
            width: width,
            height: height,
            radius: KoomRadii.sm,
          );
        }
        return Image.network(
          url,
          headers: headers,
          width: width,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : KoomSkeleton(
                  width: width,
                  height: height,
                  radius: KoomRadii.sm,
                ),
          // The file may be gone (e.g. removed with a deleted account):
          // show a neutral placeholder instead of an error.
          errorBuilder: (_, __, ___) =>
              MediaUnavailablePlaceholder(width: width, height: height),
        );
      },
    );
  }
}

/// True for the server's 429 `upload_quota_exceeded` response.
bool isUploadQuotaError(Object error) =>
    error is ApiException &&
    (error.statusCode == 429 ||
        error.message.contains('upload_quota_exceeded') ||
        error.message.contains('upload quota exceeded'));

/// Neutral placeholder for media that can no longer be loaded (404 after the
/// owner's account and files were deleted, network errors, corrupt data).
class MediaUnavailablePlaceholder extends StatelessWidget {
  const MediaUnavailablePlaceholder({
    super.key,
    this.width,
    this.height,
    this.showLabel = false,
    this.dark = false,
  });

  final double? width;
  final double? height;
  final bool showLabel;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final scheme = Theme.of(context).colorScheme;
    final foreground = dark ? Colors.white70 : scheme.onSurfaceVariant;
    final label = text.mediaUnavailable;
    return Semantics(
      label: label,
      child: Container(
        width: width,
        height: height,
        color: dark ? Colors.transparent : scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, color: foreground),
            if (showLabel) ...[
              const SizedBox(height: KoomSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen placeholder while a photo or video is fetched: roughly the shape
/// of the media it stands in for, instead of a lone spinner. Dimmed because the
/// viewer behind it is black.
class _FullScreenMediaSkeleton extends StatelessWidget {
  const _FullScreenMediaSkeleton({this.aspectRatio = 3 / 4});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KoomSpacing.xl),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: const Opacity(
            opacity: 0.3,
            child: KoomSkeleton(
              width: double.infinity,
              height: double.infinity,
              radius: KoomRadii.md,
            ),
          ),
        ),
      ),
    );
  }
}

void openPublicRequestPhoto(BuildContext context, Uint8List bytes) {
  _showPublicRequestPhotoViewer(context, bytes: bytes);
}

void openPublicRequestRemotePhoto(BuildContext context, String url) {
  _showPublicRequestPhotoViewer(context, url: url);
}

void _showPublicRequestPhotoViewer(
  BuildContext context, {
  Uint8List? bytes,
  String? url,
}) {
  showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: _PublicRequestPhotoViewer(bytes: bytes, url: url),
    ),
  );
}

class _PublicRequestPhotoViewer extends StatelessWidget {
  const _PublicRequestPhotoViewer({this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  Widget _fullImage(
    BuildContext context,
    BoxConstraints constraints,
    Map<String, String>? headers,
  ) {
    final image = bytes != null
        ? Image.memory(
            bytes!,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          )
        : Image.network(
            url!,
            headers: headers,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const _FullScreenMediaSkeleton(),
            errorBuilder: (_, __, ___) => const MediaUnavailablePlaceholder(
              showLabel: true,
              dark: true,
            ),
          );

    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      panEnabled: true,
      scaleEnabled: true,
      clipBehavior: Clip.none,
      child: SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: image,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remoteUrl = (url ?? '').trim();
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (bytes != null) {
                    return _fullImage(context, constraints, null);
                  }
                  if (remoteUrl.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return FutureBuilder<Map<String, String>?>(
                    future: _imageAuthHeaders(remoteUrl),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          snapshot.data == null) {
                        return const _FullScreenMediaSkeleton();
                      }
                      return _fullImage(
                        context,
                        constraints,
                        snapshot.data,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PublicRequestVideoTile extends StatelessWidget {
  const PublicRequestVideoTile({super.key, required this.video, this.onRemove});

  final PublicRequestVideo video;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: KoomRadii.mdAll,
      onTap: () => openPublicRequestVideo(context, video),
      child: Container(
        padding: const EdgeInsets.all(KoomSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: KoomRadii.mdAll,
          border: Border.all(color: colors.border),
        ),
        child: Row(children: [
          Icon(
            Icons.play_circle_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
          const SizedBox(width: KoomSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                video.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
              Text(_sizeLabel(video.sizeBytes), style: textTheme.bodySmall),
            ]),
          ),
          if (onRemove != null) IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded)),
        ]),
      ),
    );
  }
}

void openPublicRequestVideo(BuildContext context, PublicRequestVideo video) {
  showDialog<void>(context: context, builder: (_) => Dialog.fullscreen(backgroundColor: Colors.black, child: _VideoViewer(video: video)));
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.video});
  final PublicRequestVideo video;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  VideoPlayerController? controller;
  late final Future<void> setupFuture;

  @override
  void initState() {
    super.initState();
    setupFuture = setup();
  }

  Future<void> setup() async {
    Uint8List? bytes = _decodeBase64(widget.video.base64Data);
    if ((bytes == null || bytes.isEmpty) && widget.video.url.trim().isNotEmpty) {
      final uri = Uri.tryParse(widget.video.url.trim());
      if (uri == null || !uri.hasScheme) throw Exception('Ссылка на видео недействительна');
      final headers = await _imageAuthHeaders(widget.video.url) ?? const <String, String>{};
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) throw Exception('Не удалось загрузить видео (${response.statusCode})');
      bytes = response.bodyBytes;
    }
    if (bytes == null || bytes.isEmpty) throw Exception('Видео пустое');
    final dir = await getTemporaryDirectory();
    final lowerName = widget.video.name.toLowerCase();
    final ext = lowerName.endsWith('.mov') ? '.mov' : lowerName.endsWith('.webm') ? '.webm' : '.mp4';
    final file = File('${dir.path}/post_video_${DateTime.now().microsecondsSinceEpoch}$ext');
    await file.writeAsBytes(bytes, flush: true);
    final next = VideoPlayerController.file(file);
    controller = next;
    await next.initialize();
    await next.setLooping(true);
    await next.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SafeArea(
              child: FutureBuilder<void>(
                future: setupFuture,
                builder: (context, snapshot) {
                  final current = controller;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _FullScreenMediaSkeleton(
                      aspectRatio: 16 / 9,
                    );
                  }
                  if (snapshot.hasError ||
                      current == null ||
                      !current.value.isInitialized) {
                    // Missing (404) or broken video: neutral placeholder.
                    return const MediaUnavailablePlaceholder(
                      showLabel: true,
                      dark: true,
                    );
                  }
                  final videoSize = current.value.size;
                  final videoWidth = videoSize.width > 0 ? videoSize.width : 16.0;
                  final videoHeight =
                      videoSize.height > 0 ? videoSize.height : 9.0;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      current.value.isPlaying
                          ? current.pause()
                          : current.play();
                      setState(() {});
                    },
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: videoWidth,
                          height: videoHeight,
                          child: VideoPlayer(current),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          if (controller != null && controller!.value.isInitialized)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: VideoProgressIndicator(
                    controller!,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CreatePublicRequestMediaSheet extends StatefulWidget {
  const CreatePublicRequestMediaSheet({super.key, required this.api, required this.groupId});
  final PublicRequestsApi api;
  final String groupId;

  @override
  State<CreatePublicRequestMediaSheet> createState() => _CreatePublicRequestMediaSheetState();
}

class _CreatePublicRequestMediaSheetState extends State<CreatePublicRequestMediaSheet> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final imagePicker = ImagePicker();
  final List<PublicRequestPhoto> photos = [];
  final List<PublicRequestVideo> videos = [];
  String type = 'announcement';
  String interactionMode = 'read_only';
  bool loading = false;
  String? error;

  static const maxPhotos = 3;
  static const maxPhotoBytes = 900 * 1024;
  static const maxVideoBytes = 12 * 1024 * 1024;

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<Uint8List> _compressedPhotoBytesWithoutExif(XFile image) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/public_request_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      image.path,
      targetPath,
      minWidth: 1280,
      minHeight: 720,
      quality: 72,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) return image.readAsBytes();
    return File(compressed.path).readAsBytes();
  }

  Future<void> pickPhoto() async {
    final text = AppLanguageScope.textOf(context);
    if (loading || photos.length >= maxPhotos) return;
    try {
      final image = await imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 72);
      if (image == null) return;
      final bytes = await _compressedPhotoBytesWithoutExif(image);
      if (bytes.length > maxPhotoBytes) {
        setState(() => error = text.photoTooLarge);
        return;
      }
      final fileName = image.name.isNotEmpty ? image.name : 'photo.jpg';
      final uploaded = await widget.api.uploadPublicRequestFile(groupId: widget.groupId, kind: 'photo', fileName: fileName, bytes: bytes);
      setState(() {
        photos.add(PublicRequestPhoto(
          name: uploaded['file_name'] as String? ?? fileName,
          sizeBytes: uploaded['size_bytes'] as int? ?? bytes.length,
          fileId: uploaded['id'] as String? ?? '',
          url: uploaded['url'] as String? ?? '',
        ));
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = isUploadQuotaError(e) ? text.uploadQuotaExceeded : (text.isKy ? 'Сүрөт тандалган жок: $e' : 'Не удалось выбрать фото: $e'));
    }
  }

  Future<void> pickVideo() async {
    final text = AppLanguageScope.textOf(context);
    if (loading || videos.isNotEmpty) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'mov'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) return;
      if (bytes.length > maxVideoBytes) {
        setState(() => error = text.videoTooLarge);
        return;
      }
      final fileName = file.name.isNotEmpty ? file.name : 'video.mp4';
      final uploaded = await widget.api.uploadPublicRequestFile(groupId: widget.groupId, kind: 'video', fileName: fileName, bytes: bytes);
      if (!mounted) return;
      final lowerName = fileName.toLowerCase();
      final mimeType = lowerName.endsWith('.mov') ? 'video/quicktime' : 'video/mp4';
      setState(() {
        videos
          ..clear()
          ..add(PublicRequestVideo(name: uploaded['file_name'] as String? ?? fileName, sizeBytes: uploaded['size_bytes'] as int? ?? bytes.length, fileId: uploaded['id'] as String? ?? '', url: uploaded['url'] as String? ?? '', mimeType: mimeType));
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = isUploadQuotaError(e) ? text.uploadQuotaExceeded : (text.isKy ? 'Видео тандалган жок: $e' : 'Не удалось выбрать видео: $e'));
    }
  }

  Future<void> submit() async {
    final text = AppLanguageScope.textOf(context);
    final bodyText = bodyController.text.trim();
    if (bodyText.isEmpty && photos.isEmpty && videos.isEmpty) {
      setState(() => error = text.addTextOrMedia);
      return;
    }
    final payload = PublicRequestContent(text: bodyText, photos: List.of(photos), videos: List.of(videos)).toPayload();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final request = await widget.api.createRequest(groupId: widget.groupId, type: type, interactionMode: interactionMode, title: titleController.text.trim(), body: payload);
      if (mounted) Navigator.of(context).pop(request);
    } on ModerationPendingException catch (e) {
      if (mounted) {
        showAppSnack(context, e.message);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final content = PublicRequestContent(text: bodyController.text, photos: photos, videos: videos);
    return Padding(
      padding: EdgeInsets.only(left: KoomSpacing.xl, right: KoomSpacing.xl, bottom: MediaQuery.of(context).viewInsets.bottom + KoomSpacing.xl),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(text.newPost, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: KoomSpacing.lg),
          TextField(key: const ValueKey('post_title_field'), controller: titleController, decoration: InputDecoration(labelText: text.title)),
          const SizedBox(height: KoomSpacing.md),
          TextField(key: const ValueKey('post_body_field'), controller: bodyController, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: text.description)),
          const SizedBox(height: KoomSpacing.md),
          DropdownButtonFormField<String>(
            value: type,
            decoration: InputDecoration(labelText: text.postType),
            items: [
              DropdownMenuItem(value: 'announcement', child: Text(text.announcement)),
              DropdownMenuItem(value: 'suggestion', child: Text(text.suggestion)),
              DropdownMenuItem(value: 'complaint', child: Text(text.complaint)),
              DropdownMenuItem(value: 'requirement', child: Text(text.requirement)),
              DropdownMenuItem(value: 'problem', child: Text(text.problem)),
              DropdownMenuItem(value: 'idea', child: Text(text.idea)),
            ],
            onChanged: loading ? null : (value) => setState(() => type = value ?? 'announcement'),
          ),
          const SizedBox(height: KoomSpacing.md),
          DropdownButtonFormField<String>(
            key: const ValueKey('post_mode_dropdown'),
            value: interactionMode,
            decoration: InputDecoration(labelText: text.interactionMode),
            items: [
              DropdownMenuItem(value: 'read_only', child: Text(text.textOnly)),
              DropdownMenuItem(value: 'vote_only', child: Text(text.votingOnly)),
              DropdownMenuItem(value: 'discussion', child: Text(text.discussionWithComments, key: const ValueKey('post_mode_discussion'))),
            ],
            onChanged: loading ? null : (value) => setState(() => interactionMode = value ?? 'read_only'),
          ),
          const SizedBox(height: KoomSpacing.md),
          Wrap(spacing: KoomSpacing.sm, runSpacing: KoomSpacing.sm, children: [
            OutlinedButton.icon(onPressed: loading || photos.length >= maxPhotos ? null : pickPhoto, icon: const Icon(Icons.photo_library_outlined), label: Text('${text.photoLabel} ${photos.length}/$maxPhotos')),
            OutlinedButton.icon(onPressed: loading || videos.isNotEmpty ? null : pickVideo, icon: const Icon(Icons.video_library_outlined), label: Text(videos.isEmpty ? text.addVideo : text.videoAdded)),
          ]),
          if (content.hasMedia) ...[
            const SizedBox(height: KoomSpacing.md),
            PublicRequestMediaView(content: content, compact: false, onRemovePhoto: (photo) => setState(() => photos.remove(photo)), onRemoveVideo: (video) => setState(() => videos.remove(video))),
          ],
          const SizedBox(height: KoomSpacing.sm),
          Text(text.mediaLimitsHint, style: Theme.of(context).textTheme.bodySmall),
          if (error != null) ...[const SizedBox(height: KoomSpacing.md), ErrorBanner(message: error!)],
          const SizedBox(height: KoomSpacing.lg),
          FilledButton(key: const ValueKey('post_submit_button'), onPressed: loading ? null : submit, child: Text(loading ? text.publishing : text.publish)),
        ]),
      ),
    );
  }
}
