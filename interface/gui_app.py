from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication, QMainWindow, QStatusBar, QWidget

from .gui_renderer import GuiRenderer

ROOT = Path(__file__).resolve().parents[1]
LUAU = Path(os.environ.get("FMO_LUAU_PATH", Path.home() / "luau/build/luau")).expanduser()
SNAPSHOT_MARKER = "__FMO_GUI_SNAPSHOT__"


def lua_string(value: str) -> str:
    return '"' + "".join(f"\\x{byte:02X}" for byte in value.encode("utf-8")) + '"'


def bridge_require_path(script: Path) -> str:
    module = Path(os.path.relpath(ROOT / "simulator" / "gui_bridge.lua", script.parent)).with_suffix("")
    value = module.as_posix()
    if not value.startswith("."):
        value = "./" + value
    return value


class SimulatorWindow(QMainWindow):
    def __init__(self, data: dict, script_path: Path):
        super().__init__()
        self.script_path = script_path
        self._current_data = data
        self._refreshing = False
        self._resize_pending = False
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
        self._refreshing = True
        self._current_data = data
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
        self._refreshing = False

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if self._refreshing or self._resize_pending or not hasattr(self, "_current_data"):
            return
        self._resize_pending = True
        QTimer.singleShot(80, self._rerender_after_resize)

    def _rerender_after_resize(self):
        self._resize_pending = False
        if self.isVisible() and not self._refreshing:
            self.refresh(self._current_data)

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
