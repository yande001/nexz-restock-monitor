#!/usr/bin/env python3
"""Send an email via Gmail SMTP. Usage: send_mail.py "<subject>" "<body>" """
import sys, smtplib, ssl, os
from email.message import EmailMessage

CFG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mail.cfg")
cfg = {}
with open(CFG) as f:
    for line in f:
        line = line.strip()
        if line and "=" in line:
            k, v = line.split("=", 1)
            cfg[k] = v

subject = sys.argv[1] if len(sys.argv) > 1 else "(no subject)"
body = sys.argv[2] if len(sys.argv) > 2 else ""

msg = EmailMessage()
msg["From"] = cfg["GMAIL_USER"]
msg["To"] = cfg["MAIL_TO"]
msg["Subject"] = subject
msg.set_content(body)

ctx = ssl.create_default_context()
with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=ctx) as s:
    s.login(cfg["GMAIL_USER"], cfg["GMAIL_APP_PW"])
    s.send_message(msg)
print("sent ok")
