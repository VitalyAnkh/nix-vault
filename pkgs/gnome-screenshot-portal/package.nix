{
  lib,
  gnome-screenshot,
  python3,
  runCommand,
  wl-clipboard,
  writeShellApplication,
}:

let
  python = python3.withPackages (ps: [ ps.dbus-next ]);
  wrapper = writeShellApplication {
    name = "gnome-screenshot";
    runtimeInputs = [
      python
      wl-clipboard
    ];

    text = ''
      exec ${python}/bin/python3 - "$@" <<'PY'
      import argparse
      import asyncio
      import os
      from pathlib import Path
      import shutil
      import shlex
      import subprocess
      import sys
      import time
      from urllib.parse import unquote, urlparse

      from dbus_next import BusType, Message, MessageType, Variant
      from dbus_next.aio import MessageBus

      ORIGINAL_GNOME_SCREENSHOT = "${gnome-screenshot}/bin/gnome-screenshot"
      PORTAL_RESPONSE_TIMEOUT_SECONDS = 15 * 60
      DBUS_SERVICE = "org.freedesktop.DBus"
      DBUS_PATH = "/org/freedesktop/DBus"
      DBUS_IFACE = "org.freedesktop.DBus"
      PORTAL_SERVICE = "org.freedesktop.portal.Desktop"
      PORTAL_PATH = "/org/freedesktop/portal/desktop"
      PORTAL_SCREENSHOT_IFACE = "org.freedesktop.portal.Screenshot"
      PORTAL_REQUEST_IFACE = "org.freedesktop.portal.Request"
      REQUEST_NAMESPACE = "/org/freedesktop/portal/desktop/request"
      PORTAL_RESPONSE_MATCH = (
          "type='signal',"
          f"interface='{PORTAL_REQUEST_IFACE}',"
          "member='Response',"
          f"path_namespace='{REQUEST_NAMESPACE}'"
      )


      def parse_xdg_user_dir(name: str) -> Path | None:
          config_home = os.environ.get("XDG_CONFIG_HOME")
          config_path = (
              Path(config_home).expanduser() / "user-dirs.dirs"
              if config_home
              else Path.home() / ".config" / "user-dirs.dirs"
          )
          key = f"XDG_{name}_DIR"

          try:
              lines = config_path.read_text(encoding="utf-8").splitlines()
          except FileNotFoundError:
              return None
          except OSError:
              return None

          for raw_line in lines:
              line = raw_line.strip()
              if not line or line.startswith("#") or "=" not in line:
                  continue

              current_key, raw_value = line.split("=", 1)
              if current_key.strip() != key:
                  continue

              try:
                  parts = shlex.split(raw_value, comments=True, posix=True)
              except ValueError:
                  return None
              if not parts:
                  return None

              return Path(os.path.expandvars(parts[0])).expanduser()

          return None


      def pictures_dir() -> Path:
          pictures = os.environ.get("XDG_PICTURES_DIR")
          if pictures:
              return Path(os.path.expandvars(pictures)).expanduser()
          return parse_xdg_user_dir("PICTURES") or Path.home() / "Pictures"


      def default_output_path() -> Path:
          timestamp = time.strftime("%Y-%m-%d %H-%M-%S")
          return pictures_dir() / "Screenshots" / f"Screenshot from {timestamp}.png"


      def parse_args(argv):
          parser = argparse.ArgumentParser(
              prog="gnome-screenshot",
              description="Capture a screenshot through the XDG Desktop Portal with native fallbacks.",
          )
          parser.add_argument(
              "-a",
              "--area",
              action="store_true",
              help="Capture an area using the native gnome-screenshot fallback.",
          )
          parser.add_argument(
              "-w",
              "--window",
              action="store_true",
              help="Capture a window using the native gnome-screenshot fallback.",
          )
          parser.add_argument(
              "-c",
              "--clipboard",
              action="store_true",
              help="Copy the screenshot to the clipboard.",
          )
          parser.add_argument("-i", "--interactive", action="store_true")
          parser.add_argument("-f", "--file", dest="output_file")
          parser.add_argument("-d", "--delay", type=float, default=0)
          parser.add_argument(
              "--version",
              action="version",
              version="gnome-screenshot 41.0 (portal wrapper)",
          )
          args, unknown = parser.parse_known_args(argv)
          if args.delay < 0:
              parser.error("--delay must be non-negative")
          return args, unknown


      def variant_value(value):
          return value.value if hasattr(value, "value") else value


      def file_uri_to_path(uri: str) -> Path:
          parsed = urlparse(uri)
          if parsed.scheme != "file":
              raise RuntimeError(f"unsupported screenshot URI: {uri}")
          return Path(unquote(parsed.path))


      async def add_portal_response_match(bus: MessageBus):
          reply = await bus.call(
              Message(
                  destination=DBUS_SERVICE,
                  path=DBUS_PATH,
                  interface=DBUS_IFACE,
                  member="AddMatch",
                  signature="s",
                  body=[PORTAL_RESPONSE_MATCH],
              )
          )
          if reply.message_type == MessageType.ERROR:
              raise RuntimeError(
                  f"failed to subscribe to portal response signals: {reply.error_name}"
              )


      async def capture_screenshot_uri(interactive: bool, fallback_argv: list[str]) -> str:
          bus = await MessageBus(bus_type=BusType.SESSION).connect()
          loop = asyncio.get_running_loop()
          future = loop.create_future()
          responses = {}
          handle_holder = {}

          def handle_response(message):
              if message.message_type != MessageType.SIGNAL:
                  return
              if message.interface != PORTAL_REQUEST_IFACE or message.member != "Response":
                  return
              if not message.path or not message.path.startswith(REQUEST_NAMESPACE):
                  return

              responses[message.path] = message.body
              handle = handle_holder.get("handle")
              if handle == message.path and not future.done():
                  future.set_result(message.body)

          bus.add_message_handler(handle_response)
          await add_portal_response_match(bus)

          token = f"gnome_screenshot_{os.getpid()}_{time.time_ns()}".replace("-", "_")
          options = {
              "handle_token": Variant("s", token),
              "interactive": Variant("b", interactive),
          }

          reply = await bus.call(
              Message(
                  destination=PORTAL_SERVICE,
                  path=PORTAL_PATH,
                  interface=PORTAL_SCREENSHOT_IFACE,
                  member="Screenshot",
                  signature="sa{sv}",
                  body=["", options],
              )
          )
          handle = str(reply.body[0])
          handle_holder["handle"] = handle

          if handle in responses and not future.done():
              future.set_result(responses[handle])

          try:
              body = await asyncio.wait_for(future, timeout=PORTAL_RESPONSE_TIMEOUT_SECONDS)
          except asyncio.TimeoutError:
              completed = subprocess.run([ORIGINAL_GNOME_SCREENSHOT, *fallback_argv], check=False)
              raise SystemExit(completed.returncode)

          response_code, results = body
          if response_code != 0:
              raise RuntimeError(
                  f"portal screenshot was denied or cancelled with response code {response_code}"
              )

          try:
              uri = variant_value(results["uri"])
          except KeyError as error:
              raise RuntimeError("portal screenshot response did not include a uri") from error

          if not isinstance(uri, str):
              raise RuntimeError("portal screenshot uri was not a string")

          return uri


      def copy_to_clipboard(path: Path):
          data = path.read_bytes()
          if not data:
              raise RuntimeError(f"cannot copy empty screenshot to clipboard: {path}")
          completed = subprocess.run(
              ["wl-copy", "--type", "image/png"],
              input=data,
              check=False,
          )
          if completed.returncode != 0:
              raise RuntimeError(f"wl-copy exited with status {completed.returncode}")


      async def main(argv):
          args, unknown = parse_args(argv)
          if unknown or args.area or args.window or (args.clipboard and not os.environ.get("WAYLAND_DISPLAY")):
              completed = subprocess.run([ORIGINAL_GNOME_SCREENSHOT, *argv], check=False)
              raise SystemExit(completed.returncode)
          if args.delay:
              await asyncio.sleep(args.delay)

          destination = None
          if args.output_file:
              destination = Path(args.output_file).expanduser()
          elif not args.clipboard:
              destination = default_output_path()

          uri = await capture_screenshot_uri(interactive=args.interactive, fallback_argv=argv)
          source = file_uri_to_path(uri)
          if not source.is_file() or source.stat().st_size == 0:
              raise RuntimeError(f"portal screenshot file is missing or empty: {source}")

          clipboard_source = source
          if destination is not None:
              destination.parent.mkdir(parents=True, exist_ok=True)
              if source.resolve() != destination.resolve(strict=False):
                  shutil.copyfile(source, destination)
              clipboard_source = destination

          if args.clipboard:
              copy_to_clipboard(clipboard_source)


      try:
          asyncio.run(main(sys.argv[1:]))
      except Exception as error:
          print(f"gnome-screenshot: {error}", file=sys.stderr)
          sys.exit(1)
      PY
    '';
  };

in
runCommand "gnome-screenshot"
  {
    meta = {
      description = "Portal-backed gnome-screenshot compatibility wrapper";
      license = lib.licenses.mit;
      mainProgram = "gnome-screenshot";
      platforms = lib.platforms.linux;
    };
  }
  ''
      cp -a ${gnome-screenshot}/. "$out/"
      chmod -R u+w "$out"
      rm -f "$out/bin/gnome-screenshot"
      install -Dm755 ${wrapper}/bin/gnome-screenshot "$out/bin/gnome-screenshot"
      cat > "$out/share/dbus-1/services/org.gnome.Screenshot.service" <<EOF
    [D-BUS Service]
    Name=org.gnome.Screenshot
    Exec=$out/bin/gnome-screenshot --gapplication-service
    EOF
  ''
