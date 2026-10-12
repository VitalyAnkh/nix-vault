"""Policy and isolated filesystem tests; these do not simulate the macOS HID driver."""

import copy
import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


MODULE_DIR = Path(__file__).resolve().parent
RULES_PATH = MODULE_DIR / "linux-shortcuts.json"
SPEC = importlib.util.spec_from_file_location("karabiner_sync", MODULE_DIR / "sync.py")
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)
ASSET = json.loads(RULES_PATH.read_text())
RULES = {rule["description"]: rule for rule in ASSET["rules"]}
WARP_RULE = "Nix Vault: Warp clipboard and input undo"
EMACS_RULE = "Nix Vault: All profiles: Emacs global hotkey"
COMMAND_OPTION_RULE = "Nix Vault: All profiles: Command and Option on the built-in keyboard"
GUI_APPS = (
    "com.apple.finder", "com.apple.Safari", "com.google.Chrome",
    "com.microsoft.edgemac", "com.apple.TextEdit", "com.apple.Preview",
    "com.apple.Notes", "com.apple.mail", "com.electron.lark",
    "ru.keepcoder.Telegram", "com.tencent.xinWeChat",
    "com.kingsoft.wpsoffice.mac", "md.obsidian",
)
GUI_KEYS = "cvxzasfwtnop"
WARP = "dev.warp.Warp-Stable"
EMACS = "org.gnu.Emacs"
EMACS_APP = "~/Applications/Home Manager Apps/Emacs.app"
OPEN_EMACS = ("open_application", frozenset({("file_path", EMACS_APP)}))
# Emacs binds s-h (Command+H) to ns-do-hide-emacs by default.
HIDE_EMACS = ("h", frozenset({"command"}))
# Astra's macOS settings for the built-in keyboard, on both sides: the key next to the
# space bar becomes Option, like Alt on a PC keyboard, and Option becomes Command.
COMMAND_OPTION_SWAP = (
    ("left_command", "left_option"), ("left_option", "left_command"),
    ("right_command", "right_option"), ("right_option", "right_command"),
)
# Device properties that device_if matches, as `karabiner_cli --list-connected-devices`
# reports them. The MacBook keyboard has no vendor or product ID.
BUILT_IN_KEYBOARD = {"is_keyboard": True, "is_built_in_keyboard": True}
EXTERNAL_KEYBOARD = {"is_keyboard": True, "vendor_id": 3141, "product_id": 32790}
KEYBOARDS = (BUILT_IN_KEYBOARD, EXTERNAL_KEYBOARD)
POINTING_DEVICE = {"is_pointing_device": True, "vendor_id": 1133, "product_id": 45108}


def modifier_family(modifier):
    return re.sub(r"^(left|right)_", "", modifier)


def device_matches(identifiers, device):
    # Every key of an identifier must match; any one identifier is sufficient.
    return any(all(device.get(key, False) == value for key, value in identifier.items())
               for identifier in identifiers)


def apply_rule(bundle, key, modifiers, device=EXTERNAL_KEYBOARD, rules=None):
    """Evaluate the exact basic/app/device/modifier subset used in the shipped asset."""
    modifiers = {modifier_family(m) for m in modifiers}
    for rule in ASSET["rules"] if rules is None else rules:
        if not rule.get("enabled", True):
            continue  # switched off in Karabiner Settings
        for manipulator in rule["manipulators"]:
            source = manipulator["from"]
            if source["key_code"] != key:
                continue
            mandatory = set(source["modifiers"].get("mandatory", []))
            optional = set(source["modifiers"]["optional"])
            if not mandatory <= modifiers or (
                "any" not in optional and not modifiers <= mandatory | optional
            ):
                continue
            if not all(
                (any(re.search(pattern, bundle) for pattern in condition["bundle_identifiers"])
                 if condition["type"] == "frontmost_application_if" else
                 device_matches(condition["identifiers"], device))
                for condition in manipulator.get("conditions", [])
            ):
                continue
            destination = manipulator["to"][0]
            if "software_function" in destination:
                # Karabiner consumes the key and runs the function on key_down.
                (function, arguments), = destination["software_function"].items()
                return function, frozenset(arguments.items())
            output_modifiers = {modifier_family(m) for m in destination.get("modifiers", [])}
            return destination["key_code"], frozenset((modifiers - mandatory) | output_modifiers)
    return key, frozenset(modifiers)


