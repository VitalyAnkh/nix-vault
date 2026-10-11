"""Merge the owned Karabiner profile without taking ownership of karabiner.json."""

import argparse
import copy
import datetime
import json
import math
import os
from pathlib import Path
import stat
import sys
import tempfile


MANAGED_PROFILE = "Nix Vault - Linux shortcuts"
NATIVE_PROFILE = "Nix Vault - Native"
RULE_PREFIX = "Nix Vault: "
MODIFIERS_RULE = "Nix Vault: Caps Lock and Control"
# Rules with this prefix, such as global app hotkeys, also belong to the Native profile.
SHARED_RULE_PREFIX = "Nix Vault: All profiles: "
# open_application file paths may start with this prefix. Sync resolves it against
# the home directory, so the asset itself does not depend on the user.
HOME_PREFIX = "~/"
# Maps the earlier description of a renamed owned rule to its current one. A rule
# saved under the earlier description is replaced in place and keeps its enabled
# state, as if it already had the current description.
RENAMED_RULES = {}


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


def open_applications(rules):
    """Yield the open_application objects of the rules' to events."""
    for rule in rules:
        for manipulator in rule["manipulators"]:
            events = manipulator.get("to", []) if isinstance(manipulator, dict) else None
            if not isinstance(events, list) or any(not isinstance(e, dict) for e in events):
                raise ConfigError(
                    rule["description"] + ": manipulators and their to events must be objects"
                )
            for event in events:
                function = event.get("software_function")
                if isinstance(function, dict):
                    application = function.get("open_application")
                    if isinstance(application, dict):
                        yield application


def expand_app_paths(rules, home):
    """Return a copy of the rules with ~/ file paths resolved against home."""
    home = Path(home)
    if not home.is_absolute():
        raise ConfigError("The home directory must be absolute: " + str(home))
    rules = copy.deepcopy(rules)
    for application in open_applications(rules):
        path = application.get("file_path")
        if isinstance(path, str) and path.startswith(HOME_PREFIX):
            application["file_path"] = str(home / path[len(HOME_PREFIX):])
    return rules


def missing_applications(rules):
    """Return open_application paths that do not exist; Karabiner reports nothing for them."""
    # os.path.exists reports False instead of raising, e.g. for an unreadable parent.
    return [
        application["file_path"]
        for application in open_applications(rules)
        if isinstance(application.get("file_path"), str)
        and not os.path.exists(application["file_path"])
    ]


def read_rules(path):
    asset = parse_json(path.read_bytes())
    if not isinstance(asset, dict) or not isinstance(asset.get("rules"), list):
        raise ConfigError("The rule asset must contain a rules array")
    rules = asset["rules"]
    descriptions = set()
    for rule in rules:
        if not isinstance(rule, dict):
            raise ConfigError("Each owned rule must be an object")
        description = rule.get("description", "")
        if not isinstance(description, str) or not description.startswith(RULE_PREFIX):
            raise ConfigError("Owned rule descriptions must start with " + RULE_PREFIX)
        if description in descriptions:
            raise ConfigError("Duplicate owned rule description: " + description)
        if not isinstance(rule.get("manipulators"), list) or not rule["manipulators"]:
            raise ConfigError("Each owned rule must contain manipulators")
        descriptions.add(description)
    if MODIFIERS_RULE not in descriptions:
        raise ConfigError("The rule asset must contain " + MODIFIERS_RULE)
    for application in open_applications(rules):
        path = application.get("file_path")
        # Karabiner opens the path as given; a relative path would depend on its
        # working directory. Only the current user's ~/ is expanded.
        if path is not None and not (isinstance(path, str) and path.startswith(("/", HOME_PREFIX))):
            raise ConfigError(
                "open_application file_path must be absolute or start with " + HOME_PREFIX
            )
    return rules


def merge_profile_rules(profile, rules, owned_prefix=None):
    modifications = profile.setdefault("complex_modifications", {})
    if not isinstance(modifications, dict):
        raise ConfigError(profile["name"] + ": complex_modifications must be an object")
    old_rules = modifications.get("rules", [])
    if not isinstance(old_rules, list) or any(not isinstance(r, dict) for r in old_rules):
        raise ConfigError(profile["name"] + ": rules must be an array of objects")

    remaining = {rule["description"]: copy.deepcopy(rule) for rule in rules}
    owned_names = set(remaining)
    merged_rules = []
    for rule in old_rules:
        original = rule.get("description", "")
        if not isinstance(original, str):
            merged_rules.append(rule)
            continue
        description = RENAMED_RULES.get(original, original)
        # A rule is owned under its current or its earlier description, so that a
        # rule renamed out of the owned prefix still leaves this profile.
        if description in owned_names or (
            owned_prefix
            and (description.startswith(owned_prefix) or original.startswith(owned_prefix))
        ):
            # Replace in place so a user's own rules keep their precedence. A rule
            # switched off in Karabiner Settings stays off.
            if description in remaining:
                replacement = remaining.pop(description)
                if "enabled" in rule:
                    replacement["enabled"] = rule["enabled"]
                merged_rules.append(replacement)
        else:
            merged_rules.append(rule)
    merged_rules.extend(remaining.values())
    modifications["rules"] = merged_rules


