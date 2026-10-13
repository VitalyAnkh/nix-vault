"""Merge the owned Warp settings without taking ownership of Warp's settings.toml."""

import argparse
import copy
import datetime
import json
import math
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
# Warp writes TOML 1.1 (inline tables across lines, with trailing commas); the standard
# library's tomllib reads only TOML 1.0. tomli, its upstream, reads both.
import tomli


BARE_KEY = re.compile(r"[A-Za-z0-9_-]+")
ESCAPES = {
    '"': '\\"', "\\": "\\\\", "\b": "\\b", "\t": "\\t", "\n": "\\n", "\f": "\\f", "\r": "\\r",
}


class ConfigError(ValueError):
    pass


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ConfigError("Duplicate JSON key: " + key)
        result[key] = value
    return result


def reject_constant(value):
    raise ConfigError("Invalid JSON constant: " + value)


def finite_float(value):
    number = float(value)
    if not math.isfinite(number):
        raise ConfigError("JSON number out of range: " + value)
    return number


def parse_json(contents):
    return json.loads(
        contents,
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
        parse_float=finite_float,
    )


def format_key(key):
    return key if BARE_KEY.fullmatch(key) else format_string(key)


def dotted(path):
    return ".".join(map(format_key, path))


def format_string(value):
    characters = []
    for character in value:
        if character in ESCAPES:
            characters.append(ESCAPES[character])
        elif ord(character) < 0x20 or ord(character) == 0x7F:
            characters.append("\\u%04X" % ord(character))
        else:
            characters.append(character)
    return '"' + "".join(characters) + '"'


def format_value(value, path):
    """Return value as TOML text. Tables are written as headers, never inline."""
    # bool is a subclass of int; check it first.
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        if not -(2**63) <= value < 2**63:
            raise ConfigError(dotted(path) + ": the integer is outside TOML's 64-bit range")
        return str(value)
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ConfigError(dotted(path) + ": the number is not finite")
        return repr(value)
    if isinstance(value, str):
        return format_string(value)
    if isinstance(value, list):
        return "[" + ", ".join(format_value(item, path) for item in value) + "]"
    raise ConfigError(dotted(path) + ": unsupported value " + json.dumps(value))


def owned_leaves(settings, path=()):
    """Yield (key path, value) for every value below the owned tables."""
    for key, value in settings.items():
        here = path + (key,)
        if not key:
            raise ConfigError("Owned setting keys must not be empty: " + dotted(here))
        if isinstance(value, dict):
            if not value:
                raise ConfigError("Owned tables must not be empty: " + dotted(here))
            yield from owned_leaves(value, here)
        else:
            format_value(value, here)
            yield here, value


def read_settings(path):
    settings = parse_json(Path(path).read_bytes())
    if not isinstance(settings, dict):
        raise ConfigError("The owned settings must be a JSON object")
    return list(owned_leaves(settings))


