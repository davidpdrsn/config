#!/usr/bin/env python3
"""Tests for PR digest delivery behavior."""

from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "pr_digest", Path(__file__).with_name("pr-digest.py")
)
digest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(digest)


class DigestTests(unittest.TestCase):
    def test_no_prs_produces_no_output_or_summaries(self):
        output = io.StringIO()
        with (
            patch.object(digest.sys, "argv", ["pr-digest", "owner/repo"]),
            patch.object(digest.shutil, "which", return_value="/bin/tool"),
            patch.object(digest, "Progress") as progress,
            patch.object(digest, "find_prs", return_value=[]),
            patch.object(digest, "process_pr") as process,
            patch.object(digest.tempfile, "TemporaryDirectory") as temporary_directory,
            redirect_stdout(output),
        ):
            self.assertEqual(digest.main(), 0)
        self.assertEqual(output.getvalue(), "")
        process.assert_not_called()
        temporary_directory.assert_not_called()
        progress.return_value.finish.assert_called_once()


if __name__ == "__main__":
    unittest.main()
