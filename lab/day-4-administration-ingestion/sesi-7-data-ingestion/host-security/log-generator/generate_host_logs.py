import random
import time
from datetime import datetime

AUTH_LOG = "/var/log/host-security/auth.log"
BASH_HISTORY = "/var/log/host-security/bash_history"

HOSTNAME = "web-prod-01"

NORMAL_USERS = ["deploy", "alice", "bob"]
NORMAL_IPS = ["10.20.30.41", "10.20.30.55", "10.20.30.12"]
BRUTE_FORCE_IPS = ["198.51.100.23", "203.0.113.77"]

NORMAL_COMMANDS = [
    "whoami",
    "cd /var/www/app",
    "git pull origin main",
    "docker ps",
    "systemctl status app",
    "sudo systemctl restart app",
    "tail -f /var/log/app.log",
    "ls -la",
]

SENSITIVE_COMMANDS = [
    "cat /etc/shadow",
    "cat /etc/passwd",
    "cat ~/.ssh/id_rsa",
    "mysql -u root -p",
    "cat /var/www/app/.env",
]


def ts():
    return datetime.now().strftime("%b %d %H:%M:%S")


def append(path, line):
    with open(path, "a") as f:
        f.write(line + "\n")
        f.flush()


def emit_ssh_success():
    user = random.choice(NORMAL_USERS)
    ip = random.choice(NORMAL_IPS)
    pid = random.randint(10000, 20000)
    port = random.randint(40000, 60000)
    append(
        AUTH_LOG,
        f"{ts()} {HOSTNAME} sshd[{pid}]: Accepted publickey for {user} from {ip} port {port} ssh2",
    )


def emit_ssh_brute_force():
    ip = random.choice(BRUTE_FORCE_IPS)
    pid = random.randint(10000, 20000)
    port = random.randint(40000, 60000)
    for _ in range(random.randint(3, 6)):
        append(
            AUTH_LOG,
            f"{ts()} {HOSTNAME} sshd[{pid}]: Failed password for root from {ip} port {port} ssh2",
        )
        time.sleep(0.3)


def emit_new_user():
    uid = random.randint(1001, 1099)
    name = f"svc-{uid}"
    pid = random.randint(10000, 20000)
    append(
        AUTH_LOG,
        f"{ts()} {HOSTNAME} useradd[{pid}]: new user: name={name}, UID={uid}, GID={uid}, "
        f"home=/home/{name}, shell=/bin/bash",
    )


def emit_bash_normal():
    append(BASH_HISTORY, random.choice(NORMAL_COMMANDS))


def emit_bash_sensitive():
    append(BASH_HISTORY, random.choice(SENSITIVE_COMMANDS))


def main():
    print("host-security log generator started", flush=True)
    while True:
        roll = random.random()
        if roll < 0.35:
            emit_ssh_success()
        elif roll < 0.40:
            emit_ssh_brute_force()
        elif roll < 0.42:
            emit_new_user()
        elif roll < 0.90:
            emit_bash_normal()
        else:
            emit_bash_sensitive()
        time.sleep(random.uniform(1.0, 3.0))


if __name__ == "__main__":
    main()
