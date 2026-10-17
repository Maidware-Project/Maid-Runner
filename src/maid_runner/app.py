r"""Maid Runner window: one search box, TAB cycles sources.

The window is a fullscreen dim overlay with the search card centered
inside it. The card is placed by layout, not by asking the compositor
to move the toplevel: Wayland never lets an app position its own
window, so the old move() centering silently did nothing there and the
window landed wherever KWin wanted.

The process is resident: the first launch opens the window and stays
around, later ones flip it over a unix socket (toggle.py). Closing the
window hides it, so the next keybind press is a repaint, not a start.
On KWin the window is a layer surface (wayland.py), which keeps it out
of the taskbar and alt-tab without changing its look.

Caps lock cycles the six Maid Scroll palettes and stores the pick; the
window and the shipped themes stay one family.
"""

import os

from PyQt6.QtCore import QObject, QSocketNotifier, Qt
from PyQt6.QtGui import QColor, QIcon, QPainter, QPalette
from PyQt6.QtWidgets import (QApplication, QDialog, QFrame,
                             QGraphicsDropShadowEffect, QHBoxLayout, QLabel,
                             QLineEdit, QListWidget, QListWidgetItem,
                             QStackedWidget, QStyleFactory, QVBoxLayout,
                             QWidget)

from . import toggle
from .palettes import PALETTES, index_of, load, save
from .suite import any_installed
from .wayland import attach_layer
from .sources.apps import AppsSource, categories_present, load_apps
from .sources.calc import CalcSource
from .sources.files import FileIndex, FilesSource
from .sources.maid import MaidSource
from .sources.run import RunSource
from .sources.web import WebSource

# Subtitle policy: "maid" (subtitles only on Maid rows), "all", "none".
# Override locally with MAID_RUNNER_SUBTITLES; the repo default stays.
SUBTITLE_MODE = os.environ.get("MAID_RUNNER_SUBTITLES", "maid")

# The card is the visible "box"; clamped down on tiny screens.
CARD_W, CARD_H = 640, 470
# Backdrop dim over the desktop; translucent, wallpaper reads through.
BACKDROP = QColor(10, 11, 18, 120)

HINT = "tab switch  ·  shift+tab back  ·  enter run  ·  esc close  ·  caps lock: {}"


def _rgba(hex_color, alpha):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f"rgba({r}, {g}, {b}, {round(alpha * 255)})"


def _style(p):
    """One palette as the window stylesheet; borders derive from it."""
    return f"""
QFrame#card {{ background-color: {p['bg']}; border: 1px solid {_rgba(p['muted'], 0.35)}; border-radius: 18px; }}
QLineEdit#search {{ background-color: {p['bg_alt']}; border: 1px solid {_rgba(p['muted'], 0.35)};
    border-radius: 12px; padding: 12px 16px; font-size: 16px; color: {p['fg']};
    selection-background-color: {p['accent']}; selection-color: {p['bg']}; }}
QLineEdit#search:focus {{ border-color: {p['accent']}; }}
QLabel#source {{ color: {p['accent']}; font-size: 12px; font-weight: 600; }}
QLabel#hint {{ color: {p['muted']}; font-size: 11px; }}
QLabel#empty {{ color: {p['muted']}; font-size: 14px; }}
QLabel#title {{ color: {p['fg']}; font-size: 15px; }}
QLabel#sub {{ color: {p['muted']}; font-size: 12px; }}
QListWidget#list {{ background: transparent; border: none; outline: 0; padding: 2px; }}
QListWidget#list::item {{ border: 1px solid transparent; border-radius: 10px; margin: 1px 4px; }}
QListWidget#list::item:hover {{ background-color: {_rgba(p['fg'], 0.06)}; border-color: {_rgba(p['muted'], 0.3)}; }}
QListWidget#list::item:selected {{ background-color: {_rgba(p['accent'], 0.15)}; border-color: {p['accent']}; }}
"""


