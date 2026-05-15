from pathlib import Path

path = Path("lib/main_offline.dart")
text = path.read_text()

old = """          FeedPostCard(post: widget.post, group: widget.group),
          if (widget.group.canModerate) DropdownButtonFormField<String>(value: widget.post.status, decoration: const InputDecoration(labelText: 'Admin status'), items: const [DropdownMenuItem(value: 'new', child: Text('New')), DropdownMenuItem(value: 'under_review', child: Text('Under review')), DropdownMenuItem(value: 'accepted', child: Text('Accepted')), DropdownMenuItem(value: 'rejected', child: Text('Rejected')), DropdownMenuItem(value: 'resolved', child: Text('Resolved'))], onChanged: (value) { if (value != null) demo.updateStatus(widget.post, value); }),
"""
new = """          DetailsOnlyPostCard(post: widget.post),
          if (widget.group.canModerate) DropdownButtonFormField<String>(value: widget.post.status, decoration: const InputDecoration(labelText: 'Admin status'), items: const [DropdownMenuItem(value: 'new', child: Text('New')), DropdownMenuItem(value: 'under_review', child: Text('Under review')), DropdownMenuItem(value: 'accepted', child: Text('Accepted')), DropdownMenuItem(value: 'rejected', child: Text('Rejected')), DropdownMenuItem(value: 'resolved', child: Text('Resolved'))], onChanged: (value) { if (value != null) demo.updateStatus(widget.post, value); }),
"""

if old in text:
    text = text.replace(old, new)

insert_before = """class DetailsScreen extends StatefulWidget {"""
card_class = """
class DetailsOnlyPostCard extends StatelessWidget {
  const DetailsOnlyPostCard({super.key, required this.post});
  final DemoPost post;

  @override
  Widget build(BuildContext context) {
    final myVote = demo.votes[post.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [ChipLabel(text: post.type), const SizedBox(width: 8), ChipLabel(text: post.mode.label), const Spacer(), Text(post.status, style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 10),
            Text(post.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(post.body),
            const SizedBox(height: 10),
            Text('By ${post.author}', style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)),
            if (post.canVote) ...[
              const SizedBox(height: 12),
              Row(children: [
                OutlinedButton.icon(onPressed: () => demo.vote(post, 'support'), icon: Icon(myVote == 'support' ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined), label: Text('${post.support}')),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () => demo.vote(post, 'oppose'), icon: Icon(myVote == 'oppose' ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined), label: Text('${post.oppose}')),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

"""

if "class DetailsOnlyPostCard" not in text:
    text = text.replace(insert_before, card_class + insert_before)

if "DetailsOnlyPostCard(post: widget.post)" not in text:
    raise SystemExit("Failed to patch details screen card")

path.write_text(text)
print("Offline details Read button patch applied.")
