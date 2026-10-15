"""Maid Runner window: one search box, TAB cycles sources."""

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (QApplication, QHBoxLayout, QLabel, QLineEdit,
                             QListWidget, QListWidgetItem, QVBoxLayout,
                             QWidget)

from .sources.apps import AppsSource
from .sources.calc import CalcSource
from .sources.maid import MaidSource
from .sources.run import RunSource
from .sources.web import WebSource

STYLE = """
QWidget { background-color: #181818; color: #ECECEC; font-size: 15px; }
QLineEdit { background-color: #242424; border: 1px solid #EFA8C4;
    border-radius: 8px; padding: 10px 14px; selection-background-color: #EFA8C4; }
QListWidget { background-color: #121212; border: none; outline: 0; }
QListWidget::item { padding: 2px; border: none; }
QListWidget::item:selected { background-color: #2E2E2E; border-radius: 6px; }
QLabel#source { color: #757575; font-size: 12px; }
QLabel#title { color: #ECECEC; font-size: 15px; }
QLabel#sub { color: #9A9A9A; font-size: 12px; }
"""


class RunnerWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Maid Runner")
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint)
        self.resize(600, 430)
        self.setStyleSheet(STYLE)

        self.sources = [AppsSource(), MaidSource(), RunSource(),
                        CalcSource(), WebSource()]
        self.source_idx = 0
        self.rows = []

        lay = QVBoxLayout(self)
        lay.setContentsMargins(14, 14, 14, 14)
        lay.setSpacing(8)
        self.search = QLineEdit(self)
        self.search.setPlaceholderText("Type to search — TAB switches source, Enter runs")
        self.search.textChanged.connect(self.refresh)
        lay.addWidget(self.search)
        self.source_label = QLabel(self)
        self.source_label.setObjectName("source")
        lay.addWidget(self.source_label)
        self.list = QListWidget(self)
        self.list.itemActivated.connect(self.run_current)
        lay.addWidget(self.list)

        screen = QApplication.primaryScreen().availableGeometry()
        self.move(screen.center().x() - 300,
                 screen.center().y() - 215)
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
        self.source_label.setText(f"{src.name} — TAB for next")
        self.rows = src.items(self.search.text())
        self.list.clear()
        for title, sub, _payload in self.rows[:40]:
            item = QListWidgetItem()
            w = QWidget()
            lay = QVBoxLayout(w)
            lay.setContentsMargins(10, 6, 10, 6)
            lay.setSpacing(0)
            t = QLabel(title)
            t.setObjectName("title")
            lay.addWidget(t)
            if sub:
                s = QLabel(sub)
                s.setObjectName("sub")
                lay.addWidget(s)
            item.setSizeHint(w.sizeHint())
            self.list.addItem(item)
            self.list.setItemWidget(item, w)
        self.list.setCurrentRow(0)

    def run_current(self):
        row = self.list.currentRow()
        if 0 <= row < len(self.rows):
            _t, _s, payload = self.rows[row]
            if self.sources[self.source_idx].activate(payload):
                self.close()


def main():
    import sys
    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("Maid Runner")
    app.setOrganizationName("Maidware Project")
    win = RunnerWindow()
    win.show()
    win.search.setFocus()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
