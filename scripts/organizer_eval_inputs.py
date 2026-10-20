"""Fixed-corpus identity; never substitutes a transcript for actual image bytes."""
import hashlib
import json
from pathlib import Path


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def case_fingerprint(case, root, image_bytes=None):
    kind = case.get('sourceType', 'TEXT')
    content = {key: case.get(key, '') for key in ('sourceText', 'sourceLabel', 'teacherName', 'contentType')}
    content['sourceType'] = kind
    if kind == 'IMAGE':
        if not case.get('imagePath'):
            raise ValueError('Image case requires actual imagePath: ' + case['id'])
        content['imageHash'] = hashlib.sha256(image_bytes if image_bytes is not None else (Path(root) / case['imagePath']).read_bytes()).hexdigest()
    elif kind != 'TEXT':
        raise ValueError('Unsupported source type: ' + str(kind))
    return digest(content)
