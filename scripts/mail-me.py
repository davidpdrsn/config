#!/usr/bin/env python3
"""Send stdin to David's Gmail: mail-me [--html] "Subject" < body."""

import argparse
from email.message import EmailMessage
from email.policy import SMTP
import subprocess
import sys

RECIPIENT = "david.pdrsn@gmail.com"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("subject", help="Email subject (one nonempty line)")
    parser.add_argument("--html", action="store_true", help="Treat stdin as HTML")
    args = parser.parse_args(argv)
    if not args.subject.strip() or "\r" in args.subject or "\n" in args.subject:
        parser.error("subject must be a single nonempty line")
    if sys.stdin.isatty():
        parser.error("provide the body through a pipe or stdin redirection")

    message = EmailMessage(policy=SMTP)
    message["From"] = RECIPIENT
    message["To"] = RECIPIENT
    message["Subject"] = args.subject
    message.set_content(
        sys.stdin.read(), subtype="html" if args.html else "plain", charset="utf-8"
    )
    try:
        return subprocess.run(
            ["msmtp", "--account=gmail", "--", RECIPIENT],
            input=message.as_bytes(),
            check=False,
        ).returncode
    except OSError as error:
        print(f"mail-me: could not launch msmtp: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
