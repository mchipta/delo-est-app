import re
import sys

p = sys.argv[1]
s = open(p, encoding='utf-8').read()

perm = '    <uses-permission android:name="android.permission.INTERNET"/>\n'
intents = (
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>\n'
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
)

if '<queries>' in s:
    s = s.replace('<queries>', '<queries>\n' + intents, 1)
    s = s.replace('<application', perm + '    <application', 1)
else:
    s = s.replace('<application', perm + '    <queries>\n' + intents + '    </queries>\n    <application', 1)

s = re.sub(r'android:label="[^"]*"', 'android:label="ДелоЕсть"', s, count=1)
open(p, 'w', encoding='utf-8').write(s)
print('manifest patched')