class RunnerWindow(QDialog):
    def __init__(self, files_index=None):
        super().__init__()
        self.setWindowTitle("Maid Runner")
        # Match the installed desktop entry's Icon= so the taskbar and
        # window list show the search glyph instead of a generic one.
        self.setWindowIcon(QIcon.fromTheme(
            "system-search", QIcon.fromTheme("application-x-executable")))
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.FramelessWindowHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

        # The process is resident (main() keeps it alive); the index is
        # shared with the service so a daemon started at login has the
        # file list warm by the time the first toggle arrives.
        self._files = files_index if files_index is not None else FileIndex()
        apps = load_apps()
        self.sources = [AppsSource(apps)]
        for category in categories_present(apps):
            self.sources.append(AppsSource(apps, category=category))
        # The Maid tab drives the other tools, so it only earns its
        # place when at least one of them is installed - the suite is
        # independent tool by tool. It sits where the app manager keeps
        # its Maid group: among the categories, just before Development.
        if any_installed():
            pos = next((i for i, s in enumerate(self.sources)
                        if s.name == "Development"), len(self.sources))
            self.sources.insert(pos, MaidSource())
        self.sources += [FilesSource(self._files), RunSource(apps),
                         CalcSource(), WebSource()]
        self.source_idx = 0
        self.theme_idx = index_of(load())
        self.rows = []

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.addStretch(1)
        mid = QHBoxLayout()
        mid.addStretch(1)
        self.card = QFrame(self)
        self.card.setObjectName("card")
        avail = QApplication.primaryScreen().availableGeometry()
        self.card.setFixedSize(min(CARD_W, max(320, avail.width() - 80)),
                               min(CARD_H, max(240, avail.height() - 80)))
        shadow = QGraphicsDropShadowEffect(self.card)
        shadow.setBlurRadius(48)
        shadow.setOffset(0, 10)
        shadow.setColor(QColor(0, 0, 0, 170))
        self.card.setGraphicsEffect(shadow)
        mid.addWidget(self.card)
        mid.addStretch(1)
        root.addLayout(mid)
        root.addStretch(1)

        lay = QVBoxLayout(self.card)
        lay.setContentsMargins(16, 16, 16, 14)
        lay.setSpacing(10)

        self.search = QLineEdit(self.card)
        self.search.setObjectName("search")
        self.search.setPlaceholderText("Type to search")
        self.search.textChanged.connect(self.refresh)
        lay.addWidget(self.search)

        head = QHBoxLayout()
        head.setContentsMargins(4, 0, 4, 0)
        self.source_label = QLabel(self.card)
        self.source_label.setObjectName("source")
        self.hint = QLabel(self.card)
        self.hint.setObjectName("hint")
        head.addWidget(self.source_label)
        head.addStretch(1)
        head.addWidget(self.hint)
        lay.addLayout(head)

        self.list = QListWidget(self.card)
        self.list.setObjectName("list")
        # The search box owns the keyboard. If the list could take focus,
        # Qt would eat TAB for focus traversal and it would never reach
        # keyPressEvent - that was the TAB-does-nothing bug.
        self.list.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.list.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list.itemActivated.connect(self.run_current)
        self.empty = QLabel(self.card)
        self.empty.setObjectName("empty")
        self.empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.stack = QStackedWidget(self.card)
        self.stack.addWidget(self.list)
        self.stack.addWidget(self.empty)
        lay.addWidget(self.stack, 1)

        self.refresh()
        self.apply_theme()

        # Give the window its handle, then aim it at a layer surface
        # where the session takes one: on KWin that is what keeps it out
        # of the taskbar and alt-tab. attach_layer() returns False and
        # changes nothing where there is no layer shell; showFullScreen()
        # sizes the window correctly in both cases.
        self.winId()
        attach_layer(self.windowHandle())

    def pop_up(self):
        """Bring the window up ready for typing (the keybind path)."""
        self._files.refresh()
        if self.search.text():
            self.search.clear()  # textChanged refreshes the list
        else:
            self.refresh()
        self.showFullScreen()
        self.search.setFocus()

    def apply_theme(self):
        name, p = PALETTES[self.theme_idx]
        self.setStyleSheet(_style(p))
        pal = self.search.palette()
        pal.setColor(QPalette.ColorRole.PlaceholderText, QColor(p["muted"]))
        self.search.setPalette(pal)
        self.hint.setText(HINT.format(name))

    def mousePressEvent(self, event):  # noqa: N802
        # card widgets handle their own clicks; a press landing on the
        # dim backdrop closes.
        if not self.card.geometry().contains(event.position().toPoint()):
            self.close()
        else:
            super().mousePressEvent(event)

    def paintEvent(self, event):  # noqa: N802
        painter = QPainter(self)
        painter.fillRect(self.rect(), BACKDROP)
        painter.end()

    def keyPressEvent(self, event):  # noqa: N802
        key = event.key()
        if key == Qt.Key.Key_Escape:
            self.close()
        elif key in (Qt.Key.Key_Tab, Qt.Key.Key_Backtab):
            back = (key == Qt.Key.Key_Backtab
                    or bool(event.modifiers() & Qt.KeyboardModifier.ShiftModifier))
            self.source_idx = (self.source_idx + (-1 if back else 1)) % len(self.sources)
            self.refresh()
        elif key == Qt.Key.Key_CapsLock:
            self.theme_idx = (self.theme_idx + 1) % len(PALETTES)
            save(PALETTES[self.theme_idx][0])
            self.apply_theme()
        elif key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            self.run_current()
        elif key == Qt.Key.Key_Up:
            r = max(0, self.list.currentRow() - 1)
            self.list.setCurrentRow(r)
        elif key == Qt.Key.Key_Down:
            r = min(self.list.count() - 1, self.list.currentRow() + 1)
            self.list.setCurrentRow(r)
        else:
            super().keyPressEvent(event)

    def _row_widget(self, title, sub, icon, show_sub):
        w = QWidget()
        row = QHBoxLayout(w)
        row.setContentsMargins(12, 7, 12, 7)
        row.setSpacing(12)
        if icon:
            ico = QIcon.fromTheme(icon, QIcon.fromTheme("application-x-executable"))
            pm = ico.pixmap(30, 30)
            if not pm.isNull():
                pic = QLabel()
                pic.setObjectName("icon")
                pic.setPixmap(pm)
                pic.setFixedSize(30, 30)
                row.addWidget(pic)
        col = QVBoxLayout()
        col.setContentsMargins(0, 0, 0, 0)
        col.setSpacing(1)
        t = QLabel(title)
        t.setObjectName("title")
        col.addWidget(t)
        if show_sub and sub:
            s = QLabel(sub)
            s.setObjectName("sub")
            col.addWidget(s)
        row.addLayout(col, 1)
        return w

    def refresh(self):
        src = self.sources[self.source_idx]
        self.source_label.setText(src.name)
        if SUBTITLE_MODE == "all":
            show_sub = True
        elif SUBTITLE_MODE == "none":
            show_sub = False
        else:
            show_sub = getattr(src, "show_subtitles", False)
        query = self.search.text()
        self.rows = src.items(query)
        self.list.clear()
        for title, sub, icon, _payload in self.rows[:40]:
            item = QListWidgetItem()
            row = self._row_widget(title, sub, icon, show_sub)
            item.setSizeHint(row.sizeHint())
            self.list.addItem(item)
            self.list.setItemWidget(item, row)
        self.list.setCurrentRow(0)
        if self.rows:
            self.stack.setCurrentWidget(self.list)
        else:
            q = query.strip()
            self.empty.setText(f'no matches for "{q}"' if q else "type to search")
            self.stack.setCurrentWidget(self.empty)

    def run_current(self):
        row = self.list.currentRow()
        if 0 <= row < len(self.rows):
            _t, _s, _icon, payload = self.rows[row]
            if self.sources[self.source_idx].activate(payload):
                self.close()


