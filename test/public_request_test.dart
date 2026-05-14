import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/data/public_request.dart';

void main() {
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
}
