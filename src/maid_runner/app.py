"""Maid Runner window: one search box, TAB cycles sources."""

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import (QApplication, QDialog, QHBoxLayout, QLabel,
                             QLineEdit, QListWidget, QListWidgetItem,
                             QVBoxLayout, QWidget, QStyleFactory)

from .sources.apps import AppsSource
from .sources.calc import CalcSource
from .sources.maid import MaidSource
from .sources.run import RunSource
from .sources.web import WebSource

# Subtitle policy: "maid" (subtitles only on Maid rows), "all", "none".
# Override locally with MAID_RUNNER_SUBTITLES; the repo default stays.
import os
SUBTITLE_MODE = os.environ.get("MAID_RUNNER_SUBTITLES", "maid")

STYLE = """
QWidget { background-color: #1a1b26; color: #c0caf5; selection-background-color: #5cb9ae; selection-color: #1a1b26; }
QLineEdit { background-color: #24283b; border: 1px solid #488985; border-radius: 10px;
    padding: 12px 14px; font-size: 15px; color: #c0caf5; selection-background-color: #5cb9ae; }
QListWidget { background-color: #1a1b26; border: none; outline: 0; }
QListWidget::item { padding: 2px; border: none; }
QListWidget::item:selected { background-color: #24283b; border-radius: 8px; }
QLabel#source { color: #565f89; font-size: 12px; }
QLabel#title { color: #c0caf5; font-size: 15px; }
QLabel#sub { color: #565f89; font-size: 12px; }
QLabel#icon { background-color: transparent; }
"""


class RunnerWindow(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Maid Runner")
        # dialog windows center on screen under KWin; plain widgets do not
        self.setWindowFlags(Qt.WindowType.Dialog | Qt.WindowType.FramelessWindowHint)
        self.setFixedSize(600, 430)
        self.setStyleSheet(STYLE)

        self.sources = [AppsSource(), MaidSource(), RunSource(),
                        CalcSource(), WebSource()]
        self.source_idx = 0
        self.rows = []

        lay = QVBoxLayout(self)
        lay.setContentsMargins(14, 14, 14, 14)
        lay.setSpacing(8)
        self.search = QLineEdit(self)
        self.search.setPlaceholderText("Type to search - TAB switches source, Enter runs")
        self.search.textChanged.connect(self.refresh)
        lay.addWidget(self.search)
        self.source_label = QLabel(self)
        self.source_label.setObjectName("source")
        lay.addWidget(self.source_label)
        self.list = QListWidget(self)
        self.list.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.list.itemActivated.connect(self.run_current)
        lay.addWidget(self.list)

        screen = QApplication.primaryScreen().availableGeometry()
        self.move(int(screen.center().x() - self.width() // 2),
                  int(screen.center().y() - self.height() // 2))
        self.refresh()

    def keyPressEvent(self, event):  # noqa: N802
        key = event.key()
        if key == Qt.Key.Key_Escape:
            self.close()
        elif key == Qt.Key.Key_Tab:
            self.source_idx = (self.source_idx + 1) % len(self.sources)
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

    def refresh(self):
        src = self.sources[self.source_idx]
        self.source_label.setText(f"{src.name} - TAB for next")
        if SUBTITLE_MODE == "all":
            show_sub = True
        elif SUBTITLE_MODE == "none":
            show_sub = False
        else:
            show_sub = getattr(src, "show_subtitles", False)
        self.rows = src.items(self.search.text())
        self.list.clear()
        for title, sub, icon, _payload in self.rows[:40]:
            item = QListWidgetItem()
            w = QWidget()
            row = QHBoxLayout(w)
            row.setContentsMargins(10, 6, 10, 6)
            row.setSpacing(10)
            if icon:
                pic = QLabel()
                pic.setObjectName("icon")
                pm = QIcon.fromTheme(icon).pixmap(28, 28)
                if not pm.isNull():
                    pic.setPixmap(pm)
                    pic.setFixedSize(28, 28)
                    row.addWidget(pic)
            col = QVBoxLayout()
            col.setContentsMargins(0, 0, 0, 0)
            col.setSpacing(0)
            t = QLabel(title)
            t.setObjectName("title")
            col.addWidget(t)
            if show_sub and sub:
                s = QLabel(sub)
                s.setObjectName("sub")
                col.addWidget(s)
            row.addLayout(col, 1)
            item.setSizeHint(w.sizeHint())
            self.list.addItem(item)
            self.list.setItemWidget(item, w)
        self.list.setCurrentRow(0)

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
    win.show()
    win.search.setFocus()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
