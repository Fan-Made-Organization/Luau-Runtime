from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (
    QApplication, QFrame, QLabel, QLineEdit, QMainWindow, QPushButton,
    QScrollArea, QStatusBar, QWidget,
)

ROOT = Path(__file__).resolve().parents[1]
LUAU = Path(os.environ.get("FMO_LUAU_PATH", Path.home() / "luau/build/luau")).expanduser()
SNAPSHOT_MARKER = "__FMO_GUI_SNAPSHOT__"


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


def _udim_component(scale, offset, parent_extent, fallback):
    return int(round(number(scale) * parent_extent + number(offset, fallback)))


def dimensions(value, default=(180, 40), parent_size=(900, 650)):
    if not isinstance(value, list) or len(value) < 4:
        return default
    return (
        max(1, _udim_component(value[0], value[1], parent_size[0], default[0])),
        max(1, _udim_component(value[2], value[3], parent_size[1], default[1])),
    )


def position(value, parent_size=(900, 650)):
    if not isinstance(value, list) or len(value) < 4:
        return (12, 12)
    return (
        _udim_component(value[0], value[1], parent_size[0], 12),
        _udim_component(value[2], value[3], parent_size[1], 12),
    )


def lua_string(value: str) -> str:
    return '"' + "".join(f"\\x{byte:02X}" for byte in value.encode("utf-8")) + '"'


def bridge_require_path(script: Path) -> str:
    module = Path(os.path.relpath(ROOT / "simulator" / "gui_bridge.lua", script.parent)).with_suffix("")
    value = module.as_posix()
    if not value.startswith("."):
        value = "./" + value
    return value


class GuiRenderer:
    def __init__(self, parent: QWidget, event_handler):
        self.parent = parent
        self.event_handler = event_handler
        self.created = 0
        self.skipped = 0

    def debug(self, message: str):
        print(f"[FMO GUI DEBUG] {message}", flush=True)

    def render_children(self, parent_widget, children):
        for node in children:
            self.render_node(parent_widget, node)

    def render_node(self, parent_widget, node):
        props = node.get("properties", {})
        kind = props.get("ClassName", "Frame")
        node_id = node.get("id", "<sin-id>")
        if props.get("Visible") is False:
            self.skipped += 1
            self.debug(f"SKIP id={node_id} class={kind} reason=VisibleFalse")
            return

        if kind == "TextButton":
            widget = QPushButton(str(props.get("Text", "Button")), parent_widget)
            widget.setCursor(Qt.CursorShape.PointingHandCursor)
            widget.setEnabled(props.get("Enabled", True) is not False)
            widget.setStyleSheet(
                f"QPushButton {{ background:{color(props.get('BackgroundColor3')).name()};"
                f" color:{color(props.get('TextColor3'), '#ffffff').name()};"
                " border:0; border-radius:7px; padding:6px 12px; }"
                "QPushButton:hover { border:1px solid #8aa8ff; }"
                "QPushButton:disabled { background:#454957; color:#a0a4ad; }"
            )
            instance_id = node.get("id")
            if instance_id:
                widget.clicked.connect(
                    lambda checked=False, target=instance_id:
                    self.event_handler(target, "click", None)
                )
        elif kind == "TextBox":
            widget = QLineEdit(str(props.get("Text", "")), parent_widget)
            widget.setPlaceholderText(str(props.get("PlaceholderText", "")))
            widget.setEnabled(props.get("Enabled", True) is not False)
            widget.setStyleSheet(
                "QLineEdit { background:#303747; color:#f2f4fa;"
                " border:1px solid #4a5367; border-radius:6px; padding:7px; }"
            )
            instance_id = node.get("id")
            if instance_id:
                widget.editingFinished.connect(
                    lambda target=instance_id, field=widget:
                    self.event_handler(target, "text", field.text())
                )
        elif kind == "TextLabel":
            widget = QLabel(str(props.get("Text", "Label")), parent_widget)
            widget.setWordWrap(True)
            widget.setStyleSheet(
                f"color:{color(props.get('TextColor3'), '#f0f0f5').name()};"
                " background:transparent;"
            )
        elif kind == "Frame":
            widget = QFrame(parent_widget)
            widget.setStyleSheet(
                f"background:{color(props.get('BackgroundColor3')).name()}; border:0;"
            )
        elif kind == "ScrollingFrame":
            widget = QScrollArea(parent_widget)
            widget.setWidgetResizable(False)
            widget.setStyleSheet("QScrollArea { border:0; background:transparent; }")
            content = QWidget()
            content.resize(*dimensions(props.get("CanvasSize"), (260, 320)))
            widget.setWidget(content)
        else:
            self.skipped += 1
            self.debug(f"SKIP id={node_id} class={kind} reason=UnsupportedClass")
            return

        parent_size = (max(1, parent_widget.width()), max(1, parent_widget.height()))
        width, height = dimensions(props.get("Size"), (180, 40), parent_size)
        x, y = position(props.get("Position"), parent_size)
        widget.setGeometry(x, y, width, height)
        self.created += 1
        self.debug(
            f"CREATE id={node_id} class={kind} parent={parent_size[0]}x{parent_size[1]} "
            f"geometry=({x},{y},{width},{height}) children={len(node.get('children', []))}"
        )
        if kind == "Frame":
            widget.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        widget.show()
        widget.raise_()

        child_parent = widget.widget() if kind == "ScrollingFrame" else widget
        self.render_children(child_parent, node.get("children", []))


