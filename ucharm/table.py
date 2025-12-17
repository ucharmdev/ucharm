# ucharm/table.py - Table rendering
"""
Table rendering components.
All rendering is done natively in Zig via libucharm.
"""

from ._native import ALIGN_CENTER, ALIGN_LEFT, ALIGN_RIGHT, ui
from .style import style

_ALIGN_MAP = {"left": ALIGN_LEFT, "right": ALIGN_RIGHT, "center": ALIGN_CENTER}


def table(
    data,
    headers=None,
    border=True,
    header_style=None,
    row_styles=None,
    column_alignments=None,
    padding=1,
):
    """
    Render a table.

    Args:
        data: List of rows (each row is a list of values)
        headers: Optional list of header strings
        border: Whether to draw borders
        header_style: Dict of style kwargs for headers (e.g., {"bold": True, "fg": "cyan"})
        row_styles: Function(row_idx, row) -> style kwargs, or None
        column_alignments: List of alignments per column ("left", "right", "center")
        padding: Horizontal cell padding

    Example:
        table(
            [["Alice", 25, "Engineer"], ["Bob", 30, "Designer"]],
            headers=["Name", "Age", "Role"],
            header_style={"bold": True, "fg": "cyan"}
        )
    """
    if not data and not headers:
        return

    # Convert all data to strings
    str_data = [[str(cell) for cell in row] for row in data]

    # Determine number of columns
    num_cols = len(headers) if headers else len(data[0]) if data else 0

    # Calculate column widths
    col_widths = [0] * num_cols
    if headers:
        for i, h in enumerate(headers):
            col_widths[i] = max(col_widths[i], ui.visible_len(str(h)))
    for row in str_data:
        for i, cell in enumerate(row):
            if i < num_cols:
                col_widths[i] = max(col_widths[i], ui.visible_len(cell))

    # Add padding
    col_widths = [w + padding * 2 for w in col_widths]

    # Default alignments
    if column_alignments is None:
        column_alignments = ["left"] * num_cols

    def make_row(cells, alignments):
        """Build a table row string."""
        parts = []
        for i, (cell, width) in enumerate(zip(cells, col_widths)):
            align = _ALIGN_MAP.get(
                alignments[i] if i < len(alignments) else "left", ALIGN_LEFT
            )
            parts.append(ui.table_cell(cell, width, align, padding))
        v = ui.table_v()
        if border:
            return v + v.join(parts) + v
        else:
            return "  ".join(parts)

    lines = []

    # Top border
    if border:
        lines.append(ui.table_top(col_widths))

    # Headers
    if headers:
        header_cells = []
        hs = header_style or {}
        for h in headers:
            styled_h = style(str(h), **hs) if hs else str(h)
            header_cells.append(styled_h)
        lines.append(make_row(header_cells, column_alignments))
        if border:
            lines.append(ui.table_divider(col_widths))

    # Data rows
    for row_idx, row in enumerate(str_data):
        if row_styles:
            rs = row_styles(row_idx, row)
            if rs:
                row = [style(cell, **rs) for cell in row]
        lines.append(make_row(row, column_alignments))

    # Bottom border
    if border:
        lines.append(ui.table_bottom(col_widths))

    for line in lines:
        print(line)


def simple_table(data, headers=None):
    """Simple borderless table with minimal styling."""
    table(
        data,
        headers=headers,
        border=False,
        header_style={"bold": True, "underline": True},
    )


def key_value(items, separator=" : ", key_style=None, value_style=None):
    """
    Render key-value pairs.

    Args:
        items: Dict or list of (key, value) tuples
        separator: String between key and value
        key_style: Style kwargs for keys
        value_style: Style kwargs for values
    """
    if isinstance(items, dict):
        items = list(items.items())

    max_key = max(ui.visible_len(str(k)) for k, v in items)
    ks = key_style or {"bold": True}
    vs = value_style or {"fg": "cyan"}

    for key, value in items:
        key_str = style(str(key), **ks) if ks else str(key)
        val_str = style(str(value), **vs) if vs else str(value)
        padding = " " * (max_key - ui.visible_len(str(key)))
        print(key_str + padding + separator + val_str)
