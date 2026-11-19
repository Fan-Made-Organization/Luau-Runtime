"""Qt renderer for the FMO Luau GUI compatibility layer.

This is a local visual simulator. It intentionally does not download remote Roblox
assets or claim full Roblox engine compatibility.
"""
from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt, QRect, QSize
from PySide6.QtGui import QColor, QFont, QPainter, QPixmap, QIcon, QLinearGradient, QBrush, QPen
from PySide6.QtWidgets import (
    QWidget, QFrame, QPushButton, QLineEdit, QScrollArea, QLabel,
)


def number(value, fallback=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return float(fallback)


def qcolor(value, fallback="#252936"):
    if isinstance(value, (list, tuple)) and len(value) >= 3:
        return QColor(*(max(0, min(255, int(number(v)))) for v in value[:3]))
    if isinstance(value, dict):
        values = [value.get(str(i), 0) for i in range(1, 4)]
        return QColor(*(max(0, min(255, int(number(v) * 255 if number(v) <= 1 else number(v)))) for v in values))
    return QColor(fallback)


def udim(value, extent, default=0):
    if isinstance(value, (list, tuple)) and len(value) >= 2:
        return int(round(number(value[0]) * extent + number(value[1])))
    if isinstance(value, dict):
        return int(round(number(value.get("Scale", value.get("scale", 0))) * extent
                         + number(value.get("Offset", value.get("offset", default)))))
    return int(default)


def pair(value, fallback=(0, 0)):
    if isinstance(value, (list, tuple)) and len(value) >= 2:
        return value[0], value[1]
    return fallback


def dimensions(value, parent_size, fallback=(180, 40)):
    if isinstance(value, (list, tuple)) and len(value) >= 4:
        return (
            max(1, int(round(number(value[0]) * parent_size[0] + number(value[1])))),
            max(1, int(round(number(value[2]) * parent_size[1] + number(value[3])))),
        )
    return fallback


def position(value, parent_size):
    if isinstance(value, (list, tuple)) and len(value) >= 4:
        return (
            int(round(number(value[0]) * parent_size[0] + number(value[1]))),
            int(round(number(value[2]) * parent_size[1] + number(value[3]))),
        )
    return 12, 12


def _child_class(node):
    return node.get("properties", {}).get("ClassName", "")


def _style_modifiers(children):
    modifiers = {}
    for child in children:
        kind = _child_class(child)
        if kind in {"UICorner", "UIStroke", "UIGradient", "UIScale"}:
            modifiers[kind] = child.get("properties", {})
    return modifiers


def _gradient_css(props):
    gradient = props.get("UIGradient")
    if not gradient or gradient.get("Enabled", True) is False:
        return None
    colors = gradient.get("Color")
    if not isinstance(colors, list) or not colors:
        return None
    stops = []
    for index, entry in enumerate(colors):
        shade = qcolor(entry).name()
        stop = 0 if len(colors) == 1 else index / (len(colors) - 1)
        stops.append(f"stop:{stop:.3f} {shade}")
    rotation = number(gradient.get("Rotation", 0)) % 360
    # Qt stylesheet gradient coordinates are normalized; rotation is approximated
    # to the nearest cardinal direction to keep the stylesheet deterministic.
    directions = ["x1:0,y1:0,x2:1,y2:0", "x1:0,y1:1,x2:0,y2:0",
                  "x1:1,y1:0,x2:0,y2:0", "x1:0,y1:0,x2:0,y2:1"]
    direction = directions[int((rotation + 45) // 90) % 4]
    return f"qlineargradient({direction}, " + ", ".join(stops) + ")"


def _widget_style(props, children, fallback):
    mods = _style_modifiers(children)
    base = qcolor(props.get("BackgroundColor3"), fallback)
    transparency = max(0.0, min(1.0, number(props.get("BackgroundTransparency", 0))))
    base.setAlphaF(1.0 - transparency)
    background = base.name(QColor.NameFormat.HexArgb)
    gradient = _gradient_css(mods)
    if gradient:
        background = gradient

    stroke = mods.get("UIStroke", {})
    if stroke.get("Enabled", True) is False:
        stroke = {}
    border_width = max(0, int(number(stroke.get("Thickness", props.get("BorderSizePixel", 0)))))
    border_shade = qcolor(stroke.get("Color", props.get("BorderColor3")), "#59647a")
    border_shade.setAlphaF(max(0.0, min(1.0, 1.0 - number(stroke.get("Transparency", 0)))))
    border_color = border_shade.name(QColor.NameFormat.HexArgb)
    radius = 0
    corner = mods.get("UICorner", {})
    if corner:
        radius = max(0, udim(corner.get("CornerRadius"), 100, 0))
    return (
        f"background:{background}; border:{border_width}px solid {border_color}; "
        f"border-radius:{radius}px;"
    )


class FmoTextLabel(QWidget):
    def __init__(self, props, parent=None):
        super().__init__(parent)
        self.text = str(props.get("Text", "Label"))
        self.text_color = qcolor(props.get("TextColor3"), "#f0f0f5")
        self.font = QFont(self.font())
        self.font.setPointSize(max(1, int(number(props.get("TextSize", 14)))))
        self.font.setBold("bold" in str(props.get("Font", "")).lower())
        self.alignment = self._alignment(props)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)

    @staticmethod
    def _alignment(props):
        horizontal = {
            "left": Qt.AlignmentFlag.AlignLeft,
            "center": Qt.AlignmentFlag.AlignHCenter,
            "right": Qt.AlignmentFlag.AlignRight,
        }.get(str(props.get("TextXAlignment", "Left")).lower(), Qt.AlignmentFlag.AlignLeft)
        vertical = {
            "top": Qt.AlignmentFlag.AlignTop,
            "center": Qt.AlignmentFlag.AlignVCenter,
            "bottom": Qt.AlignmentFlag.AlignBottom,
        }.get(str(props.get("TextYAlignment", "Center")).lower(), Qt.AlignmentFlag.AlignVCenter)
        return horizontal | vertical

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)
        painter.setPen(self.text_color)
        painter.setFont(self.font)
        painter.drawText(self.rect().adjusted(2, 1, -2, -1),
                         self.alignment | Qt.TextFlag.TextWordWrap, self.text)


class FmoImageLabel(QWidget):
    def __init__(self, props, parent=None):
        super().__init__(parent)
        self.path = str(props.get("Image", ""))
        self.tint = qcolor(props.get("ImageColor3"), "#ffffff")
        self.transparency = max(0.0, min(1.0, number(props.get("ImageTransparency", 0))))
        self.scale_type = str(props.get("ScaleType", "Fit")).lower()
        self.pixmap = QPixmap(self.path) if self.path and Path(self.path).is_file() else QPixmap()
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        if self.pixmap.isNull():
            painter.setPen(QPen(QColor("#8993a8"), 1, Qt.PenStyle.DashLine))
            painter.drawRoundedRect(self.rect().adjusted(1, 1, -1, -1), 5, 5)
            painter.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter,
                             "Image unavailable\\n(local file paths only)")
            return
        target = self.rect()
        if self.scale_type in {"fit", "crop"}:
            mode = Qt.AspectRatioMode.KeepAspectRatio if self.scale_type == "fit" else Qt.AspectRatioMode.KeepAspectRatioByExpanding
            scaled = self.pixmap.scaled(target.size(), mode, Qt.TransformationMode.SmoothTransformation)
            x = (target.width() - scaled.width()) // 2
            y = (target.height() - scaled.height()) // 2
            painter.setOpacity(1.0 - self.transparency)
            painter.drawPixmap(x, y, scaled)
        else:
            painter.setOpacity(1.0 - self.transparency)
            painter.drawPixmap(target, self.pixmap)


