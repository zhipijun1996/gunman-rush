"""Static Godot dependencies for the existing project check and audit report.

This is a code boundary check, not a content registry or a replacement for the
engine/PCK checks. Computed load paths remain explicitly reported as dynamic.
"""
from pathlib import Path
import re

ROOTS = ("game", "scripts", "scenes", "resources", "experiments", "assets")
CORE = {"player", "combat", "loadout", "economy", "rewards", "progression",
        "enemies", "bosses", "world"}
TOKENS = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\#[^\n]*')

RESOURCE_TOKENS = re.compile(TOKENS.pattern + r"|;[^\n]*")

def without_comments(text, resource=False):
    tokens = RESOURCE_TOKENS if resource else TOKENS
    return tokens.sub(lambda m: "".join("\n" if c == "\n" else " " for c in m.group()) if m.group().startswith(("#", ";") if resource else ("#",)) else m.group(), text)


def code_only(text, resource=False):
    tokens = RESOURCE_TOKENS if resource else TOKENS
    return tokens.sub(lambda m: "".join("\n" if c == "\n" else " " for c in m.group()), text)


def balanced_end(code, start, opening="(", closing=")"):
    """Strings/comments have been masked at identical character offsets."""
    depth = 0
    for index in range(start, len(code)):
        if code[index] == opening:
            depth += 1
        elif code[index] == closing:
            depth -= 1
            if depth == 0:
                return index
    return None  # Syntax validity remains the engine's responsibility.


def previous_word(code, index):
    end = index
    while end and code[end - 1].isspace():
        end -= 1
    start = end
    while start and (code[start - 1].isalnum() or code[start - 1] == "_"):
        start -= 1
    return code[start:end], start, end


def resource_calls(raw, code):
    for match in re.finditer(r"\b(?:load|preload)\s*\(", code):
        word, _, end = previous_word(code, match.start())
        # Only the built-in calls and ResourceLoader.load are known loaders;
        # a same-named method on an arbitrary object is not this dependency.
        if end and code[end - 1] == "." and previous_word(code, end - 1)[0] != "ResourceLoader":
            continue
        if word == "func":
            continue
        start = match.end() - 1
        end = balanced_end(code, start)
        if end is not None:
            # ResourceLoader.load also accepts type/cache arguments. Only the
            # first argument names the dependency; commas inside expressions
            # or strings belong to that expression rather than the call.
            depth = 0
            for index in range(start + 1, end):
                if code[index] in "([{":
                    depth += 1
                elif code[index] in ")]}":
                    depth -= 1
                elif code[index] == "," and depth == 0:
                    end = index
                    break
            yield without_comments(raw[start + 1:end]).strip()


def class_references(code):
    for match in re.finditer(r"\b[A-Za-z_]\w*\b", code):
        word, _, end = previous_word(code, match.start())
        if (end and code[end - 1] == ".") or word in {"var", "const", "func", "signal", "class", "class_name"}:
            continue
        yield match.group()


def inspect(root):
    root = Path(root)
    files = sorted({p for folder in ROOTS for p in (root / folder).rglob("*")
                    if p.is_file() and p.suffix in {".gd", ".tscn", ".tres"}})
    texts = {p.relative_to(root).as_posix(): p.read_text() for p in files}
    classes, errors = {}, []
    for name, text in texts.items():
        if not name.endswith(".gd"):
            continue
        match = re.search(r"(?m)^[ \t]*class_name\s+(\w+)", code_only(text))
        if match:
            key = match.group(1)
            if key in classes:
                errors.append(f"Duplicate runtime class {key}: {classes[key]}, {name}")
            else:
                classes[key] = name
    edges, dynamic = set(), []
    for name, raw in texts.items():
        code = code_only(raw, resource=not name.endswith(".gd"))
        if name.endswith(".gd"):
            for token in set(class_references(code)):
                if token in classes and classes[token] != name:
                    edges.add((name, classes[token], "class"))
            for arg in resource_calls(raw, code):
                literal = re.fullmatch(r"[\"']res://([^\"']+)[\"']", arg)
                if literal:
                    edges.add((name, literal.group(1), "resource"))
                else:
                    dynamic.append({"source": name, "expression": arg})
            for match in re.finditer(r"(?m)^[ \t]*extends\b", code):
                literal = re.match(r"[\"']res://([^\"']+)[\"']", raw[match.end():].lstrip())
                if literal:
                    edges.add((name, literal.group(1), "resource"))
        else:
            for match in re.finditer(r"\[\s*ext_resource\b", code):
                end = balanced_end(code, match.start(), "[", "]")
                if end is None:
                    continue
                header = without_comments(raw[match.start():end + 1], resource=True)
                for path in re.findall(r'\bpath\s*=\s*"res://([^"\n]+)"', header):
                    edges.add((name, path, "resource"))
    application = {p for p in texts if p.startswith("game/application/")}
    # The actual App is still in its old path during staged migration.
    application.update(classes[c] for c in ("DemoApp", "RunSession", "RunComposition") if c in classes)
    for source, target, kind in sorted(edges):
        if target.startswith("tests/"):
            errors.append(f"Runtime loads test implementation: {source} -> {target}")
        parts = Path(source).parts
        if len(parts) > 2 and parts[0] == "game" and parts[1] in CORE:
            if target in application or target.startswith("experiments/"):
                errors.append(f"Core module depends on entry/composition: {source} -> {target}")
    return {"files": len(texts), "classes": classes,
            "edges": [{"source": a, "target": b, "kind": c} for a, b, c in sorted(edges)],
            "dynamic_loads": dynamic, "errors": errors,
            "scope": "Static class and literal resource dependencies; dynamic loads require runtime/export validation"}
