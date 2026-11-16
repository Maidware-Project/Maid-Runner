"""Single-instance toggle: one quiet channel to the resident window.

The first Maid Runner opens the window and stays resident; later ones
talk to it over a unix socket instead of opening a second window. The
messages are single words: ``show``, ``toggle``, ``quit``, ``ping``.

Only the standard library here. The client side runs on the keybind
path, where even a Qt import is latency the user can feel; the server
side lives on the window's event loop in app.py.
"""

import os
import socket

# The socket carries words, not payloads; this is plenty.
_CHUNK = 64


def socket_path():
    """Where the resident instance listens. Per user, per runtime dir."""
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime and os.path.isdir(runtime):
        return os.path.join(runtime, "maid-runner.sock")
    return os.path.join("/tmp", f"maid-runner-{os.getuid()}.sock")


def send(word, timeout=0.5):
    """Deliver one word to a running instance; False when none listens."""
    path = socket_path()
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect(path)
        sock.sendall(word.encode("ascii") + b"\n")
        return True
    except OSError:
        return False
    finally:
        try:
            sock.close()
        except OSError:
            pass


def _alive(path, timeout=0.1):
    """True if a responsive listener owns the socket path."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect(path)
        sock.sendall(b"ping\n")
        return True
    except OSError:
        return False
    finally:
        try:
            sock.close()
        except OSError:
            pass


def listen():
    """Bind the single socket. None when another instance already serves.

    A leftover file from a crash gets removed and the path is taken
    over; only a live listener keeps it.
    """
    path = socket_path()
    parent = os.path.dirname(path)
    if parent and not os.path.isdir(parent):
        try:
            os.makedirs(parent, mode=0o700, exist_ok=True)
        except OSError:
            pass

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.bind(path)
    except OSError:
        # Probe before stealing: if someone answers, refuse.
        if _alive(path):
            sock.close()
            return None
        # Stale socket file from a crashed instance: remove and retry.
        try:
            os.unlink(path)
        except OSError:
            pass
        try:
            sock.close()
        except OSError:
            pass
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.bind(path)
        except OSError:
            try:
                sock.close()
            except OSError:
                pass
            return None
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    sock.listen(8)
    sock.setblocking(False)
    return sock
