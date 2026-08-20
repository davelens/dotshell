#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$repo_root" <<'PY'
import sys
from pathlib import Path

RENDERERS = {"Text", "TextInput", "TextEdit"}


def tokenize(source):
    tokens = []
    index = 0
    line = 1

    while index < len(source):
        char = source[index]
        if char == "\n":
            line += 1
            index += 1
        elif char.isspace():
            index += 1
        elif source.startswith("//", index):
            newline = source.find("\n", index + 2)
            index = len(source) if newline == -1 else newline
        elif source.startswith("/*", index):
            end = source.find("*/", index + 2)
            if end == -1:
                raise ValueError(f"unterminated comment on line {line}")
            line += source.count("\n", index, end + 2)
            index = end + 2
        elif char in "'\"`":
            quote = char
            start_line = line
            index += 1
            while index < len(source) and source[index] != quote:
                if source[index] == "\\":
                    if index + 1 < len(source) and source[index + 1] == "\n":
                        line += 1
                    index += 2
                else:
                    if source[index] == "\n":
                        line += 1
                    index += 1
            if index == len(source):
                raise ValueError(f"unterminated string on line {start_line}")
            index += 1
            tokens.append(("STRING", start_line))
        elif char.isalpha() or char == "_":
            end = index + 1
            while end < len(source) and (source[end].isalnum() or source[end] == "_"):
                end += 1
            tokens.append((source[index:end], line))
            index = end
        else:
            tokens.append((char, line))
            index += 1

    return tokens


def starts_binding(tokens, index):
    if index >= len(tokens) or not (tokens[index][0][0].isalpha() or tokens[index][0][0] == "_"):
        return False
    index += 1
    while index + 1 < len(tokens) and tokens[index][0] == ".":
        index += 2
    return index < len(tokens) and tokens[index][0] == ":"


errors = []
for path in sorted(Path(sys.argv[1]).rglob("*.qml")):
    try:
        tokens = tokenize(path.read_text())
    except ValueError as error:
        errors.append(f"{path.relative_to(sys.argv[1])}: {error}")
        continue

    for index, (token, line) in enumerate(tokens[:-1]):
        if token not in RENDERERS or tokens[index + 1][0] != "{":
            continue

        depth = 1
        cursor = index + 2
        families = []
        while cursor < len(tokens) and depth:
            value = tokens[cursor][0]
            if value == "{":
                depth += 1
            elif value == "}":
                depth -= 1
            elif depth == 1 and [item[0] for item in tokens[cursor:cursor + 4]] == ["font", ".", "family", ":"]:
                families.append(cursor)
            cursor += 1

        if depth:
            errors.append(f"{path.relative_to(sys.argv[1])}:{line}: unbalanced {token} block")
            continue
        if not families:
            errors.append(f"{path.relative_to(sys.argv[1])}:{line}: {token} lacks direct font.family")
            continue

        block_end = cursor - 1
        for family in families:
            binding_line = tokens[family + 3][1]
            binding_depth = 1
            value_index = family + 4
            while value_index < block_end:
                value, value_line = tokens[value_index]
                if binding_depth == 1 and (value == ";" or (value_line > binding_line and (starts_binding(tokens, value_index) or (value_index + 1 < len(tokens) and tokens[value_index + 1][0] == "{")))):
                    break
                if value == "undefined":
                    errors.append(f"{path.relative_to(sys.argv[1])}:{tokens[family][1]}: font.family uses undefined")
                    break
                if value == "{":
                    binding_depth += 1
                elif value == "}":
                    binding_depth -= 1
                value_index += 1

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print("theme font coverage tests passed")
PY
