import os, json, re

PROJECT_ROOT = r"d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working"

# Build UID map from .uid files
uid_map = {}
for root, _, files in os.walk(PROJECT_ROOT):
    for f in files:
        if f.endswith('.uid'):
            uid_path = os.path.join(root, f)
            with open(uid_path, 'r', encoding='utf-8') as uf:
                uid = uf.read().strip()
            # resource path without .uid and using forward slashes
            rel_path = os.path.relpath(uid_path, PROJECT_ROOT)[:-4]  # strip .uid
            res_path = f"res://{rel_path.replace(os.sep, '/') }"
            uid_map[res_path] = uid

# Save map for debugging (optional)
with open(os.path.join(PROJECT_ROOT, 'uid_map.json'), 'w', encoding='utf-8') as out:
    json.dump(uid_map, out, indent=2)

# File extensions to process (non‑image source files)
extensions = {'.gd', '.cs', '.ts', '.js', '.py', '.json', '.cfg', '.ini', '.xml', '.shader', '.tres', '.tscn'}

# Replace occurrences
for root, _, files in os.walk(PROJECT_ROOT):
    for f in files:
        _, ext = os.path.splitext(f)
        if ext.lower() in extensions:
            file_path = os.path.join(root, f)
            with open(file_path, 'r', encoding='utf-8') as fr:
                content = fr.read()
            new_content = content
            for res, uid in uid_map.items():
                if res in new_content:
                    new_content = new_content.replace(res, uid)
            if new_content != content:
                with open(file_path, 'w', encoding='utf-8') as fw:
                    fw.write(new_content)
                print(f"Updated {file_path}")
print('Replacement complete.')
