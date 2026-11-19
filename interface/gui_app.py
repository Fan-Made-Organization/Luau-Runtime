from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QFont
from PySide6.QtWidgets import (
    QApplication, QFrame, QLabel, QLineEdit, QMainWindow, QPushButton,
    QScrollArea, QSizePolicy, QWidget,
)

ROOT = Path(__file__).resolve().parents[1]
LUAU = Path(os.environ.get("FMO_LUAU_PATH", Path.home() / "luau/build/luau")).expanduser()


def number(value, fallback=0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return fallback


def color(value, fallback="#252936"):
    if isinstance(value, list) and len(value) >= 3:
        return QColor(*(max(0, min(255, int(number(v)))) for v in value[:3]))
    if isinstance(value, dict):
        values = [value.get(str(i), 0) for i in range(1, 4)]
        return QColor(*(max(0, min(255, int(number(v) * 255 if number(v) <= 1 else number(v)))) for v in values))
    return QColor(fallback)


def dimensions(value, default=(180, 40)):
    if not isinstance(value, list) or len(value) < 4:
        return default
    return (max(1, int(number(value[1], default[0]))),
            max(1, int(number(value[3], default[1]))))


def position(value):
    if not isinstance(value, list) or len(value) < 4:
        return (12, 12)
    return (int(number(value[1])), int(number(value[3])))


class GuiRenderer:
    def __init__(self, parent: QWidget):
        self.parent = parent

    def render_children(self, parent_widget, children):
        for node in children:
            self.render_node(parent_widget, node)

    def render_node(self, parent_widget, node):
        props = node.get("properties", {})
        kind = props.get("ClassName", "Frame")
        if props.get("Visible") is False:
            return

        if kind == "TextButton":
            widget = QPushButton(str(props.get("Text", "Button")), parent_widget)
            widget.setCursor(Qt.CursorShape.PointingHandCursor)
            widget.setStyleSheet(
                f"QPushButton {{ background: {color(props.get('BackgroundColor3')).name()};"
                f" color: {color(props.get('TextColor3'), '#ffffff').name()};"
                " border: 0; border-radius: 7px; padding: 6px 12px; }"
                "QPushButton:hover { border: 1px solid #8aa8ff; }"
            )
        elif kind == "TextBox":
            widget = QLineEdit(str(props.get("Text", "")), parent_widget)
            widget.setPlaceholderText(str(props.get("PlaceholderText", "")))
            widget.setStyleSheet("QLineEdit { background:#303747; color:#f2f4fa; border:1px solid #4a5367; border-radius:6px; padding:7px; }")
        elif kind == "TextLabel":
            widget = QLabel(str(props.get("Text", "Label")), parent_widget)
            widget.setWordWrap(True)
            widget.setStyleSheet(f"color:{color(props.get('TextColor3'), '#f0f0f5').name()}; background:transparent;")
        elif kind in ("Frame", "ScrollingFrame"):
            widget = QFrame(parent_widget)
            widget.setStyleSheet(f"background:{color(props.get('BackgroundColor3')).name()}; border:0;")
            if kind == "ScrollingFrame":
                scroll = QScrollArea(parent_widget)
                scroll.setWidgetResizable(False)
                scroll.setStyleSheet("QScrollArea { border:0; background:transparent; }")
                content = QWidget()
                content.resize(*dimensions(props.get("CanvasSize"), (260, 320)))
                scroll.setWidget(content)
                widget.deleteLater()
                widget = scroll
                child_parent = content
            else:
                child_parent = widget
        else:
            return

        width, height = dimensions(props.get("Size"), (180, 40))
        x, y = position(props.get("Position"))
        widget.setGeometry(x, y, width, height)
        widget.show()
        if kind not in ("ScrollingFrame",):
            child_parent = widget
        self.render_children(child_parent, node.get("children", []))


class SimulatorWindow(QMainWindow):
    def __init__(self, snapshot_path: Path, script_path: Path):
        super().__init__()
        self.setWindowTitle(f"FMO Script GUI Simulator — {script_path.name}")
        self.resize(900, 650)
        self.setMinimumSize(560, 420)
        self.setStyleSheet("QMainWindow { background:#171a22; }")
        self.canvas = QWidget()
        self.canvas.setStyleSheet("background:#202430;")
        self.setCentralWidget(self.canvas)
        data = json.loads(snapshot_path.read_text(encoding="utf-8"))
        self.setWindowTitle(f"FMO Script GUI Simulator — {data.get('properties', {}).get('Name', script_path.stem)}")
        self.renderer = GuiRenderer(self.canvas)
        self.renderer.render_children(self.canvas, data.get("children", []))


def run_script(script: Path, snapshot: Path):
    if not LUAU.is_file():
        raise RuntimeError(f"Luau CLI not found: {LUAU}\nSet FMO_LUAU_PATH to your Luau executable.")
    result = subprocess.run(
        [str(LUAU), str(script)], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=20,
    )
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    if result.returncode:
        raise RuntimeError(f"Script exited with code {result.returncode}")
    if not snapshot.is_file():
        raise RuntimeError(
            "The script did not export a GUI snapshot. See scripts/gui_demo.luau "
            "for the required GuiBridge.Export(root, path) call."
        )


def main():
    script = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else ROOT / "scripts/gui_demo.luau"
    if not script.is_absolute():
        script = (ROOT / script).resolve()
    if not script.is_file():
        print(f"Script not found: {script}", file=sys.stderr)
        return 2

    app = QApplication(sys.argv[:1])
    app.setApplicationName("FMO Script GUI Simulator")
    snapshot = ROOT / ".fmo_gui_snapshot.json"
    try:
        run_script(script, snapshot)
        window = SimulatorWindow(snapshot, script)
        window.show()
        return app.exec()
    except Exception as error:
        print(f"[FMO GUI] {error}", file=sys.stderr)
        return 1
    finally:
        snapshot.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
