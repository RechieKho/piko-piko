"""End-to-end tests: Piko-piko running in QEMU, together with the `pikofs` tool.

Run with `make test-qemu` (builds the image and the tool first).
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qemu_vm import PikoVM, QEMU  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGE = os.path.join(ROOT, "piko-piko.bin")
PIKOFS = os.path.join(ROOT, "pikofs")


def read_file(path):
    with open(path, "rb") as f:
        return f.read()


def pikofs(*args, **kw):
    return subprocess.run([PIKOFS, *args], check=True, capture_output=True, **kw)


@unittest.skipUnless(shutil.which(QEMU), "%s not installed" % QEMU)
class QemuCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="piko-test-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.image = os.path.join(self.tmp, "disk.bin")
        shutil.copy(IMAGE, self.image)

    def path(self, name):
        return os.path.join(self.tmp, name)


class TestGuestRuns(QemuCase):
    """Proves the test setup itself: QEMU boots the image and we can drive it."""

    def test_boots_and_greets(self):
        with PikoVM(self.image) as vm:
            self.assertIn("Welcome to piko-piko!", vm.screen())

    def test_info_command(self):
        with PikoVM(self.image) as vm:
            screen = vm.run("info")
        self.assertIn("Piko-piko version: 1.0.0", screen)
        self.assertIn("File count: 0x0007", screen)

    def test_typing_edits_the_buffer(self):
        with PikoVM(self.image) as vm:
            vm.run("= 0 'hello world'")
            screen = vm.run("lsb 0 1")
        self.assertIn("00000 hello world", screen)


class TestHostToGuest(QemuCase):
    """`pikofs import` -> the guest's `load` sees the file."""

    def test_imported_file_is_loaded_by_guest(self):
        src = self.path("in.txt")
        with open(src, "w") as f:
            f.write("say n 'from the host'\nrow two\n\nrow four\n")
        pikofs("import", self.image, "3", src)
        with PikoVM(self.image) as vm:
            vm.run("stb 1")
            vm.run("load 3")
            screen = vm.run("lsb 0 5")
        self.assertIn("00000 say n 'from the host'", screen)
        self.assertIn("00001 row two", screen)
        self.assertIn("00003 row four", screen)

    def test_imported_program_runs(self):
        src = self.path("prog.txt")
        with open(src, "w") as f:
            f.write("say n 'hello from file'\n")
        pikofs("import", self.image, "0", src)
        with PikoVM(self.image) as vm:
            vm.run("load 0")
            screen = vm.run("run")
        self.assertIn("hello from file", screen)

    def test_import_keeps_other_slots_and_kernel(self):
        before = read_file(self.image)
        src = self.path("in.txt")
        with open(src, "w") as f:
            f.write("x\n")
        pikofs("import", self.image, "2", src)
        after = read_file(self.image)
        self.assertEqual(len(before), len(after))
        slot = 96 * 512
        begin = (40 + 2) * 512 + 2 * slot
        self.assertEqual(before[:begin], after[:begin])
        self.assertEqual(before[begin + slot:], after[begin + slot:])


class TestGuestToHost(QemuCase):
    """The guest's `save` -> `pikofs export` gets the file out."""

    def test_saved_file_is_exported(self):
        with PikoVM(self.image) as vm:
            vm.run("= 0 'say n hi'")
            vm.run("= 2 'bye'")
            vm.run("save 5")
        out = pikofs("export", self.image, "5").stdout.decode()
        self.assertEqual(out, "say n hi\n\nbye\n")

    def test_round_trip_through_guest(self):
        src = self.path("in.txt")
        content = "first\n  indented\n\nlast one\n"
        with open(src, "w") as f:
            f.write(content)
        pikofs("import", self.image, "1", src)
        with PikoVM(self.image) as vm:
            vm.run("load 1")
            vm.run("save 4")  # guest copies slot 1 to slot 4
        self.assertEqual(pikofs("export", self.image, "4").stdout.decode(), content)


if __name__ == "__main__":
    unittest.main()
