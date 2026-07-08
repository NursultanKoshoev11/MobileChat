from pathlib import Path
p=Path('lib/features/public_requests/public_requests_widgets.dart')
s=p.read_text(encoding='utf-8')
s=s.replace('''                  onStatus: widget.onStatusChanged,
''', '''                  onStatus: widget.onStatusChanged == null
                      ? null
                      : (status) {
                          setRequest(request.copyWith(status: status, updatedAt: DateTime.now()));
                          widget.onStatusChanged!(status);
                        },
''')
s=s.replace('''                if (widget.request.displayBody.isNotEmpty)
''', '''                if (request.displayBody.isNotEmpty)
''')
s=s.replace('''                    child: Text(widget.request.displayBody,
''', '''                    child: Text(request.displayBody,
''')
s=s.replace('''                if (widget.request.content.photos.isNotEmpty) ...[
''', '''                if (request.content.photos.isNotEmpty) ...[
''')
s=s.replace('''                    photos: widget.request.content.photos,
''', '''                    photos: request.content.photos,
''')
s=s.replace('''                if (snapshot.connectionState == ConnectionState.waiting)
''', '''                if (snapshot.connectionState == ConnectionState.waiting && cachedComments.isEmpty)
''')
p.write_text(s, encoding='utf-8')
print('details patched')
