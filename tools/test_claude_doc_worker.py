"""Offline checks: no API calls, only temporary candidate files."""
import pathlib
import tempfile
import unittest
import claude_doc_worker as worker


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.old = worker.JOB
        worker.JOB = pathlib.Path(self.temp.name)
        for folder in ["candidate", "original"]:
            (worker.JOB / folder / "docs").mkdir(parents=True)
            (worker.JOB / folder / "docs/a.md").write_text("# Title\n\nOriginal body.\n", encoding="utf-8")

    def tearDown(self):
        worker.JOB = self.old
        self.temp.cleanup()

    def patch(self, op, old="", new="", file="docs/a.md"):
        return {"file":file, "op":op, "old":old, "new":new}

    def test_forbidden_paths(self):
        for name in ["AGENTS.md", "../a.md", "src/a.luau", ".env"]:
            with self.assertRaises(ValueError):
                worker.allowed_path(worker.JOB, name, [name])

    def test_replace(self):
        worker.apply_candidate({"patches":[self.patch("replace", "Original body.", "Updated body.")]}, ["docs/a.md"])
        self.assertIn("Updated body.", (worker.JOB / "candidate/docs/a.md").read_text())

    def test_validate_whole_report_before_write(self):
        p = worker.JOB / "candidate/docs/a.md"
        before = p.read_bytes()
        with self.assertRaises(ValueError):
            worker.apply_candidate({"patches":[self.patch("replace", "Original", "Changed"), self.patch("replace", "missing", "new")]}, ["docs/a.md"])
        self.assertEqual(before, p.read_bytes())

    def test_preserve_history_body(self):
        p = worker.JOB / "candidate/docs/a.md"
        p.write_text("# Title\n\nTampered history.\n")
        worker.apply_candidate({"patches":[self.patch("restore_history", new="> 기록용 안내")]}, ["docs/a.md"])
        result = p.read_text(encoding="utf-8")
        self.assertEqual(result.replace("\n> 기록용 안내\n", ""), "# Title\n\nOriginal body.\n")

    def test_restore_cannot_mix(self):
        with self.assertRaises(ValueError):
            worker.apply_candidate({"patches":[self.patch("restore_history", new="> notice"), self.patch("prepend", new="> another")]}, ["docs/a.md"])


if __name__ == "__main__":
    unittest.main()
