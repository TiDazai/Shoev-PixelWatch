"""Keep native translations and the SwiftUI catalog in sync; audit static UI labels."""
import json
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
translations=json.loads((root/'PixelWatch/Resources/Translations.json').read_text())
catalog=json.loads((root/'PixelWatch/Resources/Localizable.xcstrings').read_text())['strings']
assert set(translations)==set(catalog), 'Translation key sets differ'
formats=re.compile(r'%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?(?:ll|l)?[@diufeg%]')
for key,value in translations.items():
 assert catalog[key]['localizations']['ru']['stringUnit']['value']==value, key
 assert formats.findall(key)==formats.findall(value), 'Format arguments differ: '+key
identity={'PixelWatch','SHOEV PixelWatch','SHOEV PRODUCTS','SHOEV PRODUCTS  /  0.1.1','SHOEV SYSTEMS\nSHOEV PRODUCTS','GitHub'}
labels=re.compile(r'(?:Text|Button|Toggle|Picker|Label|LabeledContent|\.help|\.alert)\(\s*("(?:[^"\\]|\\.)*")')
missing=[]
for path in list((root/'PixelWatch/Views').glob('*.swift'))+[root/'PixelWatch/App/PixelWatchApp.swift']:
 for match in labels.finditer(path.read_text()):
  literal=match.group(1)
  if '\\(' in literal: continue # User text/numbers or explicitly formatted dynamic strings.
  value=json.loads(literal)
  if value not in translations and value not in identity: missing.append((path.name,value))
assert not missing, 'Missing UI translations: '+repr(missing)
print(f'{len(translations)} translations: catalog, placeholders and static UI labels verified')