class Service(QObject):
    """The resident side: one socket, one window, built lazily.

    A service start (autostart at login) should cost nothing until
    somebody looks at it, and the first window build is the only slow
    one. So the window appears on the first show, and hide/show after
    that is a repaint, not a start.
    """

    def __init__(self, app, listener):
        super().__init__(app)
        self._app = app
        self._listener = listener
        self._win = None
        self._files = FileIndex()
        self._files.start()
        self._notifier = QSocketNotifier(listener.fileno(),
                                         QSocketNotifier.Type.Read, self)
        self._notifier.activated.connect(self._accept)
        app.aboutToQuit.connect(self._close)

    def window(self):
        if self._win is None:
            self._win = RunnerWindow(files_index=self._files)
        return self._win

    def show_window(self):
        self.window().pop_up()

    def toggle(self):
        win = self._win
        if win is not None and win.isVisible():
            win.hide()
        else:
            self.show_window()

    def _accept(self):
        try:
            conn, _addr = self._listener.accept()
        except OSError:
            return
        # One word arrives per connection; the short deadline is for
        # clients that die mid-sentence, not for the word itself.
        conn.settimeout(0.2)
        data = b""
        try:
            while b"\n" not in data and len(data) < 64:
                chunk = conn.recv(64)
                if not chunk:
                    break
                data += chunk
        except OSError:
            pass
        conn.close()
        word = data.decode("ascii", "replace").strip()
        if word == "show":
            self.show_window()
        elif word == "toggle":
            self.toggle()
        elif word == "quit":
            self._app.quit()

    def _close(self):
        self._listener.close()
        try:
            os.unlink(toggle.socket_path())
        except OSError:
            pass


def main(argv=None):
    """Open the window, or talk to the instance that already has it.

    Plain runs show; ``--toggle`` flips it (keybind); ``--service``
    starts hidden and waits (autostart); ``--quit`` stops the resident
    instance. One instance owns the window; every other launch hands
    over one word over a unix socket and exits without waking Qt.
    """
    import sys
    args = list(sys.argv[1:] if argv is None else argv)
    mode = "show"
    for flag, name in (("--toggle", "toggle"), ("--service", "service"),
                       ("--quit", "quit")):
        if flag in args:
            mode = name
            break

    if mode == "quit":
        if toggle.send("quit"):
            return 0
        print("maid-runner: nothing to quit", file=sys.stderr)
        return 1

    # The socket is bound before Qt starts, so two launches racing at
    # the same moment cannot both decide to become the instance.
    if mode != "service" and toggle.send(mode):
        return 0
    listener = toggle.listen()
    if listener is None:
        # A service request that finds an instance already running is
        # simply done; show/toggle slipped in between send and bind and
        # gets one more try.
        if mode != "service":
            toggle.send(mode)
        return 0

    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("Maid Runner")
    app.setOrganizationName("Maidware Project")
    # Wayland app_id: name the desktop file so the compositor matches
    # maid-runner.desktop (its icon, its grouping) instead of guessing
    # from the window title.
    app.setDesktopFileName("maid-runner")
    # Closing the window hides it; the process outlives it on purpose.
    app.setQuitOnLastWindowClosed(False)
    # Fusion renders the Maid stylesheet predictably on every desktop;
    # system style stays untouched for everything else.
    fusion = QStyleFactory.create("Fusion")
    if fusion is not None:
        app.setStyle(fusion)

    service = Service(app, listener)
    if mode != "service":
        service.show_window()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