class ShortcutTests(unittest.TestCase):
    def test_supported_rule_shape_and_explicit_conditions(self):
        # No rule ships switched off: sync keeps an asset's "enabled": false.
        for rule in ASSET["rules"]:
            self.assertEqual(set(rule), {"description", "manipulators"})
        manipulators = [m for r in ASSET["rules"] if r["description"] != EMACS_RULE
                        for m in r["manipulators"]]
        self.assertEqual(len(manipulators), 23)
        # The physical modifier exchanges and the devices that they apply to.
        exchanges = {
            **dict.fromkeys(("caps_lock", "left_control"), {"is_keyboard": True}),
            **dict.fromkeys(dict(COMMAND_OPTION_SWAP), {"is_built_in_keyboard": True}),
        }
        for manipulator in manipulators:
            self.assertEqual(set(manipulator), {"type", "from", "to", "conditions"})
            self.assertEqual(manipulator["type"], "basic")
            self.assertEqual(len(manipulator["to"]), 1)
            self.assertEqual(len(manipulator["conditions"]), 1)
            condition = manipulator["conditions"][0]
            if manipulator["from"]["key_code"] in exchanges:
                self.assertEqual(manipulator["from"]["modifiers"], {"optional": ["any"]})
                # A plain key: the resulting modifier is held as long as the physical key.
                self.assertEqual(set(manipulator["to"][0]), {"key_code"})
                self.assertEqual(condition, {
                    "type": "device_if",
                    "identifiers": [exchanges[manipulator["from"]["key_code"]]],
                })
                continue
            self.assertEqual(manipulator["from"]["modifiers"]["optional"], ["caps_lock"])
            self.assertEqual(condition["type"], "frontmost_application_if")
            for pattern in condition["bundle_identifiers"]:
                self.assertTrue(pattern.startswith("^") and pattern.endswith("$"))
                re.compile(pattern)

    def test_emacs_hotkey_hides_frontmost_emacs_and_otherwise_opens_it(self):
        chord = {"key_code": "q", "modifiers": {"mandatory": ["control", "shift"],
                                                "optional": ["caps_lock"]}}
        # Karabiner uses the first matching manipulator, so the conditional hide comes first.
        self.assertEqual(RULES[EMACS_RULE]["manipulators"], [
            {
                "type": "basic",
                "from": chord,
                "to": [{"key_code": "h", "modifiers": ["left_command"], "repeat": False}],
                "conditions": [{"type": "frontmost_application_if",
                                "bundle_identifiers": ["^" + re.escape(EMACS) + "$"]}],
            },
            {
                "type": "basic",
                "from": chord,
                "to": [{"software_function": {"open_application": {"file_path": EMACS_APP}}}],
            },
        ])

    def test_emacs_hotkey_in_every_app_with_either_side_and_caps_lock(self):
        apps = GUI_APPS + (WARP, "net.kovidgoyal.kitty", "dev.zed.Zed", "com.microsoft.VSCode",
                           "org.alacritty", "com.apple.ScreenSharing", "some.other.app")
        for app, control, shift, caps in itertools.product(
            apps + (EMACS,), ("left_control", "right_control"), ("left_shift", "right_shift"),
            ((), ("caps_lock",)),
        ):
            with self.subTest(app=app, control=control, shift=shift, caps=caps):
                expected = ((HIDE_EMACS[0], HIDE_EMACS[1] | set(caps)) if app == EMACS
                            else OPEN_EMACS)
                self.assertEqual(apply_rule(app, "q", (control, shift) + caps), expected)

    def test_only_emacs_itself_is_hidden(self):
        for app in ("other." + EMACS, EMACS + ".other", EMACS.replace(".", "-"),
                    "org.gnu.EmacsMac"):
            self.assertEqual(apply_rule(app, "q", ("control", "shift")), OPEN_EMACS)

    def test_other_q_combinations_pass_through(self):
        # Including macOS's Lock Screen (Control+Command+Q) and Log Out (Shift+Command+Q).
        for app, modifiers in itertools.product(
            ("com.apple.TextEdit", WARP, EMACS),
            ((), ("control",), ("shift",), ("command",), ("control", "command"),
             ("shift", "command"), ("option", "shift", "command"), ("control", "shift", "option"),
             ("control", "shift", "command"), ("control", "shift", "fn"), ("caps_lock", "shift")),
        ):
            self.assertEqual(apply_rule(app, "q", modifiers), ("q", frozenset(modifiers)))

    def test_gui_manipulators_share_one_allowlist(self):
        # The JSON repeats the allowlist per manipulator; keep every copy identical.
        rule = next(r for r in ASSET["rules"]
                    if r["description"] == "Nix Vault: GUI Linux shortcuts")
        for manipulator in rule["manipulators"]:
            self.assertEqual(manipulator["conditions"], [{
                "type": "frontmost_application_if",
                "bundle_identifiers": ["^" + re.escape(app) + "$" for app in GUI_APPS],
            }])

    def test_all_gui_shortcuts_both_control_sides_and_caps_lock(self):
        for app, key, control, caps in itertools.product(
            GUI_APPS, GUI_KEYS, ("left_control", "right_control"), ((), ("caps_lock",))
        ):
            with self.subTest(app=app, key=key, control=control, caps=caps):
                self.assertEqual(
                    apply_rule(app, key, (control,) + caps),
                    (key, frozenset(("command",) + caps)),
                )

    def test_gui_redo(self):
        for app, control, shift in itertools.product(
            GUI_APPS, ("left_control", "right_control"), ("left_shift", "right_shift")
        ):
            self.assertEqual(
                apply_rule(app, "z", (control, shift)),
                ("z", frozenset(("command", "shift"))),
            )

    def test_other_gui_combinations_pass_through(self):
        for app, key, modifiers in itertools.product(
            GUI_APPS,
            GUI_KEYS + "qey",
            (("command",), ("control", "option"), ("control", "command"),
             ("control", "fn"), ("control", "shift", "option")),
        ):
            self.assertEqual(apply_rule(app, key, modifiers), (key, frozenset(modifiers)))
        for app, key in itertools.product(GUI_APPS, GUI_KEYS.replace("z", "")):
            self.assertEqual(
                apply_rule(app, key, ("control", "shift")),
                (key, frozenset(("control", "shift"))),
            )

    def test_warp_copy_paste_undo_redo(self):
        expected = {
            "c": ("c", frozenset(("command",))),
            "v": ("v", frozenset(("command",))),
            "z": ("z", frozenset(("command",))),
            "y": ("z", frozenset(("command", "shift"))),
        }
        for key, result in expected.items():
            for control, shift in itertools.product(
                ("left_control", "right_control"), ("left_shift", "right_shift")
            ):
                self.assertEqual(apply_rule(WARP, key, (control, shift)), result)
                self.assertEqual(
                    apply_rule(WARP, key, (control, shift, "caps_lock")),
                    (result[0], result[1] | {"caps_lock"}),
                )

    def test_warp_terminal_controls_and_extra_modifiers_pass_through(self):
        for key, modifiers in itertools.product(
            "abcdefghijklmnopqrstuvwxyz",
            (("control",), ("control", "caps_lock"), ("option",), ("command",),
             ("control", "shift", "option"), ("control", "shift", "command"),
             ("control", "shift", "fn")),
        ):
            self.assertEqual(apply_rule(WARP, key, modifiers), (key, frozenset(modifiers)))

    def test_editors_terminals_ssh_and_remote_desktop_are_excluded(self):
        excluded = (
            "org.gnu.Emacs", "org.gnu.EmacsMac", "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders", "dev.zed.Zed", "com.openai.codex",
            "com.apple.Terminal", "com.googlecode.iterm2", "net.kovidgoyal.kitty",
            "com.mitchellh.ghostty", "org.alacritty", "com.termius-dmg.mac",
            "com.vandyke.SecureCRT", "com.microsoft.rdc.macos",
            "com.microsoft.windowsapp", "com.teamviewer.TeamViewer",
            "com.anydesk.Anydesk", "dev.warp.Warp-Preview", "some.other.app",
        )
        for app, key, modifiers in itertools.product(
            excluded, GUI_KEYS + "ey", (("control",), ("control", "shift"))
        ):
            self.assertEqual(apply_rule(app, key, modifiers), (key, frozenset(modifiers)))

    def test_bundle_patterns_do_not_match_prefixes_suffixes_or_unescaped_dots(self):
        for app in GUI_APPS + (WARP,):
            for wrong in ("other." + app, app + ".other", app.replace(".", "-")):
                for modifiers in (("control",), ("control", "shift")):
                    self.assertEqual(apply_rule(wrong, "c", modifiers), ("c", frozenset(modifiers)))

    def test_every_keyboard_swaps_caps_and_left_control_only(self):
        for device in KEYBOARDS:
            for source, target in (("caps_lock", "left_control"), ("left_control", "caps_lock")):
                for modifiers in ((), ("shift",), ("command", "option"), ("shift", "control")):
                    with self.subTest(device=device, source=source, modifiers=modifiers):
                        self.assertEqual(apply_rule(WARP, source, modifiers, device),
                                         (target, frozenset(modifiers)))
            self.assertEqual(apply_rule(WARP, "right_control", (), device),
                             ("right_control", frozenset()))

    def test_devices_that_are_not_keyboards_keep_caps_lock_and_control(self):
        for source in ("caps_lock", "left_control"):
            self.assertEqual(apply_rule(WARP, source, (), POINTING_DEVICE), (source, frozenset()))

    def test_swapped_caps_feeds_gui_shortcuts_and_control_combinations(self):
        # Modifier output updates Karabiner's modifier state before the next key;
        # generated modifier events are not recursively remapped in this stage.
        for device in KEYBOARDS:
            control, _ = apply_rule("com.apple.TextEdit", "caps_lock", (), device)
            self.assertEqual(control, "left_control")
            self.assertEqual(apply_rule("com.apple.TextEdit", "c", (control,), device),
                             ("c", frozenset(("command",))))
            self.assertEqual(apply_rule(WARP, "z", (control,), device),
                             ("z", frozenset(("control",))))
            # Control+Shift+8 (previous input source) and Warp's Control+Shift+E stay
            # Control combinations instead of Caps Lock followed by Shift+8, i.e. `*`.
            for app in ("com.apple.TextEdit", WARP):
                self.assertEqual(apply_rule(app, "8", (control, "shift"), device),
                                 ("8", frozenset(("control", "shift"))))
            self.assertEqual(apply_rule(WARP, "e", (control, "shift"), device),
                             ("e", frozenset(("control", "shift"))))
            # Physical Caps Lock+Shift+Q toggles Emacs; physical left Control is Caps Lock.
            self.assertEqual(apply_rule(WARP, "q", (control, "shift"), device), OPEN_EMACS)
            self.assertEqual(apply_rule(EMACS, "q", (control, "shift"), device), HIDE_EMACS)
            caps, _ = apply_rule(WARP, "left_control", (), device)
            self.assertEqual(apply_rule(WARP, "q", (caps, "shift"), device),
                             ("q", frozenset(("caps_lock", "shift"))))

    def test_built_in_keyboard_swaps_command_and_option_on_both_sides(self):
        for app, (source, target), modifiers in itertools.product(
            ("com.apple.TextEdit", WARP, EMACS, "some.other.app"), COMMAND_OPTION_SWAP,
            ((), ("shift",), ("control", "shift"), ("caps_lock",), ("command",), ("option",),
             ("fn",)),
        ):
            with self.subTest(app=app, source=source, modifiers=modifiers):
                self.assertEqual(apply_rule(app, source, modifiers, BUILT_IN_KEYBOARD),
                                 (target, frozenset(modifiers)))
        for key in ("fn", "left_shift", "right_shift", "right_control"):
            self.assertEqual(apply_rule(WARP, key, (), BUILT_IN_KEYBOARD), (key, frozenset()))

    def test_external_keyboards_and_other_devices_keep_command_and_option(self):
        # A PC-layout keyboard already has Option (Alt) next to the space bar.
        for device, (source, _), modifiers in itertools.product(
            (EXTERNAL_KEYBOARD, POINTING_DEVICE), COMMAND_OPTION_SWAP,
            ((), ("shift",), ("control", "shift"), ("command",), ("option",)),
        ):
            with self.subTest(device=device, source=source, modifiers=modifiers):
                self.assertEqual(apply_rule(EMACS, source, modifiers, device),
                                 (source, frozenset(modifiers)))

    def test_swapped_command_and_option_feed_emacs_meta_and_the_other_rules(self):
        # As for Caps Lock, the following keys see the resulting modifiers.
        meta, _ = apply_rule(EMACS, "left_command", (), BUILT_IN_KEYBOARD)
        command, _ = apply_rule(EMACS, "left_option", (), BUILT_IN_KEYBOARD)
        control, _ = apply_rule(EMACS, "caps_lock", (), BUILT_IN_KEYBOARD)
        self.assertEqual((meta, command, control), ("left_option", "left_command", "left_control"))
        # In Doom Emacs, left Option is Meta: M-o, M-., M-, and M-x use the left key next to
        # the space bar. The physical Option key gives Command, which Emacs reads as Super.
        for key in ("o", "period", "comma", "x"):
            self.assertEqual(apply_rule(EMACS, key, (meta,), BUILT_IN_KEYBOARD),
                             (key, frozenset(("option",))))
        self.assertEqual(apply_rule(EMACS, "h", (command,), BUILT_IN_KEYBOARD),
                         ("h", frozenset(("command",))))
        # An external keyboard's own Option key stays Meta.
        external_meta, _ = apply_rule(EMACS, "left_option", (), EXTERNAL_KEYBOARD)
        self.assertEqual(apply_rule(EMACS, "o", (external_meta,), EXTERNAL_KEYBOARD),
                         ("o", frozenset(("option",))))
        # Command shortcuts move to the physical Option key; the physical Command key
        # gives Option, so Command+C there is Option+C.
        app = "com.apple.TextEdit"
        self.assertEqual(apply_rule(app, "c", (command,), BUILT_IN_KEYBOARD),
                         ("c", frozenset(("command",))))
        self.assertEqual(apply_rule(app, "c", (meta,), BUILT_IN_KEYBOARD),
                         ("c", frozenset(("option",))))
        # GUI shortcuts and the Emacs hotkey use physical Caps Lock and do not absorb an
        # extra Option or Command.
        self.assertEqual(apply_rule(app, "c", (control,), BUILT_IN_KEYBOARD),
                         ("c", frozenset(("command",))))
        for extra in (meta, command):
            with self.subTest(extra=extra):
                family = modifier_family(extra)
                self.assertEqual(apply_rule(app, "c", (control, extra), BUILT_IN_KEYBOARD),
                                 ("c", frozenset(("control", family))))
                self.assertEqual(apply_rule(WARP, "q", (control, "shift", extra),
                                            BUILT_IN_KEYBOARD),
                                 ("q", frozenset(("control", "shift", family))))
        self.assertEqual(apply_rule(WARP, "q", (control, "shift"), BUILT_IN_KEYBOARD), OPEN_EMACS)
        self.assertEqual(apply_rule(EMACS, "q", (control, "shift"), BUILT_IN_KEYBOARD), HIDE_EMACS)
        # Warp keeps Meta and its explicit shortcuts.
        self.assertEqual(apply_rule(WARP, "b", (meta,), BUILT_IN_KEYBOARD),
                         ("b", frozenset(("option",))))
        self.assertEqual(apply_rule(WARP, "c", (control, "shift"), BUILT_IN_KEYBOARD),
                         ("c", frozenset(("command",))))
        # Lock Screen (Control+Command+Q) is physical Caps Lock+Option+Q and passes through.
        self.assertEqual(apply_rule(WARP, "q", (control, command), BUILT_IN_KEYBOARD),
                         ("q", frozenset(("control", "command"))))


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        # /var on macOS is itself a symlink, unrelated to the target under test.
        self.base = Path(self.temp.name).resolve()
        self.config = self.base / "karabiner" / "karabiner.json"
        self.home = self.base / "home"
        # The rules as sync writes them, with ~/ resolved against self.home.
        self.rules = {rule["description"]: rule
                      for rule in sync.expand_app_paths(ASSET["rules"], self.home)}
        self.emacs = str(self.home / "Applications/Home Manager Apps/Emacs.app")

    def write(self, value):
        self.config.parent.mkdir(parents=True, exist_ok=True)
        self.config.write_text(json.dumps(value, ensure_ascii=False))

    def read(self):
        return json.loads(self.config.read_text())

    def apply(self, select=False):
        return sync.sync_config(self.config, RULES_PATH, select, self.home)

    def profile(self, name):
        return next(p for p in self.read()["profiles"] if p["name"] == name)

    def test_first_run_creates_regular_file_and_native_with_swap_and_shared_rules(self):
        self.assertEqual(self.apply(), (True, None))
        self.assertTrue(self.config.is_file())
        self.assertFalse(self.config.is_symlink())
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        self.assertTrue(self.profile(sync.MANAGED_PROFILE)["selected"])
        native = self.profile(sync.NATIVE_PROFILE)
        # Omitted keys use Karabiner's defaults: no simple, device or fn remappings.
        self.assertEqual(native, {
            "name": sync.NATIVE_PROFILE, "selected": False,
            "complex_modifications": {"rules": [self.rules[sync.MODIFIERS_RULE],
                                                self.rules[COMMAND_OPTION_RULE],
                                                self.rules[EMACS_RULE]]},
        })
        native_rules = native["complex_modifications"]["rules"]
        self.assertEqual(apply_rule("com.apple.TextEdit", "c", ("control",), rules=native_rules),
                         ("c", frozenset(("control",))))
        for device in KEYBOARDS:
            self.assertEqual(apply_rule("com.apple.TextEdit", "caps_lock", (), device,
                                        rules=native_rules),
                             ("left_control", frozenset()))
        # The Emacs hotkey works in both profiles, with the path made absolute.
        open_emacs = ("open_application", frozenset({("file_path", self.emacs)}))
        for profile in (sync.MANAGED_PROFILE, sync.NATIVE_PROFILE):
            rules = self.profile(profile)["complex_modifications"]["rules"]
            self.assertEqual(apply_rule("com.apple.TextEdit", "q", ("control", "shift"),
                                        rules=rules),
                             open_emacs)
            self.assertEqual(apply_rule(EMACS, "q", ("control", "shift"), rules=rules), HIDE_EMACS)
            # Both profiles exchange Command and Option on the built-in keyboard only.
            for source, target in COMMAND_OPTION_SWAP:
                self.assertEqual(apply_rule(EMACS, source, (), BUILT_IN_KEYBOARD, rules=rules),
                                 (target, frozenset()))
                self.assertEqual(apply_rule(EMACS, source, (), EXTERNAL_KEYBOARD, rules=rules),
                                 (source, frozenset()))

    def test_existing_profiles_global_settings_and_devices_are_preserved(self):
        old_profile = {
            "name": "Personal", "selected": True,
            "devices": [{"identifiers": {"vendor_id": 123}, "ignore": True}],
            "simple_modifications": [{"from": {"key_code": "a"}, "to": [{"key_code": "b"}]}],
            "virtual_hid_keyboard": {"keyboard_type_v2": "iso"},
        }
        original = {"global": {"show_in_menu_bar": False}, "profiles": [old_profile], "other": 42}
        self.write(original)
        changed, backup = self.apply()
        self.assertTrue(changed)
        self.assertEqual(json.loads(backup.read_text()), original)
        self.assertEqual(self.read()["global"], original["global"])
        self.assertEqual(self.read()["other"], 42)
        self.assertEqual(self.read()["profiles"][0], old_profile)
        self.assertFalse(self.profile(sync.MANAGED_PROFILE)["selected"])

    def test_new_profiles_inherit_selected_hardware_layout_without_remappings(self):
        self.write({"profiles": [
            {"name": "Other", "selected": False,
             "virtual_hid_keyboard": {"keyboard_type_v2": "ansi"}},
            {"name": "Current", "selected": True,
             "virtual_hid_keyboard": {"keyboard_type_v2": "iso", "country_code": 0},
             "simple_modifications": [{"from": {"key_code": "a"}, "to": [{"key_code": "b"}]}]},
        ]})
        self.apply(select=True)
        for name in (sync.MANAGED_PROFILE, sync.NATIVE_PROFILE):
            profile = self.profile(name)
            self.assertEqual(profile["virtual_hid_keyboard"],
                             {"keyboard_type_v2": "iso", "country_code": 0})
            self.assertEqual(profile.get("simple_modifications", []), [])

    def test_sync_updates_owned_rules_and_preserves_user_rule_order_and_settings(self):
        before = {"description": "My first rule", "manipulators": []}
        after = {"description": "My second rule", "manipulators": []}
        owned = copy.deepcopy(ASSET["rules"][0])
        owned["manipulators"] = []
        original = {"profiles": [{
            "name": sync.MANAGED_PROFILE, "selected": True, "devices": [{"ignore": True}],
            "simple_modifications": [], "virtual_hid_keyboard": {"keyboard_type_v2": "iso"},
            "complex_modifications": {
                "parameters": {"basic.to_if_alone_timeout_milliseconds": 250},
                "rules": [before, owned, after, {"description": sync.RULE_PREFIX + "retired"}],
            },
        }]}
        saved = copy.deepcopy(original)
        updated = sync.merge_config(original, ASSET["rules"])
        self.assertEqual(original, saved)
        managed = updated["profiles"][0]
        self.assertEqual(managed["devices"], original["profiles"][0]["devices"])
        self.assertEqual(managed["virtual_hid_keyboard"], {"keyboard_type_v2": "iso"})
        self.assertEqual(managed["complex_modifications"]["parameters"],
                         original["profiles"][0]["complex_modifications"]["parameters"])
        self.assertEqual(managed["complex_modifications"]["rules"],
                         [before, ASSET["rules"][0], after, *ASSET["rules"][1:]])

    def test_native_updates_only_owned_rules_and_preserves_user_rules_and_devices(self):
        user_rule = {"description": "My native rule", "manipulators": []}
        unrelated_owned = {"description": sync.RULE_PREFIX + "My separate native customization"}
        old_swap = {"description": sync.MODIFIERS_RULE, "manipulators": []}
        devices = [{"identifiers": {"is_keyboard": True},
                    "simple_modifications": [{"from": {"key_code": "f1"},
                                              "to": [{"key_code": "f2"}]}]}]
        self.write({"profiles": [{
            "name": sync.NATIVE_PROFILE, "selected": True, "devices": devices,
            "virtual_hid_keyboard": {"keyboard_type_v2": "iso"},
            "complex_modifications": {"parameters": {"custom": 123},
                                      "rules": [user_rule, old_swap, unrelated_owned]},
        }]})
        self.apply()
        native = self.profile(sync.NATIVE_PROFILE)
        self.assertTrue(native["selected"])
        self.assertEqual(native["devices"], devices)
        self.assertEqual(native["virtual_hid_keyboard"], {"keyboard_type_v2": "iso"})
        self.assertEqual(native["complex_modifications"]["parameters"], {"custom": 123})
        self.assertEqual(native["complex_modifications"]["rules"],
                         [user_rule, self.rules[sync.MODIFIERS_RULE], unrelated_owned,
                          self.rules[COMMAND_OPTION_RULE], self.rules[EMACS_RULE]])
        self.assertEqual(self.apply(), (False, None))

    def test_renamed_swap_rule_is_replaced_in_place_and_keeps_its_state(self):
        old_name = sync.RULE_PREFIX + "Old swap"
        swap = RULES[sync.MODIFIERS_RULE]
        user_rule = {"description": "My rule", "manipulators": []}
        self.write({"profiles": [
            {"name": sync.MANAGED_PROFILE, "selected": True, "complex_modifications": {
                "rules": [{"description": old_name, "manipulators": []}, user_rule]}},
            {"name": sync.NATIVE_PROFILE, "complex_modifications": {
                "rules": [user_rule, {"description": old_name, "enabled": False,
                                      "manipulators": []}, swap]}},
        ]})
        with mock.patch.dict(sync.RENAMED_RULES, {old_name: sync.MODIFIERS_RULE}):
            self.apply()
        self.assertEqual(self.profile(sync.MANAGED_PROFILE)["complex_modifications"]["rules"],
                         [swap, user_rule, *(r for name, r in self.rules.items()
                                             if name != sync.MODIFIERS_RULE)])
        # A duplicate under the current description is dropped.
        self.assertEqual(self.profile(sync.NATIVE_PROFILE)["complex_modifications"]["rules"],
                         [user_rule, {**swap, "enabled": False}, self.rules[COMMAND_OPTION_RULE],
                          self.rules[EMACS_RULE]])
        self.assertEqual(self.apply(), (False, None))

    def test_shared_rule_removed_from_the_asset_is_retired_from_both_profiles(self):
        user_rule = {"description": "My rule", "manipulators": []}
        own_owned = {"description": sync.RULE_PREFIX + "My separate native customization"}
        self.write({"profiles": [{"name": sync.NATIVE_PROFILE,
                                  "complex_modifications": {"rules": [user_rule, own_owned]}}]})
        self.apply()
        smaller = self.base / "rules.json"
        smaller.write_text(json.dumps({"rules": [r for r in ASSET["rules"]
                                                 if r["description"] != EMACS_RULE]}))
        self.assertTrue(sync.sync_config(self.config, smaller, home=self.home)[0])
        for profile in (sync.MANAGED_PROFILE, sync.NATIVE_PROFILE):
            descriptions = [r.get("description") for r in
                            self.profile(profile)["complex_modifications"]["rules"]]
            self.assertNotIn(EMACS_RULE, descriptions)
        self.assertEqual(self.profile(sync.NATIVE_PROFILE)["complex_modifications"]["rules"],
                         [user_rule, own_owned, self.rules[sync.MODIFIERS_RULE],
                          self.rules[COMMAND_OPTION_RULE]])

    def test_shared_rule_renamed_out_of_the_shared_prefix_leaves_native(self):
        self.apply()
        renamed = sync.RULE_PREFIX + "Emacs global hotkey"
        asset = copy.deepcopy(ASSET)
        next(r for r in asset["rules"] if r["description"] == EMACS_RULE)["description"] = renamed
        rules_path = self.base / "rules.json"
        rules_path.write_text(json.dumps(asset))
        with mock.patch.dict(sync.RENAMED_RULES, {EMACS_RULE: renamed}):
            self.assertTrue(sync.sync_config(self.config, rules_path, home=self.home)[0])
        managed = [r["description"] for r in
                   self.profile(sync.MANAGED_PROFILE)["complex_modifications"]["rules"]]
        native = [r["description"] for r in
                  self.profile(sync.NATIVE_PROFILE)["complex_modifications"]["rules"]]
        self.assertIn(renamed, managed)
        self.assertNotIn(EMACS_RULE, managed)
        self.assertEqual(native, [sync.MODIFIERS_RULE, COMMAND_OPTION_RULE])

    def test_new_shared_rule_is_appended_to_both_existing_profiles(self):
        # An existing configuration, synchronized from an asset without the rule.
        older = self.base / "rules.json"
        older.write_text(json.dumps({"rules": [r for r in ASSET["rules"]
                                               if r["description"] != COMMAND_OPTION_RULE]}))
        self.assertTrue(sync.sync_config(self.config, older, home=self.home)[0])
        changed, backup = self.apply()
        self.assertTrue(changed)
        self.assertIsNotNone(backup)
        swap = self.rules[COMMAND_OPTION_RULE]
        self.assertEqual(self.profile(sync.MANAGED_PROFILE)["complex_modifications"]["rules"],
                         [*(r for name, r in self.rules.items() if name != COMMAND_OPTION_RULE),
                          swap])
        self.assertEqual(self.profile(sync.NATIVE_PROFILE)["complex_modifications"]["rules"],
                         [self.rules[sync.MODIFIERS_RULE], self.rules[EMACS_RULE], swap])
        # It then stays in place.
        self.assertEqual(self.apply(), (False, None))

    def test_shared_rule_switched_off_in_one_profile_stays_off_there(self):
        self.apply()
        value = self.read()
        native = next(p for p in value["profiles"] if p["name"] == sync.NATIVE_PROFILE)
        hotkey = next(r for r in native["complex_modifications"]["rules"]
                      if r["description"] == EMACS_RULE)
        hotkey["enabled"] = False
        hotkey["manipulators"] = []  # an outdated copy of the owned rule
        self.write(value)
        self.assertTrue(self.apply()[0])
        self.assertIn({**self.rules[EMACS_RULE], "enabled": False},
                      self.profile(sync.NATIVE_PROFILE)["complex_modifications"]["rules"])
        self.assertIn(self.rules[EMACS_RULE],
                      self.profile(sync.MANAGED_PROFILE)["complex_modifications"]["rules"])
        native_rules = self.profile(sync.NATIVE_PROFILE)["complex_modifications"]["rules"]
        self.assertEqual(apply_rule(WARP, "q", ("control", "shift"), rules=native_rules),
                         ("q", frozenset(("control", "shift"))))
        self.assertEqual(self.apply(), (False, None))

    def test_application_paths_must_be_absolute_or_in_home(self):
        for path in ("Applications/Emacs.app", "~user/Applications/Emacs.app", "~", "", 42):
            with self.subTest(path=path):
                asset = copy.deepcopy(ASSET)
                hotkey = next(r for r in asset["rules"] if r["description"] == EMACS_RULE)
                hotkey["manipulators"][1]["to"][0]["software_function"]["open_application"][
                    "file_path"] = path
                bad = self.base / "rules.json"
                bad.write_text(json.dumps(asset))
                with self.assertRaisesRegex(sync.ConfigError, "file_path"):
                    sync.sync_config(self.config, bad, home=self.home)
                self.assertFalse(self.config.exists())
        with self.assertRaisesRegex(sync.ConfigError, "absolute"):
            sync.sync_config(self.config, RULES_PATH, home=Path("relative/home"))
        self.assertFalse(self.config.exists())
        absolute = [{"description": "x", "manipulators": [
            {"to": [{"software_function": {
                "open_application": {"file_path": "/Applications/A.app"}}}]},
        ]}]
        self.assertEqual(sync.expand_app_paths(absolute, self.home), absolute)

    def test_missing_applications_lists_only_absent_targets(self):
        rules = list(self.rules.values())
        self.assertEqual(sync.missing_applications(rules), [self.emacs])
        Path(self.emacs).mkdir(parents=True)
        self.assertEqual(sync.missing_applications(rules), [])

    def test_unchanged_config_keeps_bytes_inode_mtime_and_has_no_backup(self):
        self.apply()
        original = self.config.read_bytes()
        before = self.config.stat()
        self.assertEqual(self.apply(), (False, None))
        after = self.config.stat()
        self.assertEqual(self.config.read_bytes(), original)
        self.assertEqual((before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns))
        self.assertEqual(list(self.config.parent.glob("*.nix-vault-backup-*")), [])

    def test_backup_is_byte_exact_and_output_preserves_file_mode(self):
        self.write({"global": {"show_in_menu_bar": True}, "profiles": []})
        original = b'{ "global": {"show_in_menu_bar": true}, "profiles": [] }\n\n'
        self.config.write_bytes(original)
        self.config.chmod(0o640)
        _, backup = self.apply()
        self.assertEqual(backup.read_bytes(), original)
        self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o640)

    def test_select_is_explicit_and_later_sync_preserves_native_selection(self):
        self.write({"profiles": [{"name": "Personal", "selected": True}]})
        self.apply(select=True)
        self.assertEqual([p["name"] for p in self.read()["profiles"] if p["selected"]],
                         [sync.MANAGED_PROFILE])
        value = self.read()
        for profile in value["profiles"]:
            profile["selected"] = profile["name"] == sync.NATIVE_PROFILE
        self.write(value)
        self.assertEqual(self.apply(), (False, None))
        self.assertTrue(self.profile(sync.NATIVE_PROFILE)["selected"])

    def test_select_is_idempotent_for_a_file_rewritten_by_karabiner(self):
        # Karabiner saves only `"selected": true` and drops keys left at their defaults.
        self.apply(select=True)
        value = self.read()
        for profile in value["profiles"]:
            if not profile["selected"]:
                del profile["selected"]
        self.write(value)
        self.assertEqual(self.apply(select=True), (False, None))
        self.assertEqual(list(self.config.parent.glob("*.nix-vault-backup-*")), [])

    def test_rule_switched_off_in_settings_stays_off_across_updates(self):
        self.apply()
        value = self.read()
        managed = next(p for p in value["profiles"] if p["name"] == sync.MANAGED_PROFILE)
        warp = next(r for r in managed["complex_modifications"]["rules"]
                    if r["description"] == WARP_RULE)
        warp["enabled"] = False
        warp["manipulators"] = []  # an outdated copy of the owned rule
        self.write(value)
        self.assertTrue(self.apply()[0])
        rules = self.profile(sync.MANAGED_PROFILE)["complex_modifications"]["rules"]
        warp = next(r for r in rules if r["description"] == WARP_RULE)
        self.assertEqual(warp, {**RULES[WARP_RULE], "enabled": False})
        self.assertEqual(self.apply(), (False, None))

    def test_invalid_json_and_profile_shapes_are_not_replaced(self):
        invalid = (b"{", b"[]", b'{"profiles": {}}', b'{"profiles": [null]}',
                   b'{"profiles": [], "profiles": []}', b'{"value": NaN}',
                   json.dumps({"profiles": [{"name": sync.MANAGED_PROFILE,
                                            "complex_modifications": {"rules": {}}}]}).encode(),
                   json.dumps({"profiles": [{"name": sync.MANAGED_PROFILE}] * 2}).encode())
        self.config.parent.mkdir()
        for contents in invalid:
            with self.subTest(contents=contents):
                self.config.write_bytes(contents)
                with self.assertRaises((sync.ConfigError, json.JSONDecodeError)):
                    self.apply()
                self.assertEqual(self.config.read_bytes(), contents)
                self.assertEqual(list(self.config.parent.glob("*.nix-vault-backup-*")), [])

    def test_config_file_and_directory_symlinks_are_refused(self):
        target = self.base / "target.json"
        target.write_text("{}")
        self.config.parent.mkdir()
        self.config.symlink_to(target)
        with self.assertRaisesRegex(sync.ConfigError, "symlink"):
            self.apply()
        self.assertEqual(target.read_text(), "{}")
        self.config.unlink()
        self.config.symlink_to(self.base / "missing.json")
        with self.assertRaisesRegex(sync.ConfigError, "symlink"):
            self.apply()
        linked_dir = self.base / "linked"
        linked_dir.symlink_to(self.config.parent, target_is_directory=True)
        with self.assertRaisesRegex(sync.ConfigError, "symlink"):
            sync.sync_config(linked_dir / "another.json", RULES_PATH)

    def test_read_only_asset_symlinks_are_supported(self):
        linked_asset = self.base / "asset.json"
        linked_asset.symlink_to(RULES_PATH)
        self.assertEqual(sync.sync_config(self.config, linked_asset), (True, None))

    def test_concurrent_settings_change_is_not_overwritten(self):
        self.write({"profiles": []})
        create_temp = tempfile.mkstemp
        concurrent = b'{"profiles": [], "changed_in_settings": true}'

        def edit_during_write(*args, **kwargs):
            result = create_temp(*args, **kwargs)
            self.config.write_bytes(concurrent)
            return result

        with mock.patch.object(sync.tempfile, "mkstemp", side_effect=edit_during_write):
            with self.assertRaisesRegex(sync.ConfigError, "changed during sync"):
                self.apply()
        self.assertEqual(self.config.read_bytes(), concurrent)
        self.assertEqual(list(self.config.parent.glob(".nix-vault-karabiner-*")), [])
        self.assertEqual(list(self.config.parent.glob("*.nix-vault-backup-*")), [])

    def test_failed_atomic_replace_keeps_original_and_backup(self):
        self.write({"profiles": []})
        original = self.config.read_bytes()
        with mock.patch.object(sync.os, "replace", side_effect=OSError("simulated failure")):
            with self.assertRaisesRegex(OSError, "simulated failure"):
                self.apply()
        self.assertEqual(self.config.read_bytes(), original)
        backups = list(self.config.parent.glob("*.nix-vault-backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original)
        self.assertEqual(list(self.config.parent.glob(".nix-vault-karabiner-*")), [])

    def test_invalid_rule_asset_is_rejected_before_creating_config(self):
        bad = self.base / "bad-rules.json"
        bad.write_text('{"rules": [{"description": "unowned", "manipulators": [{}]}]}')
        with self.assertRaises(sync.ConfigError):
            sync.sync_config(self.config, bad)
        self.assertFalse(self.config.exists())

    def test_rule_asset_must_provide_the_native_profile_rule(self):
        bad = self.base / "rules.json"
        bad.write_text(json.dumps({"rules": [RULES[WARP_RULE]]}))
        with self.assertRaisesRegex(sync.ConfigError, sync.MODIFIERS_RULE):
            sync.sync_config(self.config, bad)
        self.assertFalse(self.config.exists())

    def test_cli_reports_unusable_json_without_a_traceback(self):
        self.config.parent.mkdir()
        for contents in (b'{"profiles": [], "zoom": 1e400}', b"[" * 100000 + b"]" * 100000):
            with self.subTest(contents=contents[:32]):
                self.config.write_bytes(contents)
                result = subprocess.run(
                    [sys.executable, str(MODULE_DIR / "sync.py"),
                     "--config", str(self.config), "--rules", str(RULES_PATH)],
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 1)
                self.assertTrue(result.stderr.startswith("Karabiner sync failed: "), result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual(self.config.read_bytes(), contents)

    def test_cli_uses_xdg_directory_and_sibling_rules(self):
        config_home = self.base / "xdg"
        result = subprocess.run(
            [sys.executable, str(MODULE_DIR / "sync.py"), "--select"],
            env=dict(os.environ, HOME=str(self.base), XDG_CONFIG_HOME=str(config_home)),
            capture_output=True, text=True, check=True,
        )
        self.assertIn("Updated ", result.stdout)
        generated = json.loads((config_home / "karabiner/karabiner.json").read_text())
        self.assertEqual([p["name"] for p in generated["profiles"] if p["selected"]],
                         [sync.MANAGED_PROFILE])
        # Without --home, ~/ paths follow the user's home directory, and a missing
        # target is reported without failing.
        app = str(self.base / "Applications/Home Manager Apps/Emacs.app")
        for profile in generated["profiles"]:
            hotkey = next(r for r in profile["complex_modifications"]["rules"]
                          if r["description"] == EMACS_RULE)
            self.assertEqual(
                hotkey["manipulators"][1]["to"][0]["software_function"]["open_application"],
                {"file_path": app})
        self.assertEqual(result.stderr.count("Warning: " + app + " does not exist"), 1)

    def test_cli_home_option_and_no_warning_once_the_app_exists(self):
        home = self.base / "other-home"
        app = home / "Applications/Home Manager Apps/Emacs.app"
        app.mkdir(parents=True)
        # HOME has no Emacs.app, so only --home can satisfy the check.
        result = subprocess.run(
            [sys.executable, str(MODULE_DIR / "sync.py"), "--config", str(self.config),
             "--home", str(home)],
            env=dict(os.environ, HOME=str(self.base / "empty-home")),
            capture_output=True, text=True, check=True,
        )
        self.assertEqual(result.stderr, "")
        managed_rules = self.profile(sync.MANAGED_PROFILE)["complex_modifications"]["rules"]
        hotkey = next(r for r in managed_rules if r["description"] == EMACS_RULE)
        self.assertEqual(
            hotkey["manipulators"][1]["to"][0]["software_function"]["open_application"],
            {"file_path": str(app)})

    def test_cli_warns_about_a_missing_app_on_every_run(self):
        # Activations after the first find karabiner.json unchanged; the warning must
        # still appear. HOME has the app, --home does not.
        present = self.base / "home-with-emacs"
        (present / "Applications/Home Manager Apps/Emacs.app").mkdir(parents=True)
        absent = str(self.base / "home/Applications/Home Manager Apps/Emacs.app")
        for run in range(2):
            result = subprocess.run(
                [sys.executable, str(MODULE_DIR / "sync.py"), "--config", str(self.config),
                 "--home", str(self.home)],
                env=dict(os.environ, HOME=str(present)),
                capture_output=True, text=True, check=True,
            )
            with self.subTest(run=run):
                self.assertEqual(result.stdout.startswith("Updated "), run == 0)
                self.assertEqual(result.stderr.count("Warning: " + absent + " does not exist"), 1)

    def test_cli_reads_a_piped_asset_once(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_DIR / "sync.py"), "--config", str(self.config),
             "--rules", "/dev/stdin", "--home", str(self.home)],
            input=RULES_PATH.read_text(), capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Updated ", result.stdout)
        self.assertIn(self.rules[EMACS_RULE],
                      self.profile(sync.NATIVE_PROFILE)["complex_modifications"]["rules"])


if __name__ == "__main__":
    unittest.main()
