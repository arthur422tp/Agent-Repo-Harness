from pathlib import Path

from .models import Document


REQUIRED_METADATA = ("document_id", "title", "contract_type", "jurisdiction")


def load_document(path: Path) -> Document:
    path = Path(path)
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise ValueError(f"{path}: missing metadata header")

    metadata: dict[str, str] = {}
    body_start = None
    for line_number, line in enumerate(lines[1:], start=2):
        if line == "---":
            body_start = line_number
            break
        if ":" not in line:
            raise ValueError(f"{path}:{line_number}: invalid metadata line")
        key, value = (part.strip() for part in line.split(":", 1))
        if not key or not value:
            raise ValueError(f"{path}:{line_number}: invalid metadata line")
        metadata[key] = value

    if body_start is None:
        raise ValueError(f"{path}: unterminated metadata header")

    for field in REQUIRED_METADATA:
        if not metadata.get(field):
            raise ValueError(f"{path}: missing required metadata field: {field}")

    return Document(
        document_id=metadata["document_id"],
        title=metadata["title"],
        path=path,
        metadata=metadata,
        content="\n".join(lines[body_start:]).strip(),
    )


def load_corpus(root: Path) -> list[Document]:
    root = Path(root)
    if not root.is_dir():
        raise FileNotFoundError(f"corpus directory not found: {root}")
    return [load_document(path) for path in sorted(root.glob("*.md"))]
