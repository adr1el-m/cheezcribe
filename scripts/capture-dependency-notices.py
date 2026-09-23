"""Capture resolved package-level notices for the starter and practice lab."""
from pathlib import Path
from urllib.parse import urlparse, unquote
import json
root=Path(__file__).resolve().parent.parent
for app_name in ('app', 'preparation/flutter_lab'):
    app=root/app_name
    config=app/'.dart_tool/package_config.json'
    if not config.exists(): continue
    notices=[]; rows=[]
    for package in json.loads(config.read_text())['packages']:
        if package['name'] in ('appcon_starter','appcon_ai_lab'): continue
        uri=package['rootUri']
        pkg=Path(unquote(urlparse(uri).path)) if uri.startswith('file:') else (config.parent/uri).resolve()
        license_file=next((pkg/name for name in ('LICENSE','LICENSE.md','LICENSE.txt') if (pkg/name).is_file()),None)
        if license_file is None and str(pkg).startswith(str(root/'.tooling/flutter')):
            license_file=root/'.tooling/flutter/LICENSE'
        status='Captured package or SDK notice' if license_file else 'REVIEW NEEDED'
        rows.append(f"| {package['name']} | {status} |\n")
        if license_file:
            notices.append('\n'+'='*70+'\n'+package['name']+'\n'+'='*70+'\n'+license_file.read_text(errors='replace'))
    label='STARTER' if app_name=='app' else 'LAB'
    (root/f'docs/{label}_DEPENDENCY_NOTICES.txt').write_text('Resolved package notices. Proprietary service access is separate.\n'+''.join(notices))
    (root/f'docs/{label}_DEPENDENCIES.md').write_text('# '+label.title()+' resolved dependencies\n\nVersions are recorded in the app pubspec.lock. This records package-level notices, not a full legal audit of platform binaries or service terms.\n\n| Package | Notice |\n|---|---|\n'+''.join(rows))
    print(app_name, len(rows), 'dependency notices recorded.')
