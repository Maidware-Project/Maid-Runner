r"""Maid Runner window: one search box, TAB cycles sources.

The window is a fullscreen dim overlay with the search card centered
inside it (the rofi look). The card is placed by layout, not by asking
the compositor to move the toplevel: Wayland never lets an app position
its own window, so the old move() centering silently did nothing there
and the window landed wherever KWin wanted.
"""

import os

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QIcon, QPainter, QPalette
from PyQt6.QtWidgets import (QApplication, QDialog, QFrame,
                             QGraphicsDropShadowEffect, QHBoxLayout, QLabel,
                             QLineEdit, QListWidget, QListWidgetItem,
                             QStackedWidget, QStyleFactory, QVBoxLayout,
                             QWidget)

from .sources.apps import AppsSource
from .sources.calc import CalcSource
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

STYLE = """
QFrame#card { background-color: #1a1b26; border: 1px solid #2b3049; border-radius: 18px; }
QLineEdit#search { background-color: #24283b; border: 1px solid #343b58; border-radius: 12px;
    padding: 12px 16px; font-size: 16px; color: #c0caf5;
    selection-background-color: #5cb9ae; selection-color: #1a1b26; }
QLineEdit#search:focus { border-color: #5cb9ae; }
QLabel#source { color: #5cb9ae; font-size: 12px; font-weight: 600; }
QLabel#hint { color: #565f89; font-size: 11px; }
QLabel#empty { color: #565f89; font-size: 14px; }
QLabel#title { color: #c0caf5; font-size: 15px; }
QLabel#sub { color: #565f89; font-size: 12px; }
QListWidget#list { background: transparent; border: none; outline: 0; padding: 2px; }
QListWidget#list::item { border: 1px solid transparent; border-radius: 10px; margin: 1px 4px; }
QListWidget#list::item:hover { background-color: #202337; border-color: #2b3049; }
QListWidget#list::item:selected { background-color: #223047; border-color: #5cb9ae; }
"""

HINT = "tab switch  ·  shift+tab back  ·  enter run  ·  esc close"


class RunnerWindow(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Maid Runner")
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.FramelessWindowHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setStyleSheet(STYLE)

        self.sources = [AppsSource(), MaidSource(), RunSource(),
                        CalcSource(), WebSource()]
        self.source_idx = 0
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
        pal = self.search.palette()
        pal.setColor(QPalette.ColorRole.PlaceholderText, QColor("#565f89"))
        self.search.setPalette(pal)
        self.search.textChanged.connect(self.refresh)
        lay.addWidget(self.search)

        head = QHBoxLayout()
        head.setContentsMargins(4, 0, 4, 0)
        self.source_label = QLabel(self.card)
        self.source_label.setObjectName("source")
        hint = QLabel(HINT, self.card)
        hint.setObjectName("hint")
        head.addWidget(self.source_label)
        head.addStretch(1)
        head.addWidget(hint)
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

    def mousePressEvent(self, event):  # noqa: N802
        # card widgets handle their own clicks; a press landing on the
        # dim backdrop closes, the way rofi behaves.
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


def main():
    import sys
    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("Maid Runner")
    app.setOrganizationName("Maidware Project")
    # Fusion renders the Maid stylesheet predictably on every desktop;
    # system style stays untouched for everything else.
    fusion = QStyleFactory.create("Fusion")
    if fusion is not None:
        app.setStyle(fusion)
    win = RunnerWindow()
    win.showFullScreen()
    win.search.setFocus()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
