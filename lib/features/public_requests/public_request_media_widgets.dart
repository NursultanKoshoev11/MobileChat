import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../app/localization.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../shared/ui_helpers.dart';

Color _surface(BuildContext context) => Theme.of(context).cardColor;
Color _border(BuildContext context) => Theme.of(context).dividerColor;
Color _muted(BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
Color _strong(BuildContext context) => Theme.of(context).colorScheme.onSurface;

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
    final photos = content.photos.where((p) => p.base64Data.trim().isNotEmpty).take(3).toList(growable: false);
    final videos = content.videos.where((v) => v.base64Data.trim().isNotEmpty).toList(growable: false);
    if (photos.isEmpty && videos.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (photos.isNotEmpty) ...[
        Text('${text.isKy ? 'Сүрөттөр' : 'Фото'} (${photos.length}/3)', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: _muted(context))),
        const SizedBox(height: 8),
        SizedBox(
          height: compact ? 92 : 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final photo = photos[index];
              final bytes = _decodeBase64(photo.base64Data);
              if (bytes == null) return const SizedBox.shrink();
              final size = compact ? 92.0 : 116.0;
              return Stack(children: [
                GestureDetector(
                  onTap: () => openPublicRequestPhoto(context, bytes),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
                if (onRemovePhoto != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => onRemovePhoto!(photo),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ],
      if (videos.isNotEmpty) ...[
        if (photos.isNotEmpty) const SizedBox(height: 12),
        Text(text.isKy ? 'Видео' : 'Видео', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: _muted(context))),
        const SizedBox(height: 8),
        ...videos.map((video) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PublicRequestVideoTile(video: video, onRemove: onRemoveVideo == null ? null : () => onRemoveVideo!(video)),
            )),
      ],
    ]);
  }
}

void openPublicRequestPhoto(BuildContext context, Uint8List bytes) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(children: [
        InteractiveViewer(minScale: 0.7, maxScale: 4, child: Center(child: Image.memory(bytes, fit: BoxFit.contain))),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton.filledTonal(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
          ),
        ),
      ]),
    ),
  );
}

class PublicRequestVideoTile extends StatelessWidget {
  const PublicRequestVideoTile({super.key, required this.video, this.onRemove});

  final PublicRequestVideo video;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openPublicRequestVideo(context, video),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: _border(context))),
        child: Row(children: [
          Icon(Icons.play_circle_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _strong(context), fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(_sizeLabel(video.sizeBytes), style: TextStyle(color: _muted(context), fontSize: 12)),
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
    final bytes = _decodeBase64(widget.video.base64Data);
    if (bytes == null || bytes.isEmpty) throw Exception('Видео пустое');
    final dir = await getTemporaryDirectory();
    final ext = widget.video.name.toLowerCase().endsWith('.mov') ? '.mov' : '.mp4';
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
    return Stack(children: [
      Center(
        child: FutureBuilder<void>(
          future: setupFuture,
          builder: (context, snapshot) {
            final current = controller;
            if (snapshot.connectionState != ConnectionState.done) return const CircularProgressIndicator();
            if (snapshot.hasError || current == null || !current.value.isInitialized) {
              return Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.error?.toString() ?? 'Видео не открывается', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)));
            }
            return GestureDetector(
              onTap: () {
                current.value.isPlaying ? current.pause() : current.play();
                setState(() {});
              },
              child: AspectRatio(aspectRatio: current.value.aspectRatio, child: VideoPlayer(current)),
            );
          },
        ),
      ),
      SafeArea(child: Align(alignment: Alignment.topRight, child: IconButton.filledTonal(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)))),
      if (controller != null && controller!.value.isInitialized)
        SafeArea(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(16), child: VideoProgressIndicator(controller!, allowScrubbing: true)))),
    ]);
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
        setState(() => error = text.isKy ? 'Сүрөт өтө чоң. Башка сүрөт тандаңыз.' : 'Фото слишком большое. Выберите другое фото.');
        return;
      }
      setState(() {
        photos.add(PublicRequestPhoto(name: image.name.isNotEmpty ? image.name : 'photo.jpg', sizeBytes: bytes.length, base64Data: base64Encode(bytes)));
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = text.isKy ? 'Сүрөт тандалган жок: $e' : 'Не удалось выбрать фото: $e');
    }
  }

  Future<void> pickVideo() async {
    final text = AppLanguageScope.textOf(context);
    if (loading || videos.isNotEmpty) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) return;
      if (bytes.length > maxVideoBytes) {
        setState(() => error = text.isKy ? 'Видео өтө чоң. 12 MB чейин видео тандаңыз.' : 'Видео слишком большое. Выберите видео до 12 MB.');
        return;
      }
      setState(() {
        videos
          ..clear()
          ..add(PublicRequestVideo(name: file.name.isNotEmpty ? file.name : 'video.mp4', sizeBytes: bytes.length, base64Data: base64Encode(bytes)));
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = text.isKy ? 'Видео тандалган жок: $e' : 'Не удалось выбрать видео: $e');
    }
  }

  Future<void> submit() async {
    final text = AppLanguageScope.textOf(context);
    final bodyText = bodyController.text.trim();
    if (bodyText.isEmpty && photos.isEmpty && videos.isEmpty) {
      setState(() => error = text.isKy ? 'Текст, сүрөт же видео кошуңуз.' : 'Добавьте текст, фото или видео.');
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
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(text.newPost, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: titleController, decoration: InputDecoration(labelText: text.title)),
          const SizedBox(height: 12),
          TextField(controller: bodyController, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: text.description)),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: interactionMode,
            decoration: InputDecoration(labelText: text.interactionMode),
            items: [
              DropdownMenuItem(value: 'read_only', child: Text(text.textOnly)),
              DropdownMenuItem(value: 'vote_only', child: Text(text.votingOnly)),
              DropdownMenuItem(value: 'discussion', child: Text(text.discussionWithComments)),
            ],
            onChanged: loading ? null : (value) => setState(() => interactionMode = value ?? 'read_only'),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: loading || photos.length >= maxPhotos ? null : pickPhoto, icon: const Icon(Icons.photo_library_outlined), label: Text('${text.isKy ? 'Сүрөт' : 'Фото'} ${photos.length}/$maxPhotos')),
            OutlinedButton.icon(onPressed: loading || videos.isNotEmpty ? null : pickVideo, icon: const Icon(Icons.video_library_outlined), label: Text(videos.isEmpty ? (text.isKy ? 'Видео кошуу' : 'Добавить видео') : (text.isKy ? 'Видео кошулду' : 'Видео добавлено'))),
          ]),
          if (content.hasMedia) ...[
            const SizedBox(height: 12),
            PublicRequestMediaView(content: content, compact: false, onRemovePhoto: (photo) => setState(() => photos.remove(photo)), onRemoveVideo: (video) => setState(() => videos.remove(video))),
          ],
          const SizedBox(height: 8),
          Text(text.isKy ? 'Эң көп 3 сүрөт. Видео 12 MB чейин.' : 'Максимум 3 фото. Видео до 12 MB.', style: TextStyle(color: _muted(context), fontSize: 12)),
          if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
          const SizedBox(height: 16),
          FilledButton(onPressed: loading ? null : submit, child: Text(loading ? text.publishing : text.publish)),
        ]),
      ),
    );
  }
}
