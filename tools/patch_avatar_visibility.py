from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one match in {path}, found {count}: {old[:120]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_count(path: str, old: str, new: str, expected: int) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expected:
        raise RuntimeError(f"Expected {expected} matches in {path}, found {count}: {old[:120]!r}")
    file_path.write_text(text.replace(old, new), encoding="utf-8")


# User avatars should be available to every widget from the session model.
replace_once(
    "lib/data/models.dart",
    "  bool get isPlatformAdmin => role == 'platform_admin' || role == 'super_admin';\n  bool get isSuperAdmin => role == 'super_admin';\n\n  factory UserProfile.fromJson",
    "  bool get isPlatformAdmin => role == 'platform_admin' || role == 'super_admin';\n  bool get isSuperAdmin => role == 'super_admin';\n\n  Uint8List? get avatarBytes {\n    final value = avatarData.trim();\n    if (value.isEmpty) return null;\n    try {\n      final separator = value.indexOf(',');\n      final payload = separator >= 0 ? value.substring(separator + 1) : value;\n      return base64Decode(payload);\n    } catch (_) {\n      return null;\n    }\n  }\n\n  factory UserProfile.fromJson",
)

# Publications now carry and decode their author's avatar just like comments.
replace_once(
    "lib/data/public_request.dart",
    "    required this.authorName,\n    required this.requestType,",
    "    required this.authorName,\n    this.authorAvatarData = '',\n    required this.requestType,",
)
replace_once(
    "lib/data/public_request.dart",
    "  final String authorName;\n  final String requestType;",
    "  final String authorName;\n  final String authorAvatarData;\n  final String requestType;",
)
replace_once(
    "lib/data/public_request.dart",
    "  bool get supportedByMe => myVote == 'support';\n  bool get opposedByMe => myVote == 'oppose';\n  PublicRequestContent get content",
    "  bool get supportedByMe => myVote == 'support';\n  bool get opposedByMe => myVote == 'oppose';\n\n  Uint8List? get authorAvatarBytes {\n    final value = authorAvatarData.trim();\n    if (value.isEmpty) return null;\n    try {\n      final separator = value.indexOf(',');\n      final payload = separator >= 0 ? value.substring(separator + 1) : value;\n      return base64Decode(payload);\n    } catch (_) {\n      return null;\n    }\n  }\n\n  PublicRequestContent get content",
)
replace_once(
    "lib/data/public_request.dart",
    "      authorName: json['author_name'] as String? ?? 'User',\n      requestType:",
    "      authorName: json['author_name'] as String? ?? 'User',\n      authorAvatarData:\n          json['author_avatar_data'] as String? ??\n          json['avatar_data'] as String? ??\n          '',\n      requestType:",
)
replace_once(
    "lib/data/public_request.dart",
    "    String? authorName,\n    String? requestType,",
    "    String? authorName,\n    String? authorAvatarData,\n    String? requestType,",
)
replace_once(
    "lib/data/public_request.dart",
    "      authorName: authorName ?? this.authorName,\n      requestType:",
    "      authorName: authorName ?? this.authorName,\n      authorAvatarData: authorAvatarData ?? this.authorAvatarData,\n      requestType:",
)

# Every post card uses the supplied avatar bytes.
post_avatar_old = "KoomAvatar(label: request.authorName, radius: 20)"
post_avatar_new = "KoomAvatar(\n                  label: request.authorName,\n                  radius: 20,\n                  imageBytes: request.authorAvatarBytes,\n                )"
post_matches = 0
for dart_file in Path("lib").rglob("*.dart"):
    text = dart_file.read_text(encoding="utf-8")
    count = text.count(post_avatar_old)
    if count:
        post_matches += count
        dart_file.write_text(text.replace(post_avatar_old, post_avatar_new), encoding="utf-8")
if post_matches < 1:
    raise RuntimeError("No publication avatar widget was updated")

# The main groups overview must show the logged-in user's real avatar.
replace_once(
    "lib/features/groups/groups_screen.dart",
    "    required this.userName,\n    required this.groupCount,",
    "    required this.userName,\n    required this.userAvatarBytes,\n    required this.groupCount,",
)
replace_once(
    "lib/features/groups/groups_screen.dart",
    "  final String userName;\n  final int groupCount;",
    "  final String userName;\n  final Uint8List? userAvatarBytes;\n  final int groupCount;",
)
replace_count(
    "lib/features/groups/groups_screen.dart",
    "                      userName: widget.session.user.displayName,\n                      groupCount:",
    "                      userName: widget.session.user.displayName,\n                      userAvatarBytes: widget.session.user.avatarBytes,\n                      groupCount:",
    2,
)
replace_once(
    "lib/features/groups/groups_screen.dart",
    "              KoomAvatar(\n                label: safeName,\n                radius: 28,\n                background: Colors.white.withValues(alpha: 0.18),\n              ),",
    "              KoomAvatar(\n                label: safeName,\n                radius: 28,\n                background: Colors.white.withValues(alpha: 0.18),\n                imageBytes: userAvatarBytes,\n              ),",
)

# Group image changes are applied live for every connected member.
replace_once(
    "lib/features/groups/groups_screen.dart",
    "      case 'public_request.read':\n        setUnreadPublicRequests(event.groupId, 0);\n        break;\n      case 'invite.created':",
    "      case 'public_request.read':\n        setUnreadPublicRequests(event.groupId, 0);\n        break;\n      case 'group.avatar_updated':\n        final payload = event.payload;\n        if (payload is Map<String, dynamic>) {\n          final avatarData = payload['avatar_data'] as String? ?? '';\n          setGroups(\n            currentGroups\n                .map(\n                  (group) => group.id == event.groupId\n                      ? group.copyWith(avatarData: avatarData)\n                      : group,\n                )\n                .toList(),\n          );\n        }\n        break;\n      case 'invite.created':",
)
replace_once(
    "lib/features/groups/groups_screen.dart",
    "    await Navigator.of(context).push(\n      MaterialPageRoute(\n        builder: (_) => PublicRequestsScreen(\n          api: widget.api,\n          user: widget.session.user,\n          group: group,\n        ),\n      ),\n    );\n  }",
    "    await Navigator.of(context).push(\n      MaterialPageRoute(\n        builder: (_) => PublicRequestsScreen(\n          api: widget.api,\n          user: widget.session.user,\n          group: group,\n        ),\n      ),\n    );\n    if (mounted) {\n      await refresh(silent: true);\n    }\n  }",
)
replace_once(
    "lib/features/public_requests/public_requests_screen.dart",
    "      case 'public_request.created':\n        upsertRequestFromPayload(event.payload);",
    "      case 'group.avatar_updated':\n        final payload = event.payload;\n        if (payload is Map<String, dynamic>) {\n          final avatarData = payload['avatar_data'] as String? ?? '';\n          setState(() {\n            currentGroup = currentGroup.copyWith(avatarData: avatarData);\n          });\n        }\n        break;\n      case 'public_request.created':\n        upsertRequestFromPayload(event.payload);",
)

# Ensure a just-created post still has the local avatar if an older server omits it.
replace_once(
    "lib/features/public_requests/public_requests_screen.dart",
    "    if (created != null) {\n      final updated = [\n        created,",
    "    if (created != null) {\n      final visibleCreated = created.authorAvatarData.trim().isEmpty\n          ? created.copyWith(authorAvatarData: widget.user.avatarData)\n          : created;\n      final updated = [\n        visibleCreated,",
)
replace_once(
    "lib/features/public_requests/public_requests_screen.dart",
    "        ...cachedRequests.where((request) => request.id != created.id),",
    "        ...cachedRequests.where((request) => request.id != visibleCreated.id),",
)

# Remove temporary patch machinery from the final verified commit.
Path(".github/workflows/apply-avatar-visibility-fix.yml").unlink(missing_ok=True)
Path(__file__).unlink(missing_ok=True)