def merge_config(config, rules, select=False):
    if not isinstance(config, dict):
        raise ConfigError("Karabiner configuration must be an object")
    result = copy.deepcopy(config)
    profiles = result.setdefault("profiles", [])
    if not isinstance(profiles, list) or any(
        not isinstance(profile, dict) or not isinstance(profile.get("name"), str)
        for profile in profiles
    ):
        raise ConfigError("profiles must be an array of named profile objects")
    for name in (MANAGED_PROFILE, NATIVE_PROFILE):
        if sum(profile["name"] == name for profile in profiles) > 1:
            raise ConfigError("Duplicate reserved profile name: " + name)

    selected = next((p for p in profiles if p.get("selected")), profiles[0] if profiles else {})

    def new_profile(name, is_selected):
        profile = {"name": name, "selected": is_selected}
        # The virtual keyboard layout is a hardware choice, not a remapping.
        # Reuse the user's ANSI/ISO/JIS setup without copying other profiles' rules.
        if "virtual_hid_keyboard" in selected:
            profile["virtual_hid_keyboard"] = copy.deepcopy(selected["virtual_hid_keyboard"])
        return profile

    managed = next((p for p in profiles if p["name"] == MANAGED_PROFILE), None)
    if managed is None:
        # Existing profiles keep their selection. A new, empty configuration can
        # start with the managed profile without overriding a user's preference.
        managed = new_profile(MANAGED_PROFILE, not profiles)
        profiles.append(managed)
    merge_profile_rules(managed, rules, RULE_PREFIX)

    native = next((p for p in profiles if p["name"] == NATIVE_PROFILE), None)
    if native is None:
        native = new_profile(NATIVE_PROFILE, False)
        profiles.append(native)
    # Native disables GUI shortcut translation but keeps the user's physical
    # modifier swap and the rules shared by all profiles. It owns the swap by its
    # exact description and shared rules by their prefix, so that a shared rule
    # removed from the asset is removed here as well.
    merge_profile_rules(native, [
        r for r in rules
        if r["description"] == MODIFIERS_RULE or r["description"].startswith(SHARED_RULE_PREFIX)
    ], SHARED_RULE_PREFIX)
    if select:
        # Karabiner saves only a true `selected` flag; leave absent flags absent.
        for profile in profiles:
            if profile is managed:
                profile["selected"] = True
            elif profile.get("selected"):
                profile["selected"] = False
    return result


def check_path(path):
    # Do not silently follow a linked config file or config directory into a
    # repository/store path. Read-only rule assets may be Home Manager symlinks.
    for component in (path, *path.parents):
        try:
            mode = component.lstat().st_mode
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(mode):
            raise ConfigError("Refusing a symlink in the configuration path: " + str(component))
        if component == path and not stat.S_ISREG(mode):
            raise ConfigError("Configuration is not a regular file: " + str(path))
        if component != path and not stat.S_ISDIR(mode):
            raise ConfigError("Configuration parent is not a directory: " + str(component))


def load_rules(rules_path, home=None):
    """Read the rule asset and resolve its ~/ application paths against home."""
    return expand_app_paths(read_rules(Path(rules_path)), Path.home() if home is None else home)


def sync_config(config_path, rules_path, select=False, home=None):
    return write_config(config_path, load_rules(rules_path, home), select)


def write_config(config_path, rules, select=False):
    config_path = Path(os.path.abspath(config_path))
    check_path(config_path)
    original = config_path.read_bytes() if config_path.exists() else None
    config = parse_json(original) if original is not None else {}
    updated = merge_config(config, rules, select)
    if original is not None and updated == config:
        return False, None

    contents = (
        json.dumps(updated, ensure_ascii=False, indent=4, allow_nan=False) + "\n"
    ).encode("utf-8")
    if parse_json(contents) != updated:
        raise ConfigError("Generated configuration did not survive JSON validation")
    config_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    check_path(config_path)
    mode = stat.S_IMODE(config_path.stat().st_mode) if original is not None else 0o600
    temp_path = None
    backup_path = None
    try:
        fd, temp_name = tempfile.mkstemp(prefix=".nix-vault-karabiner-", dir=config_path.parent)
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
            raise ConfigError("Karabiner configuration changed during sync; retry")
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


def main():
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=config_home / "karabiner/karabiner.json")
    parser.add_argument("--rules", type=Path,
                        default=Path(__file__).with_name("linux-shortcuts.json"))
    parser.add_argument("--home", type=Path, default=Path.home(),
                        help="home directory for ~/ application paths"
                             " (default: the current user's)")
    parser.add_argument("--select", action="store_true", help="select the Linux shortcuts profile")
    parser.add_argument("--verbose", action="store_true",
                        help="also report an unchanged configuration")
    args = parser.parse_args()
    try:
        # Read the asset once: it may be a pipe, and the warning below must describe
        # the same rules that were written.
        rules = load_rules(args.rules, args.home)
        changed, backup = write_config(args.config, rules, args.select)
    except (OSError, ValueError, RecursionError) as error:
        # ValueError covers ConfigError, JSONDecodeError and UnicodeDecodeError.
        parser.exit(1, "Karabiner sync failed: " + str(error) + "\n")
    if changed:
        print("Updated " + str(args.config))
    elif args.verbose:
        print("Already up to date: " + str(args.config))
    if backup:
        print("Backup: " + str(backup))
    for path in missing_applications(rules):
        print("Warning: " + path + " does not exist;"
              " the shortcut that opens it does nothing until it does.", file=sys.stderr)


if __name__ == "__main__":
    main()
