"""Isolated filesystem tests for the Warp settings sync; they do not start Warp."""

import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import tomli


MODULE_DIR = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("warp_sync", MODULE_DIR / "sync.py")
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)

# The layout Warp writes: standard tables, one value per line, inline tables, TOML 1.1
# inline tables across lines with trailing commas, and an unowned key whose name ends
# like an owned one.
SAMPLE = """\
[appearance]
theme_mode = "light"

[appearance.themes]
system_theme = false
selected_system_themes = { dark = "dark_city", light = "snowy" }

[appearance.text]
font_size = 15.0
font_name = "IBM Plex Mono"
ai_font_name = "IBM Plex Mono"

[global_hotkey]

[global_hotkey.toggle_all_windows]
enabled = false
keybinding = "ctrl-shift-E"

[privacy]
custom_secret_regex_list = [
  { name = "IPv4", pattern = '\\b(\\d{1,3}\\.){3}\\d{1,3}\\b' },
  {
    name = "Token",
    pattern = '\\btok-[a-f0-9]+\\b',
  },
]

[terminal.input]
honor_ps1 = false
"""
OWNED = {
    "appearance": {"text": {"font_name": "Maple Mono NF CN"}},
    "global_hotkey": {"toggle_all_windows": {"enabled": True, "keybinding": "ctrl-shift-E"}},
    "session": {"new_session_shell_override": {"executable": "/opt/homebrew/bin/fish"}},
}


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        # /var on macOS is itself a symlink, unrelated to the target under test.
        self.base = Path(self.temp.name).resolve()
        self.config = self.base / "warp" / "settings.toml"
        self.settings = self.base / "owned.json"
        self.own(OWNED)

    def own(self, settings):
        self.settings.write_text(json.dumps(settings))

    def write(self, contents):
        self.config.parent.mkdir(parents=True, exist_ok=True)
        self.config.write_bytes(contents.encode() if isinstance(contents, str) else contents)

    def read(self):
        return tomli.loads(self.config.read_text())

    def apply(self):
        return sync.write_config(self.config, sync.read_settings(self.settings))

    def backups(self):
        return list(self.config.parent.glob("*.nix-vault-backup-*"))

    def test_first_run_creates_a_private_regular_file_with_the_owned_tables(self):
        self.assertEqual(self.apply(), (True, None))
        self.assertTrue(stat.S_ISREG(self.config.lstat().st_mode))
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        self.assertTrue(sync.same(self.read(), OWNED))
        self.assertEqual(self.backups(), [])

    def test_owned_values_change_only_their_lines_and_missing_tables_are_appended(self):
        self.write(SAMPLE)
        changed, backup = self.apply()
        self.assertTrue(changed)
        expected = (
            SAMPLE.replace('\nfont_name = "IBM Plex Mono"', '\nfont_name = "Maple Mono NF CN"')
            .replace("enabled = false", "enabled = true")
            + '\n[session.new_session_shell_override]\nexecutable = "/opt/homebrew/bin/fish"\n'
        )
        self.assertEqual(self.config.read_text(), expected)
        self.assertEqual(self.read()["appearance"]["text"]["ai_font_name"], "IBM Plex Mono")
        self.assertEqual(backup.read_text(), SAMPLE)

    def test_missing_key_joins_its_table_before_the_blank_separator(self):
        self.own({"appearance": {"themes": {"follow_os": True}}})
        self.write(SAMPLE)
        self.apply()
        self.assertEqual(
            self.config.read_text(),
            SAMPLE.replace('light = "snowy" }\n', 'light = "snowy" }\nfollow_os = true\n'),
        )

    def test_root_keys_go_before_the_first_table(self):
        self.own({"top_level": "x"})
        self.write(SAMPLE)
        self.apply()
        self.assertEqual(self.config.read_text(), 'top_level = "x"\n' + SAMPLE)

    def test_keys_removed_from_the_owned_settings_stay_in_the_file(self):
        self.apply()
        self.own({"appearance": {"text": {"font_name": "Maple Mono NF CN"}}})
        self.assertEqual(self.apply(), (False, None))
        self.assertTrue(sync.same(self.read(), OWNED))

    def test_unchanged_file_keeps_bytes_inode_mtime_and_has_no_backup(self):
        self.apply()
        original = self.config.read_bytes()
        before = self.config.stat()
        self.assertEqual(self.apply(), (False, None))
        after = self.config.stat()
        self.assertEqual(self.config.read_bytes(), original)
        self.assertEqual((before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns))
        self.assertEqual(self.backups(), [])

    def test_owned_values_already_set_in_another_spelling_are_left_alone(self):
        contents = (
            "[appearance.text]\nfont_name = 'Maple Mono NF CN'\n\n"
            "[global_hotkey.toggle_all_windows]\nenabled = true  # on\nkeybinding = \"ctrl-shift-E\"\n\n"
            "[session.new_session_shell_override]\nexecutable = \"/opt/homebrew/bin/fish\"\n"
        )
        self.write(contents)
        self.assertEqual(self.apply(), (False, None))
        self.assertEqual(self.config.read_text(), contents)

    def test_trailing_comment_and_crlf_line_ends_are_kept(self):
        self.own({"appearance": {"text": {"font_name": "Maple Mono NF CN", "font_size": 14.0}}})
        self.write(b'[appearance.text]\r\nfont_name = "IBM Plex Mono"   # picked in Settings\r\n')
        self.apply()
        self.assertEqual(
            self.config.read_bytes(),
            b'[appearance.text]\r\nfont_name = "Maple Mono NF CN"   # picked in Settings\r\n'
            b"font_size = 14.0\r\n",
        )

    def test_value_types_and_escapes_round_trip(self):
        owned = {"t": {
            "flag": True, "count": 3, "ratio": 1.5, "whole": 15.0, "names": ["a", "b"],
            "text": 'say "hi" \\ \n\tdone \x7f', "odd key": "é", "nested": {"deep": False},
        }}
        self.own(owned)
        self.apply()
        document = self.read()
        self.assertTrue(sync.same(document, owned))
        self.assertIs(type(document["t"]["whole"]), float)
        self.assertIs(type(document["t"]["count"]), int)
        self.assertIs(type(document["t"]["flag"]), bool)

    def test_file_shapes_the_line_edits_cannot_handle_are_not_replaced(self):
        invalid = (
            "[appearance\n",
            'appearance = "light"\n',
            '[appearance.text.font_name]\nfamily = "x"\n',
            '[appearance]\ntext.font_name = "IBM Plex Mono"\n',
            '[appearance]\ntext = { font_name = "IBM Plex Mono" }\n',
            '[appearance]\ntext = {\n  font_name = "IBM Plex Mono",\n}\n',
            '[appearance.text]\nfont_name = """\nIBM Plex Mono"""\n',
            "[[global_hotkey.toggle_all_windows]]\nenabled = false\n",
            b"\xff\xfe",
        )
        for contents in invalid:
            with self.subTest(contents=contents):
                self.write(contents)
                original = self.config.read_bytes()
                with self.assertRaises(ValueError):
                    self.apply()
                self.assertEqual(self.config.read_bytes(), original)
                self.assertEqual(self.backups(), [])

    def test_a_line_inside_an_inline_table_is_not_taken_for_an_owned_key(self):
        # "name = ..." inside the multi-line inline table looks like a [privacy] key. The
        # edit breaks the inline table or changes its value; either way it is refused.
        self.own({"privacy": {"name": "x"}})
        self.write(SAMPLE)
        with self.assertRaisesRegex(sync.ConfigError, "set them by hand"):
            self.apply()
        self.assertEqual(self.config.read_text(), SAMPLE)
        self.assertEqual(self.backups(), [])

    def test_invalid_owned_settings_are_rejected_before_creating_the_file(self):
        invalid = (
            "[]", '{"a": {}}', '{"a": null}', '{"a": [{"b": 1}]}', '{"a": NaN}',
            '{"a": 1e400}', '{"a": 1, "a": 2}', '{"": 1}', '{"a": 9223372036854775808}',
        )
        for contents in invalid:
            with self.subTest(contents=contents):
                self.settings.write_text(contents)
                with self.assertRaises(sync.ConfigError):
                    self.apply()
                self.assertFalse(self.config.exists())

    def test_backup_is_byte_exact_and_output_preserves_file_mode(self):
        self.write(SAMPLE)
        self.config.chmod(0o644)
        _, backup = self.apply()
        self.assertEqual(backup.read_text(), SAMPLE)
        self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o644)

    def test_settings_file_and_directory_symlinks_are_refused(self):
        target = self.base / "target.toml"
        target.write_text(SAMPLE)
        self.config.parent.mkdir()
        self.config.symlink_to(target)
        with self.assertRaisesRegex(sync.ConfigError, "symlink"):
            self.apply()
        self.assertEqual(target.read_text(), SAMPLE)
        self.config.unlink()
        self.config.symlink_to(self.base / "missing.toml")
        with self.assertRaisesRegex(sync.ConfigError, "symlink"):
            self.apply()
        linked_dir = self.base / "linked"
        linked_dir.symlink_to(self.config.parent, target_is_directory=True)
        with self.assertRaisesRegex(sync.ConfigError, "symlink"):
            sync.write_config(linked_dir / "another.toml", sync.read_settings(self.settings))

    def test_concurrent_settings_change_is_not_overwritten(self):
        self.write(SAMPLE)
        create_temp = tempfile.mkstemp
        concurrent = SAMPLE + "changed_in_settings = true\n"

        def edit_during_write(*args, **kwargs):
            result = create_temp(*args, **kwargs)
            self.config.write_text(concurrent)
            return result

        with mock.patch.object(sync.tempfile, "mkstemp", side_effect=edit_during_write):
            with self.assertRaisesRegex(sync.ConfigError, "changed during sync"):
                self.apply()
        self.assertEqual(self.config.read_text(), concurrent)
        self.assertEqual(list(self.config.parent.glob(".nix-vault-warp-*")), [])
        self.assertEqual(self.backups(), [])

    def test_failed_atomic_replace_keeps_original_and_backup(self):
        self.write(SAMPLE)
        with mock.patch.object(sync.os, "replace", side_effect=OSError("simulated failure")):
            with self.assertRaisesRegex(OSError, "simulated failure"):
                self.apply()
        self.assertEqual(self.config.read_text(), SAMPLE)
        backups = self.backups()
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), SAMPLE)
        self.assertEqual(list(self.config.parent.glob(".nix-vault-warp-*")), [])

    def test_default_path_is_dot_warp_on_macos_and_the_warp_oss_xdg_directory_elsewhere(self):
        environment = {"HOME": str(self.base), "XDG_CONFIG_HOME": str(self.base / "xdg")}
        with mock.patch.dict(os.environ, environment):
            with mock.patch.object(sync.sys, "platform", "darwin"):
                self.assertEqual(sync.default_config(), self.base / ".warp/settings.toml")
            with mock.patch.object(sync.sys, "platform", "linux"):
                self.assertEqual(sync.default_config(), self.base / "xdg/warp-oss/settings.toml")
                del os.environ["XDG_CONFIG_HOME"]
                self.assertEqual(sync.default_config(),
                                 self.base / ".config/warp-oss/settings.toml")

    def run_cli(self, *arguments, **kwargs):
        return subprocess.run(
            [sys.executable, str(MODULE_DIR / "sync.py"), "--settings", str(self.settings),
             *arguments],
            capture_output=True, text=True, **kwargs,
        )

    def test_cli_reports_unusable_files_without_a_traceback(self):
        self.config.parent.mkdir()
        for contents in (b"[appearance\n", b'appearance = "light"\n', b"x = [" * 100000):
            with self.subTest(contents=contents[:32]):
                self.config.write_bytes(contents)
                result = self.run_cli("--config", str(self.config))
                self.assertEqual(result.returncode, 1)
                self.assertTrue(result.stderr.startswith("Warp settings sync failed: "),
                                result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual(self.config.read_bytes(), contents)

    def test_cli_creates_the_default_file_and_then_reports_it_up_to_date(self):
        environment = dict(os.environ, HOME=str(self.base), XDG_CONFIG_HOME=str(self.base / "xdg"))
        expected = (self.base / ".warp/settings.toml" if sys.platform == "darwin"
                    else self.base / "xdg/warp-oss/settings.toml")
        result = self.run_cli(env=environment, check=True)
        self.assertEqual(result.stdout, "Updated " + str(expected) + "\n")
        self.assertTrue(sync.same(tomli.loads(expected.read_text()), OWNED))
        result = self.run_cli("--verbose", env=environment, check=True)
        self.assertEqual(result.stdout, "Already up to date: " + str(expected) + "\n")


if __name__ == "__main__":
    unittest.main()
