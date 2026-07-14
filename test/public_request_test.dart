import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/data/public_request.dart';

void main() {
  PublicRequest sampleRequest({String? body, String? myVote}) {
    return PublicRequest.fromJson({
      'id': 'REQ-BASE',
      'group_id': 'G-1',
      'author_id': 'U-1',
      'author_name': 'Nursultan',
      'request_type': 'idea',
      'interaction_mode': 'discussion',
      'title': 'Idea',
      'body': body ?? 'Body text.',
      'status': 'new',
      'support_count': 1,
      'oppose_count': 0,
      'comment_count': 2,
      'my_vote': myVote,
      'created_at': '2026-05-14T00:00:00Z',
      'updated_at': '2026-05-14T00:00:00Z',
    });
  }

  test('PublicRequest parses JSON with interaction mode', () {
    final request = PublicRequest.fromJson({
      'id': 'REQ-1',
      'group_id': 'G-1',
      'author_id': 'U-1',
      'author_name': 'Nursultan',
      'request_type': 'complaint',
      'interaction_mode': 'discussion',
      'title': 'Road problem',
      'body': 'Please fix this issue.',
      'status': 'new',
      'support_count': 10,
      'oppose_count': 2,
      'comment_count': 3,
      'my_vote': 'support',
      'created_at': '2026-05-14T00:00:00Z',
      'updated_at': '2026-05-14T00:00:00Z',
    });

    expect(request.id, 'REQ-1');
    expect(request.requestType, 'complaint');
    expect(request.interactionMode, 'discussion');
    expect(request.supportedByMe, isTrue);
    expect(request.opposedByMe, isFalse);
  });

  test('PublicRequestVoteUpdate supports exact and legacy payloads', () {
    final exact = PublicRequestVoteUpdate.fromJson({
      'request_id': 'REQ-1',
      'support_count': 8,
      'oppose_count': 2,
      'voter_id': 'U-1',
      'vote_type': 'support',
    });
    final legacy = PublicRequestVoteUpdate.fromJson({
      'request_id': 'REQ-1',
      'vote_type': 'support',
    });

    expect(exact.hasCounts, isTrue);
    expect(exact.supportCount, 8);
    expect(exact.opposeCount, 2);
    expect(exact.voterId, 'U-1');
    expect(exact.voteType, 'support');
    expect(legacy.hasCounts, isFalse);
  });

  test('PublicRequest defaults to discussion for old payloads', () {
    final request = PublicRequest.fromJson({
      'id': 'REQ-2',
      'group_id': 'G-1',
      'author_id': 'U-1',
      'author_name': 'Nursultan',
      'request_type': 'idea',
      'title': 'Idea',
      'body': 'Body text.',
      'status': 'new',
      'created_at': '2026-05-14T00:00:00Z',
      'updated_at': '2026-05-14T00:00:00Z',
    });

    expect(request.interactionMode, 'discussion');
    expect(request.supportCount, 0);
    expect(request.opposeCount, 0);
    expect(request.commentCount, 0);
  });

  test('PublicRequest copyWith overrides selected fields', () {
    final original = sampleRequest(myVote: 'support');
    final updatedAt = DateTime.parse('2026-05-15T00:00:00Z');
    final changed = original.copyWith(
      status: 'resolved',
      supportCount: 9,
      opposeCount: 3,
      commentCount: 7,
      myVote: 'oppose',
      updatedAt: updatedAt,
    );

    expect(changed.id, original.id);
    expect(changed.status, 'resolved');
    expect(changed.supportCount, 9);
    expect(changed.opposeCount, 3);
    expect(changed.commentCount, 7);
    expect(changed.supportedByMe, isFalse);
    expect(changed.opposedByMe, isTrue);
    expect(changed.updatedAt, updatedAt);

    final same = original.copyWith();
    expect(same.id, original.id);
    expect(same.groupId, original.groupId);
    expect(same.authorId, original.authorId);
    expect(same.authorName, original.authorName);
    expect(same.requestType, original.requestType);
    expect(same.interactionMode, original.interactionMode);
    expect(same.title, original.title);
    expect(same.body, original.body);
    expect(same.status, original.status);
    expect(same.supportCount, original.supportCount);
    expect(same.opposeCount, original.opposeCount);
    expect(same.commentCount, original.commentCount);
    expect(same.myVote, original.myVote);
    expect(same.createdAt, original.createdAt);
    expect(same.updatedAt, original.updatedAt);
  });

  test('PublicRequest displayBody uses parsed content text for media payloads',
      () {
    final content = PublicRequestContent(
      text: '  Photo report  ',
      photos: const [
        PublicRequestPhoto(
          name: 'road.jpg',
          sizeBytes: 1200,
          base64Data: 'base64-photo',
          fileId: 'FILE-1',
          url: 'https://example.test/road.jpg',
        ),
      ],
      videos: const [
        PublicRequestVideo(
          name: 'road.mp4',
          sizeBytes: 2400,
          base64Data: 'base64-video',
          mimeType: 'video/quicktime',
        ),
      ],
    );
    final request = sampleRequest(body: content.toPayload());

    expect(request.content.hasMedia, isTrue);
    expect(request.displayBody, 'Photo report');
    expect(request.content.photos.single.fileId, 'FILE-1');
    expect(request.content.photos.single.url, 'https://example.test/road.jpg');
    expect(request.content.videos.single.mimeType, 'video/quicktime');
  });

  test('PublicRequestContent keeps plain and invalid payloads as text', () {
    expect(PublicRequestContent.empty.hasMedia, isFalse);
    expect(
      const PublicRequestContent(text: '  hello  ', photos: []).toPayload(),
      'hello',
    );
    expect(PublicRequestContent.tryParse('').text, '');
    expect(PublicRequestContent.tryParse('plain text').text, 'plain text');
    expect(PublicRequestContent.tryParse('{broken json').text, '{broken json');
    expect(PublicRequestContent.tryParse('[1,2,3]').text, '[1,2,3]');
  });

  test('PublicRequestContent parses partial media JSON safely', () {
    final parsed = PublicRequestContent.tryParse('''
      {
        "text": "Mixed media",
        "photos": [
          {"id": "PHOTO-ID"},
          "ignored",
          {"name": "full.jpg", "size_bytes": 10, "base64": "abc"}
        ],
        "videos": [
          {"name": "clip.mov"},
          42
        ]
      }
    ''');

    expect(parsed.text, 'Mixed media');
    expect(parsed.moderationSummary(), 'Mixed media');
    expect(parsed.photos, hasLength(2));
    expect(parsed.photos.first.name, 'photo.jpg');
    expect(parsed.photos.first.fileId, 'PHOTO-ID');
    expect(parsed.photos.first.sizeBytes, 0);
    expect(parsed.photos.last.base64Data, 'abc');
    expect(parsed.videos.single.name, 'clip.mov');
    expect(parsed.videos.single.sizeBytes, 0);
    expect(parsed.videos.single.mimeType, 'video/mp4');
  });

  test(
      'PublicRequestPhoto and video JSON include optional fields only when set',
      () {
    final photo = const PublicRequestPhoto(
      name: 'a.jpg',
      sizeBytes: 5,
    ).toJson();
    final video = const PublicRequestVideo(
      name: 'a.mp4',
      sizeBytes: 8,
      base64Data: 'video-data',
    ).toJson();

    expect(photo, {'name': 'a.jpg', 'size_bytes': 5});
    expect(video['base64'], 'video-data');
    expect(video['mime_type'], 'video/mp4');
  });

  test('PublicRequestComment parses JSON', () {
    final comment = PublicRequestComment.fromJson({
      'id': 'COM-1',
      'request_id': 'REQ-1',
      'author_id': 'U-2',
      'author_name': 'User',
      'body': 'I support this.',
      'created_at': '2026-05-14T00:00:00Z',
    });

    expect(comment.id, 'COM-1');
    expect(comment.requestId, 'REQ-1');
    expect(comment.body, 'I support this.');
  });

  test('PublicRequestComment defaults missing author name', () {
    final comment = PublicRequestComment.fromJson({
      'id': 'COM-2',
      'request_id': 'REQ-2',
      'author_id': 'U-3',
      'body': 'Anonymous support.',
      'created_at': '2026-05-14T00:00:00Z',
    });

    expect(comment.authorName, 'User');
  });
}