class SimulatorWindow(QMainWindow):
    def __init__(self, data: dict, script_path: Path):
        super().__init__()
        self.script_path = script_path
        self.setWindowTitle(
            f"FMO Script GUI Simulator — {data.get('properties', {}).get('Name', script_path.stem)}"
        )
        self.resize(900, 650)
        self.setMinimumSize(560, 420)
        self.setStyleSheet("QMainWindow { background:#171a22; }")
        self.canvas = QWidget()
        self.canvas.setStyleSheet("background:#202430;")
        self.setCentralWidget(self.canvas)
        self.setStatusBar(QStatusBar(self))
        self.refresh(data)

    def refresh(self, data: dict):
        # Replace the complete render surface instead of detaching individual
        # descendants. This prevents stale parent widgets from covering the
        # refreshed tree after a Luau callback.
        previous_canvas = self.canvas
        self.canvas = QWidget()
        self.canvas.setObjectName("FmoGuiCanvas")
        self.canvas.setStyleSheet(
            "QWidget#FmoGuiCanvas { background:#202430; }"
        )
        self.setCentralWidget(self.canvas)
        self.renderer = GuiRenderer(self.canvas, self.dispatch_event)

        root_properties = data.get("properties", {})
        children = data.get("children", [])

        counts = {}
        total = 0
        def inspect_tree(nodes):
            nonlocal total
            for item in nodes if isinstance(nodes, list) else []:
                item_props = item.get("properties", {})
                item_class = item_props.get("ClassName", "<sin-clase>")
                counts[item_class] = counts.get(item_class, 0) + 1
                total += 1
                inspect_tree(item.get("children", []))

        inspect_tree(children)
        self.renderer.debug(
            f"SNAPSHOT root={root_properties.get('ClassName', '<sin-clase>')} "
            f"name={root_properties.get('Name', '<sin-nombre>')} "
            f"nodes={total} classes={counts} enabled={root_properties.get('Enabled', True)}"
        )
        if root_properties.get("Enabled", True) is not False:
            self.renderer.render_children(self.canvas, children)
        else:
            self.renderer.debug("ROOT SKIPPED reason=EnabledFalse")

        self.renderer.debug(
            f"RESULT created={self.renderer.created} skipped={self.renderer.skipped} "
            f"canvas={self.canvas.width()}x{self.canvas.height()}"
        )
        self.canvas.update()
        if previous_canvas is not self.canvas:
            previous_canvas.deleteLater()

    def dispatch_event(self, instance_id: str, event_name: str, value):
        try:
            data, output = run_script(
                self.script_path,
                event=(instance_id, event_name, value),
            )
            self.refresh(data)
            self.statusBar().showMessage(
                f"Evento Luau ejecutado: {event_name}" + (f" — {output[-1]}" if output else ""),
                5000,
            )
            for line in output:
                print(line)
        except Exception as error:
            self.statusBar().showMessage(f"Error del evento: {error}", 10000)
            print(f"[FMO GUI] {error}", file=sys.stderr)


def run_script(script: Path, event=None):
    if not LUAU.is_file():
        raise RuntimeError(
            f"Luau CLI not found: {LUAU}\nSet FMO_LUAU_PATH to your Luau executable."
        )

    execution_path = script
    temporary_path = None
    if event is not None:
        instance_id, event_name, value = event
        bridge_path = bridge_require_path(script)
        source = script.read_text(encoding="utf-8")
        prefix = f"local __FMO_GUI_BRIDGE = require({lua_string(bridge_path)})\ndo\n"
        suffix = (
            "\nend\n"
            f'print({lua_string(SNAPSHOT_MARKER)} .. '
            f"__FMO_GUI_BRIDGE.Dispatch({lua_string(instance_id)}, "
            f"{lua_string(event_name)}, {lua_string(value or '') if event_name == 'text' else 'nil'}))\n"
        )
        handle = tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".luau",
            prefix=".fmo_event_", dir=script.parent, delete=False,
        )
        with handle:
            handle.write(prefix)
            handle.write(source)
            handle.write(suffix)
        temporary_path = Path(handle.name)
        execution_path = temporary_path

    try:
        result = subprocess.run(
            [str(LUAU), str(execution_path)], cwd=ROOT,
            capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=20,
        )
    finally:
        if temporary_path:
            temporary_path.unlink(missing_ok=True)

    snapshot_data = None
    ordinary_output = []
    for line in result.stdout.splitlines():
        if line.startswith(SNAPSHOT_MARKER):
            import json
            try:
                snapshot_data = json.loads(line[len(SNAPSHOT_MARKER):])
            except json.JSONDecodeError as error:
                raise RuntimeError(f"Invalid GUI snapshot JSON: {error}") from error
        elif line:
            ordinary_output.append(line)

    if result.stderr:
        ordinary_output.extend(result.stderr.splitlines())
    if result.returncode:
        details = "\n".join(ordinary_output[-12:])
        raise RuntimeError(f"Script exited with code {result.returncode}" + (f":\n{details}" if details else ""))
    if snapshot_data is None:
        raise RuntimeError(
            "The script did not export a GUI snapshot. Add "
            'print("__FMO_GUI_SNAPSHOT__" .. GuiBridge.Export(screen)).'
        )
    return snapshot_data, ordinary_output


def main():
    script = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else ROOT / "scripts/gui_demo.luau"
    if not script.is_absolute():
        script = (ROOT / script).resolve()
    if not script.is_file():
        print(f"Script not found: {script}", file=sys.stderr)
        return 2

    app = QApplication(sys.argv[:1])
    app.setApplicationName("FMO Script GUI Simulator")
    try:
        data, output = run_script(script)
        for line in output:
            print(line)
        window = SimulatorWindow(data, script)
        window.show()
        return app.exec()
    except Exception as error:
        print(f"[FMO GUI] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
