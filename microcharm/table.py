# microcharm/table.py - Table rendering
from .style import style


def _visible_len(s):
    """Get visible length of string (excluding ANSI codes)."""
    result = s
    while "\033[" in result:
        start = result.find("\033[")
        end = start + 2
        while end < len(result) and result[end] not in "mHJK":
            end += 1
        if end < len(result):
            result = result[:start] + result[end + 1 :]
        else:
            break
    return len(result)


def _pad(text, width, align="left"):
    """Pad text to width."""
    visible = _visible_len(text)
    padding = width - visible
    if padding <= 0:
        return text
    if align == "left":
        return text + " " * padding
    elif align == "right":
        return " " * padding + text
    else:  # center
        left = padding // 2
        right = padding - left
        return " " * left + text + " " * right


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
    str_data = []
    for row in data:
        str_data.append([str(cell) for cell in row])

    # Determine number of columns
    num_cols = len(headers) if headers else len(data[0]) if data else 0

    # Calculate column widths
    col_widths = [0] * num_cols
    if headers:
        for i, h in enumerate(headers):
            col_widths[i] = max(col_widths[i], _visible_len(str(h)))
    for row in str_data:
        for i, cell in enumerate(row):
            if i < num_cols:
                col_widths[i] = max(col_widths[i], _visible_len(cell))

    # Add padding
    col_widths = [w + padding * 2 for w in col_widths]

    # Default alignments
    if column_alignments is None:
        column_alignments = ["left"] * num_cols

    # Border characters
    if border:
        h_char = "─"
        v_char = "│"
        tl, tr, bl, br = "┌", "┐", "└", "┘"
        t_down, t_up, t_left, t_right = "┬", "┴", "┤", "├"
        cross = "┼"

    def make_row(cells, alignments):
        """Build a table row string."""
        parts = []
        for i, (cell, width) in enumerate(zip(cells, col_widths)):
            align = alignments[i] if i < len(alignments) else "left"
            padded = _pad(" " * padding + cell + " " * padding, width, align)
            parts.append(padded)
        if border:
            return v_char + v_char.join(parts) + v_char
        else:
            return "  ".join(parts)

    def make_divider(left, mid, right, char):
        """Build a horizontal divider."""
        parts = [char * w for w in col_widths]
        return left + mid.join(parts) + right

    lines = []

    # Top border
    if border:
        lines.append(make_divider(tl, t_down, tr, h_char))

    # Headers
    if headers:
        header_cells = []
        hs = header_style or {}
        for h in headers:
            styled_h = style(str(h), **hs) if hs else str(h)
            header_cells.append(styled_h)
        lines.append(make_row(header_cells, column_alignments))

        # Header divider
        if border:
            lines.append(make_divider(t_right, cross, t_left, h_char))

    # Data rows
    for row_idx, row in enumerate(str_data):
        # Apply row styles if provided
        if row_styles:
            rs = row_styles(row_idx, row)
            if rs:
                row = [style(cell, **rs) for cell in row]
        lines.append(make_row(row, column_alignments))

    # Bottom border
    if border:
        lines.append(make_divider(bl, t_up, br, h_char))

    # Print
    for line in lines:
        print(line)


def simple_table(data, headers=None):
    """
    Simple borderless table with minimal styling.
    """
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

    # Find max key length
    max_key = max(_visible_len(str(k)) for k, v in items)

    ks = key_style or {"bold": True}
    vs = value_style or {"fg": "cyan"}

    for key, value in items:
        key_str = style(str(key), **ks) if ks else str(key)
        val_str = style(str(value), **vs) if vs else str(value)
        # Pad key
        padding = " " * (max_key - _visible_len(str(key)))
        print(key_str + padding + separator + val_str)
