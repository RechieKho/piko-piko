"""Tiny harness to drive Piko-piko inside QEMU (headless) through QMP.

The guest is operated like a human would: keystrokes are injected with
`send-key` and the screen is read back from the VGA text buffer (0xB8000).
"""

import json
import os
import shutil
import socket
import subprocess
import tempfile
import time

QEMU = os.environ.get("QEMU", "qemu-system-x86_64")
QEMU_RAM_SIZE = os.environ.get("QEMU_RAM_SIZE", "64M")
QEMU_ACCEL = os.environ.get("QEMU_ACCEL", "tcg")
QEMU_HD_CYLINDER_COUNT = os.environ.get("QEMU_HD_CYLINDER_COUNT", "1024")
QEMU_HD_HEAD_COUNT = os.environ.get("QEMU_HD_HEAD_COUNT", "16")
QEMU_HD_SECTOR_COUNT = os.environ.get("QEMU_HD_SECTOR_COUNT", "63")

VGA_ADDR = 0xB8000
VGA_WIDTH = 80
VGA_HEIGHT = 25

# Characters that need no modifier -> QMP qcode.
_PLAIN = {
    " ": "spc", "\n": "ret", "'": "apostrophe", "=": "equal", "-": "minus",
    ".": "dot", ",": "comma", "/": "slash", ";": "semicolon",
}
# Characters typed with shift -> QMP qcode of the underlying key.
_SHIFTED = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "*": "8",
            "(": "9", ")": "0", "_": "minus", "+": "equal", ":": "semicolon"}


def qcodes(ch):
    """Return the list of qcodes (pressed together) that types `ch`."""
    if ch in _PLAIN:
        return [_PLAIN[ch]]
    if ch.isdigit() or ("a" <= ch <= "z"):
        return [ch]
    if "A" <= ch <= "Z":
        return ["shift", ch.lower()]
    if ch in _SHIFTED:
        return ["shift", _SHIFTED[ch]]
    raise ValueError("cannot type %r" % ch)


class PikoVM:
    """A running Piko-piko guest. Use as a context manager."""

    def __init__(self, image, timeout=30):
        self.image = image
        self.timeout = timeout
        self._dir = tempfile.mkdtemp(prefix="piko-vm-")
        self._sock_path = os.path.join(self._dir, "qmp")
        self._dump_path = os.path.join(self._dir, "vga.bin")
        self._proc = None
        self._sock = None

    # --- lifecycle ---
    def __enter__(self):
        self.start()
        return self

    def __exit__(self, *exc):
        self.stop()

    def start(self):
        args = [
            QEMU, "-m", QEMU_RAM_SIZE, "-display", "none", "-accel", QEMU_ACCEL,
            "-drive", "if=none,id=disk,file=%s,format=raw" % self.image,
            "-device", "ide-hd,drive=disk,cyls=%s,heads=%s,secs=%s" % (
                QEMU_HD_CYLINDER_COUNT, QEMU_HD_HEAD_COUNT, QEMU_HD_SECTOR_COUNT),
            "-qmp", "unix:%s,server=on,wait=off" % self._sock_path,
            "-serial", "none", "-no-reboot",
        ]
        self._proc = subprocess.Popen(args, stdout=subprocess.DEVNULL,
                                      stderr=subprocess.PIPE)
        deadline = time.time() + self.timeout
        while not os.path.exists(self._sock_path):
            if self._proc.poll() is not None:
                raise RuntimeError("qemu exited: " + self._proc.stderr.read().decode())
            if time.time() > deadline:
                raise TimeoutError("qemu did not create its QMP socket")
            time.sleep(0.05)
        self._sock = socket.socket(socket.AF_UNIX)
        self._sock.connect(self._sock_path)
        self._file = self._sock.makefile("rw")
        self._file.readline()  # greeting
        self._qmp("qmp_capabilities")
        self.wait_prompt()

    def stop(self):
        """Quit the guest; the disk image is fully flushed once this returns."""
        if self._proc is not None:
            try:
                self._qmp("quit")
            except Exception:
                self._proc.kill()
            self._proc.wait(timeout=self.timeout)
            self._proc.stderr.close()
            self._proc = None
        if self._sock is not None:
            self._file.close()
            self._sock.close()
            self._sock = None
        shutil.rmtree(self._dir, ignore_errors=True)

    # --- QMP ---
    def _qmp(self, execute, **arguments):
        self._file.write(json.dumps({"execute": execute, "arguments": arguments}) + "\n")
        self._file.flush()
        while True:
            reply = json.loads(self._file.readline())
            if "error" in reply:
                raise RuntimeError(reply["error"])
            if "return" in reply:
                return reply["return"]

    # --- screen ---
    def screen(self):
        """The 80x25 text screen as a string (trailing blanks stripped)."""
        self._qmp("pmemsave", val=VGA_ADDR, size=VGA_WIDTH * VGA_HEIGHT * 2,
                  filename=self._dump_path)
        with open(self._dump_path, "rb") as f:
            raw = f.read()
        rows = []
        for r in range(VGA_HEIGHT):
            row = raw[r * VGA_WIDTH * 2:(r + 1) * VGA_WIDTH * 2:2]
            rows.append(row.decode("latin1").replace("\0", " ").rstrip())
        return "\n".join(rows).rstrip()

    def wait_prompt(self, before=None):
        """Wait until the screen is stable, differs from `before`, ends in '>'."""
        deadline = time.time() + self.timeout
        last, stable = None, 0
        while time.time() < deadline:
            now = self.screen()
            stable = stable + 1 if now == last else 0
            last = now
            if stable >= 3 and now != before and now.splitlines()[-1:] == [">"]:
                return now
            time.sleep(0.1)
        raise TimeoutError("no prompt; screen was:\n" + (last or ""))

    # --- keyboard ---
    def type(self, text):
        for ch in text:
            keys = [{"type": "qcode", "data": k} for k in qcodes(ch)]
            self._qmp("send-key", keys=keys, **{"hold-time": 20})
            time.sleep(0.03)

    def run(self, command):
        """Type a command, press enter and return the screen once it finished.

        The screen is cleared first so the result holds only this command.
        """
        if command != "cls":
            self.run("cls")
        before = self.screen()
        self.type(command + "\n")
        return self.wait_prompt(before)
