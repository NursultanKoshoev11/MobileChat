import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/data/public_request.dart';

void main() {
  test('PublicRequest parses JSON', () {
    final request = PublicRequest.fromJson({
      'id': 'REQ-1',
      'group_id': 'G-1',
      'author_id': 'U-1',
      'author_name': 'Nursultan',
      'request_type': 'complaint',
      'title': 'Road problem',
      'body': 'Please repair the road near the school.',
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
    expect(request.supportCount, 10);
    expect(request.opposeCount, 2);
    expect(request.commentCount, 3);
    expect(request.supportedByMe, isTrue);
    expect(request.opposedByMe, isFalse);
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
