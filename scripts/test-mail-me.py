import importlib.util
import io
from email import policy
from email.parser import BytesParser
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "mail_me", Path(__file__).with_name("mail-me.py")
)
mail_me = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mail_me)


class MailMeTests(unittest.TestCase):
    def test_utf8_message_and_fixed_recipient(self):
        with patch.object(mail_me.sys, "stdin", io.StringIO("Job finished ✓\n")), patch.object(
            mail_me.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)
        ) as run:
            self.assertEqual(mail_me.main(["Summary ✓"]), 0)
        self.assertEqual(run.call_args.args[0], ["msmtp", "--account=gmail", "--", mail_me.RECIPIENT])
        message = BytesParser(policy=policy.default).parsebytes(run.call_args.kwargs["input"])
        self.assertEqual(str(message["Subject"]), "Summary ✓")
        self.assertEqual(message["To"], mail_me.RECIPIENT)
        self.assertEqual(message["From"], mail_me.RECIPIENT)
        self.assertEqual(message.get_content().replace("\r\n", "\n"), "Job finished ✓\n")
        self.assertEqual(message.get_content_type(), "text/plain")

    def test_invalid_subjects_never_send(self):
        for subject in ["", "  ", "Hello\nBcc: other@example.com", "Hello\rInjected"]:
            with self.subTest(subject=subject), patch.object(mail_me.subprocess, "run") as run, patch.object(
                mail_me.sys, "stderr", io.StringIO()
            ), self.assertRaises(SystemExit) as error:
                mail_me.main([subject])
            self.assertEqual(error.exception.code, 2)
            run.assert_not_called()

    def test_delivery_failure_propagates(self):
        with patch.object(mail_me.sys, "stdin", io.StringIO("")), patch.object(
            mail_me.subprocess, "run", return_value=subprocess.CompletedProcess([], 75)
        ):
            self.assertEqual(mail_me.main(["Failed job"]), 75)

    def test_missing_msmtp(self):
        with patch.object(mail_me.sys, "stdin", io.StringIO("body")), patch.object(
            mail_me.subprocess, "run", side_effect=FileNotFoundError("msmtp")
        ), patch.object(mail_me.sys, "stderr", io.StringIO()):
            self.assertEqual(mail_me.main(["Subject"]), 1)

    def test_interactive_stdin_rejected(self):
        with patch.object(mail_me.sys.stdin, "isatty", return_value=True), patch.object(
            mail_me.subprocess, "run"
        ) as run, patch.object(mail_me.sys, "stderr", io.StringIO()), self.assertRaises(SystemExit) as error:
            mail_me.main(["Subject"])
        self.assertEqual(error.exception.code, 2)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