class GuiRenderer:
    SUPPORTED = {
        "Frame", "ScrollingFrame", "TextLabel", "TextButton", "TextBox",
        "ImageLabel", "ImageButton",
    }

    def __init__(self, parent: QWidget, event_handler):
        self.parent = parent
        self.event_handler = event_handler
        self.created = 0
        self.skipped = 0
        self.warnings = []

    def debug(self, message):
        print(f"[FMO GUI DEBUG] {message}", flush=True)

    def _ordered(self, children, layout_props=None):
        items = [item for item in children if _child_class(item) in self.SUPPORTED]
        if layout_props and str(layout_props.get("SortOrder", "LayoutOrder")).lower() == "layoutorder":
            items.sort(key=lambda item: int(number(item.get("properties", {}).get("LayoutOrder", 0))))
        return items

    def _layout_geometry(self, parent, children, layout_node):
        if not layout_node:
            return {}
        layout_kind = _child_class(layout_node)
        props = layout_node.get("properties", {})
        items = self._ordered(children, props)
        width, height = max(1, parent.width()), max(1, parent.height())
        result = {}
        if layout_kind == "UIListLayout":
            vertical = str(props.get("FillDirection", "Vertical")).lower() != "horizontal"
            pad = udim(props.get("Padding"), height if vertical else width, 0)
            cursor = 0
            for item in items:
                size = dimensions(item.get("properties", {}).get("Size"), (width, height))
                w, h = size
                if vertical:
                    x = 0
                    align = str(props.get("HorizontalAlignment", "Left")).lower()
                    if align == "center": x = (width - w) // 2
                    elif align == "right": x = width - w
                    result[item.get("id")] = (x, cursor, w, h)
                    cursor += h + pad
                else:
                    y = 0
                    align = str(props.get("VerticalAlignment", "Top")).lower()
                    if align == "center": y = (height - h) // 2
                    elif align == "bottom": y = height - h
                    result[item.get("id")] = (cursor, y, w, h)
                    cursor += w + pad
        elif layout_kind == "UIGridLayout":
            cell_w, cell_h = dimensions(props.get("CellSize"), (width, height), (100, 80))
            pad_x, pad_y = dimensions(props.get("CellPadding"), (width, height), (8, 8))
            cols = max(1, (width + pad_x) // max(1, cell_w + pad_x))
            for index, item in enumerate(items):
                row, col = divmod(index, cols)
                result[item.get("id")] = (col * (cell_w + pad_x), row * (cell_h + pad_y), cell_w, cell_h)
        return result

    def render_children(self, parent_widget, children):
        modifiers = _style_modifiers(children)
        layout_node = next((child for child in children if _child_class(child) in {"UIListLayout", "UIGridLayout"}), None)
        layout = self._layout_geometry(parent_widget, children, layout_node)
        ordered = sorted(
            enumerate(children),
            key=lambda pair: (int(number(pair[1].get("properties", {}).get("ZIndex", 1))), pair[0]),
        )
        for _, node in ordered:
            kind = _child_class(node)
            if kind in {"UICorner", "UIStroke", "UIGradient", "UIScale", "UIListLayout", "UIGridLayout"}:
                continue
            self.render_node(parent_widget, node, layout.get(node.get("id")))

    def render_node(self, parent_widget, node, override_geometry=None):
        props = node.get("properties", {})
        kind = _child_class(node) or "Frame"
        node_id = node.get("id", "<sin-id>")
        if props.get("Visible") is False:
            self.skipped += 1
            self.debug(f"SKIP id={node_id} class={kind} reason=VisibleFalse")
            return
        if kind not in self.SUPPORTED:
            self.skipped += 1
            self.debug(f"SKIP id={node_id} class={kind} reason=UnsupportedClass")
            return

        children = node.get("children", [])
        mods = _style_modifiers(children)
        if kind == "TextButton":
            widget = QPushButton(str(props.get("Text", "Button")), parent_widget)
        elif kind == "ImageButton":
            widget = QPushButton("Image", parent_widget)
        elif kind == "TextBox":
            widget = QLineEdit(str(props.get("Text", "")), parent_widget)
            widget.setPlaceholderText(str(props.get("PlaceholderText", "")))
        elif kind == "TextLabel":
            widget = FmoTextLabel(props, parent_widget)
        elif kind == "ImageLabel":
            widget = FmoImageLabel(props, parent_widget)
        elif kind == "ScrollingFrame":
            widget = QScrollArea(parent_widget)
            widget.setWidgetResizable(False)
            widget.setFrameShape(QFrame.Shape.NoFrame)
            widget.setHorizontalScrollBarPolicy(
                Qt.ScrollBarPolicy.ScrollBarAsNeeded
                if "x" in str(props.get("ScrollingDirection", "XY")).lower()
                else Qt.ScrollBarPolicy.ScrollBarAlwaysOff
            )
            widget.setVerticalScrollBarPolicy(
                Qt.ScrollBarPolicy.ScrollBarAsNeeded
                if "y" in str(props.get("ScrollingDirection", "XY")).lower()
                else Qt.ScrollBarPolicy.ScrollBarAlwaysOff
            )
            content = QWidget()
            viewport_size = (max(1, parent_widget.width()), max(1, parent_widget.height()))
            raw_canvas = props.get("CanvasSize")
            if isinstance(raw_canvas, (list, tuple)) and len(raw_canvas) >= 4:
                canvas_size = dimensions(raw_canvas, viewport_size, viewport_size)
                if canvas_size == (1, 1):
                    canvas_size = viewport_size
            else:
                canvas_size = viewport_size
            content.resize(*canvas_size)
            widget.setWidget(content)
        else:
            widget = QFrame(parent_widget)
            widget.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        if kind in {"TextButton", "ImageButton"}:
            widget.setCursor(Qt.CursorShape.PointingHandCursor)
            widget.setEnabled(props.get("Active", True) is not False and props.get("Interactable", True) is not False)
            widget.setStyleSheet(
                f"QPushButton {{ {_widget_style(props, children, '#465f9e')} color:{qcolor(props.get('TextColor3'), '#ffffff').name()};"
                " padding:5px 10px; } QPushButton:disabled { color:#999999; }"
            )
            if kind == "TextButton":
                font = QFont(widget.font())
                font.setPointSize(max(1, int(number(props.get("TextSize", 14)))))
                font.setBold("bold" in str(props.get("Font", "")).lower())
                widget.setFont(font)
            else:
                image_path = str(props.get("Image", ""))
                if image_path and Path(image_path).is_file():
                    widget.setIcon(QIcon(image_path))
                    widget.setIconSize(QSize(64, 64))
            target = node.get("id")
            if target:
                widget.clicked.connect(lambda checked=False, ident=target:
                                       self.event_handler(ident, "click", None))
        elif kind == "TextBox":
            widget.setEnabled(props.get("Active", True) is not False)
            widget.setStyleSheet(
                f"QLineEdit {{ {_widget_style(props, children, '#303747')} color:{qcolor(props.get('TextColor3'), '#f2f4fa').name()}; padding:6px; }}"
            )
            font = QFont(widget.font())
            font.setPointSize(max(1, int(number(props.get("TextSize", 14)))))
            widget.setFont(font)
            target = node.get("id")
            if target:
                widget.editingFinished.connect(lambda ident=target, field=widget:
                                               self.event_handler(ident, "text", field.text()))
        elif kind in {"Frame", "ScrollingFrame"}:
            widget.setStyleSheet(f"{_widget_style(props, children, '#252936')}")
        elif kind == "ImageLabel":
            pass

        parent_size = (max(1, parent_widget.width()), max(1, parent_widget.height()))
        if override_geometry:
            x, y, width, height = override_geometry
        else:
            width, height = dimensions(props.get("Size"), parent_size)
            x, y = position(props.get("Position"), parent_size)
            anchor = pair(props.get("AnchorPoint"), (0, 0))
            x -= int(round(width * number(anchor[0])))
            y -= int(round(height * number(anchor[1])))
        scale = number(mods.get("UIScale", {}).get("Scale", 1), 1)
        if scale > 0 and scale != 1:
            width, height = max(1, int(width * scale)), max(1, int(height * scale))
        widget.setGeometry(x, y, width, height)
        self.created += 1
        self.debug(f"CREATE id={node_id} class={kind} geometry=({x},{y},{width},{height})")
        widget.show()
        widget.raise_()
        child_parent = widget.widget() if kind == "ScrollingFrame" else widget
        self.render_children(child_parent, children)


__all__ = ["GuiRenderer"]
