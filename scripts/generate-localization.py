"""Generate SwiftUI catalog from the authoritative native translation dictionary."""
import json
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
values=json.loads((root/'PixelWatch/Resources/Translations.json').read_text())
strings={key:{'localizations':{'en':{'stringUnit':{'state':'translated','value':re.sub(r'\.(?=\s|$)','',key)}},'ru':{'stringUnit':{'state':'translated','value':value}}}} for key,value in values.items()}
(root/'PixelWatch/Resources/Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':strings,'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