def same(left, right):
    """Compare parsed TOML by type as well, so that true never stands for 1 or 1.0."""
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(same(left[k], right[k]) for k in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(map(same, left, right))
    if isinstance(left, float) and math.isnan(left):
        return math.isnan(right)
    return left == right


def lookup(document, path):
    value = document
    for key in path:
        if not isinstance(value, dict) or key not in value:
            return None
        value = value[key]
    return value


def apply_leaves(document, leaves):
    """Return a copy of the parsed document with the owned leaves set."""
    result = copy.deepcopy(document)
    for path, value in leaves:
        table = result
        for depth, key in enumerate(path[:-1]):
            table = table.setdefault(key, {})
            if not isinstance(table, dict):
                raise ConfigError(dotted(path[:depth + 1]) + " is not a table in the settings file")
        if isinstance(table.get(path[-1]), dict):
            raise ConfigError(dotted(path) + " is a table in the settings file, not a value")
        table[path[-1]] = copy.deepcopy(value)
    return result


def split_lines(text):
    """Split only at \\n, unlike str.splitlines, so that line ends stay as they were."""
    lines = [line + "\n" for line in text.split("\n")]
    lines[-1] = lines[-1][:-1]
    return lines if lines[-1] else lines[:-1]


def skip_space(text, index):
    while index < len(text) and text[index] in " \t":
        index += 1
    return index


def scan_key(text, index):
    """Read a dotted key that starts at index; return (parts, end), or None if there is none."""
    parts = []
    while True:
        index = skip_space(text, index)
        if index >= len(text):
            return None
        if text[index] == '"':
            end = index + 1
            while end < len(text) and text[end] != '"':
                if text[end] in "\r\n":
                    return None
                end += 2 if text[end] == "\\" else 1
            if end >= len(text):
                return None
            try:
                parts.append(tomli.loads("key = " + text[index:end + 1])["key"])
            except tomli.TOMLDecodeError:
                return None
            index = end + 1
        elif text[index] == "'":
            end = text.find("'", index + 1)
            if end < 0 or "\n" in text[index:end]:
                return None
            parts.append(text[index + 1:end])
            index = end + 1
        else:
            match = BARE_KEY.match(text, index)
            if not match:
                return None
            parts.append(match.group())
            index = match.end()
        index = skip_space(text, index)
        if index < len(text) and text[index] == ".":
            index += 1
        else:
            return tuple(parts), index


def parse_header(line):
    """Return ("table" or "array", key parts) for a table header line, or None."""
    text = line.lstrip(" \t")
    if text.startswith("[["):
        kind, start, close = "array", 2, "]]"
    elif text.startswith("["):
        kind, start, close = "table", 1, "]"
    else:
        return None
    scanned = scan_key(text, start)
    if scanned is None or not text.startswith(close, scanned[1]):
        return None
    rest = text[scanned[1] + len(close):].strip()
    if rest and not rest.startswith("#"):
        return None
    return kind, scanned[0]


def parse_assignment(line):
    """Return (key parts, index of "=") for a key/value line, or None."""
    start = skip_space(line, 0)
    if start >= len(line) or line[start] in "#[\r\n":
        return None
    scanned = scan_key(line, start)
    if scanned is None or scanned[1] >= len(line) or line[scanned[1]] != "=":
        return None
    return scanned


def find_comment(text):
    """Return the index of the comment after a one-line value, or None."""
    index = 0
    while index < len(text):
        character = text[index]
        if character == "#":
            return index
        if character == '"':
            if text.startswith('"""', index):
                return None
            index += 1
            while index < len(text) and text[index] != '"':
                index += 2 if text[index] == "\\" else 1
        elif character == "'":
            if text.startswith("'''", index):
                return None
            index = text.find("'", index + 1)
            if index < 0:
                return None
        index += 1
    return None


def find_table(lines, table):
    """Return (first, end) line indexes of a table's body, or None if it has no header."""
    headers = [(index, parse_header(line)) for index, line in enumerate(lines)]
    headers = [(index, header) for index, header in headers if header]
    if not table:
        return 0, headers[0][0] if headers else len(lines)
    for position, (index, header) in enumerate(headers):
        if header == ("table", table):
            end = headers[position + 1][0] if position + 1 < len(headers) else len(lines)
            return index + 1, end
    return None


def set_line_value(line, equals, value):
    """Replace the value after "=", keeping the key as written and any trailing comment."""
    body = line.rstrip("\r\n")
    ending = line[len(body):]
    remainder = body[equals + 1:]
    comment = find_comment(remainder)
    suffix = ""
    if comment is not None:
        before = remainder[:comment]
        suffix = (before[len(before.rstrip(" \t")):] or " ") + remainder[comment:]
    return body[:equals + 1] + " " + value + suffix + ending


def merge_text(text, leaves):
    """Set the leaves in the TOML text; other lines stay byte for byte as they were."""
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = split_lines(text)
    new_tables = {}
    for path, value in leaves:
        table, key = path[:-1], path[-1]
        formatted = format_value(value, path)
        body = find_table(lines, table)
        if body is None:
            new_tables.setdefault(table, []).append((key, formatted))
            continue
        first, end = body
        for index in range(first, end):
            assignment = parse_assignment(lines[index])
            if assignment and assignment[0] == (key,):
                lines[index] = set_line_value(lines[index], assignment[1], formatted)
                break
        else:
            # Append to the table, before the blank lines that separate it from the next.
            position = end
            while position > first and not lines[position - 1].strip():
                position -= 1
            if position > 0 and not lines[position - 1].endswith("\n"):
                lines[position - 1] += newline
            lines.insert(position, format_key(key) + " = " + formatted + newline)
    for table, entries in new_tables.items():
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += newline
        if lines and lines[-1].strip():
            lines.append(newline)
        lines.append("[" + dotted(table) + "]" + newline)
        lines.extend(format_key(key) + " = " + formatted + newline for key, formatted in entries)
    return "".join(lines)


def merge_settings(text, leaves):
    """Return the updated TOML text, or None when the file already holds the owned values."""
    document = tomli.loads(text)
    expected = apply_leaves(document, leaves)
    if same(expected, document):
        return None
    changed = [(path, value) for path, value in leaves if not same(lookup(document, path), value)]
    updated = merge_text(text, changed)
    # The line edits understand standard tables with one value per line, as Warp writes
    # them. Anything else at an owned key, such as dotted keys, inline tables or values
    # across lines, and lines inside such values elsewhere that look like keys, show up here.
    try:
        result = tomli.loads(updated)
    except tomli.TOMLDecodeError as error:
        raise ConfigError("Setting the owned keys would make the file invalid TOML ("
                          + str(error) + "); set them by hand") from None
    if not same(result, expected):
        raise ConfigError("Setting the owned keys would change other settings; set them by hand")
    return updated


def check_path(path):
    # Do not silently follow a linked settings file or directory into a repository or
    # store path; Warp writes this file itself.
    for component in (path, *path.parents):
        try:
            mode = component.lstat().st_mode
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(mode):
            raise ConfigError("Refusing a symlink in the settings path: " + str(component))
        if component == path and not stat.S_ISREG(mode):
            raise ConfigError("Settings file is not a regular file: " + str(path))
        if component != path and not stat.S_ISDIR(mode):
            raise ConfigError("Settings parent is not a directory: " + str(component))


def write_config(config_path, leaves):
    config_path = Path(os.path.abspath(config_path))
    check_path(config_path)
    original = config_path.read_bytes() if config_path.exists() else None
    updated = merge_settings(original.decode("utf-8") if original is not None else "", leaves)
    if updated is None:
        return False, None

    contents = updated.encode("utf-8")
    config_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    check_path(config_path)
    mode = stat.S_IMODE(config_path.stat().st_mode) if original is not None else 0o600
    temp_path = None
    backup_path = None
    try:
        fd, temp_name = tempfile.mkstemp(prefix=".nix-vault-warp-", dir=config_path.parent)
        temp_path = Path(temp_name)
        with os.fdopen(fd, "wb") as output:
            output.write(contents)
            output.flush()
            os.fsync(output.fileno())
            os.fchmod(output.fileno(), mode)

        # Avoid clobbering Settings edits made while the replacement was prepared.
        check_path(config_path)
        current = config_path.read_bytes() if config_path.exists() else None
        if current != original:
            raise ConfigError("Warp settings changed during sync; retry")
        if original is not None:
            timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ-")
            fd, backup_name = tempfile.mkstemp(
                prefix=config_path.name + ".nix-vault-backup-" + timestamp,
                dir=config_path.parent,
            )
            backup_path = Path(backup_name)
            with os.fdopen(fd, "wb") as backup:
                backup.write(original)
                backup.flush()
                os.fsync(backup.fileno())
        os.replace(temp_path, config_path)
    finally:
        if temp_path is not None and temp_path.exists():
            temp_path.unlink()
    return True, backup_path


def default_config():
    """Warp's settings file: ~/.warp on macOS, the warp-oss XDG directory elsewhere."""
    if sys.platform == "darwin":
        return Path.home() / ".warp/settings.toml"
    config_home = os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config"
    return Path(config_home) / "warp-oss/settings.toml"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=default_config())
    parser.add_argument("--settings", type=Path, required=True,
                        help="JSON object of the owned settings; other keys are left alone")
    parser.add_argument("--verbose", action="store_true",
                        help="also report an unchanged settings file")
    args = parser.parse_args()
    try:
        changed, backup = write_config(args.config, read_settings(args.settings))
    except (OSError, ValueError, RecursionError) as error:
        # ValueError covers ConfigError, TOMLDecodeError, JSONDecodeError and UnicodeError.
        parser.exit(1, "Warp settings sync failed: " + str(error) + "\n")
    if changed:
        print("Updated " + str(args.config))
    elif args.verbose:
        print("Already up to date: " + str(args.config))
    if backup:
        print("Backup: " + str(backup))


if __name__ == "__main__":
    main()
