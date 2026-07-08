from pathlib import Path
bad = [chr(0x0420)+chr(0x045f), chr(0x0420)+chr(0x0459), chr(0x0421)+chr(0x0403), chr(0x0421)+chr(0x201a), chr(0x0422)+chr(0x0407), chr(0x040e)+chr(0x00a9)]
found=[]
for p in Path('lib').rglob('*.dart'):
    s=p.read_text(encoding='utf-8')
    if any(x in s for x in bad): found.append(str(p))
print('\n'.join(found) if found else 'NO_MOJIBAKE_PATTERNS')
