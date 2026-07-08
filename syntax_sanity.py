from pathlib import Path
files=[Path('lib/data/public_request.dart'),Path('lib/features/public_requests/public_requests_screen.dart'),Path('lib/features/public_requests/public_requests_widgets.dart'),Path('lib/features/public_requests/public_request_media_widgets.dart')]
for p in files:
    s=p.read_text(encoding='utf-8')
    stack=[]
    pairs={')':'(',']':'[','}':'{'}
    in_single=False; in_double=False; esc=False
    ok=True
    for n,ch in enumerate(s):
        if esc:
            esc=False; continue
        if ch=='\\':
            esc=True; continue
        if not in_double and ch=="'":
            in_single=not in_single; continue
        if not in_single and ch=='"':
            in_double=not in_double; continue
        if in_single or in_double: continue
        if ch in '([{': stack.append(ch)
        elif ch in ')]}':
            if not stack or stack[-1]!=pairs[ch]:
                print('BAD',p,'at',n,ch)
                ok=False
                break
            stack.pop()
    if ok:
        print('OK',p,'remaining',len(stack),'single',in_single,'double',in_double)
