# μcharm bundled library for MicroPython
# This file is embedded in the ucharm CLI for use with 'ucharm run'

import sys
import time

# Constants
ALIGN_LEFT = 0
ALIGN_RIGHT = 1
ALIGN_CENTER = 2
BORDER_ROUNDED = 0
BORDER_SQUARE = 1
BORDER_DOUBLE = 2
BORDER_HEAVY = 3
BORDER_NONE = 4

# Pure Python ui class (replaces _native.ui for MicroPython)
class ui:
    _BOX_CHARS = {
        0: ('╭', '╮', '╰', '╯', '─', '│'),  # rounded
        1: ('┌', '┐', '└', '┘', '─', '│'),  # square
        2: ('╔', '╗', '╚', '╝', '═', '║'),  # double
        3: ('┏', '┓', '┗', '┛', '━', '┃'),  # heavy
        4: (' ', ' ', ' ', ' ', ' ', ' '),  # none
    }
    _SPINNER = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']

    @staticmethod
    def visible_len(s):
        i, length = 0, 0
        while i < len(s):
            if s[i] == '\x1b' and i + 1 < len(s) and s[i + 1] == '[':
                i += 2
                while i < len(s) and s[i] not in 'mHJK':
                    i += 1
                i += 1
            else:
                c = ord(s[i])
                if c < 128:
                    length += 1
                    i += 1
                elif c < 0xE0:
                    length += 1
                    i += 2
                elif c < 0xF0:
                    length += 2
                    i += 3
                else:
                    length += 2
                    i += 4
        return length

    @staticmethod
    def pad(text, width, align=0):
        vis = ui.visible_len(text)
        if vis >= width:
            return text
        pad = width - vis
        if align == 1:
            return ' ' * pad + text
        elif align == 2:
            l = pad // 2
            return ' ' * l + text + ' ' * (pad - l)
        return text + ' ' * pad

    @staticmethod
    def progress_bar(cur, total, width, fill='█', empty='░'):
        if total <= 0:
            return empty * width
        filled = int(width * cur / total)
        return fill * filled + empty * (width - filled)

    @staticmethod
    def percent_str(cur, total):
        if total <= 0:
            return '0%'
        return str(int(100 * cur / total)) + '%'

    @staticmethod
    def box_chars(style=0):
        c = ui._BOX_CHARS.get(style, ui._BOX_CHARS[0])
        return {'tl': c[0], 'tr': c[1], 'bl': c[2], 'br': c[3], 'h': c[4], 'v': c[5]}

    @staticmethod
    def symbol_success():
        return '✓'

    @staticmethod
    def symbol_error():
        return '✗'

    @staticmethod
    def symbol_warning():
        return '⚠'

    @staticmethod
    def symbol_info():
        return 'ℹ'

    @staticmethod
    def symbol_bullet():
        return '•'

    @staticmethod
    def spinner_frame(idx):
        return ui._SPINNER[idx % len(ui._SPINNER)]

    @staticmethod
    def spinner_frame_count():
        return len(ui._SPINNER)

    @staticmethod
    def select_indicator():
        return '❯ '

    @staticmethod
    def checkbox_on():
        return '◉'

    @staticmethod
    def checkbox_off():
        return '○'

    @staticmethod
    def cursor_up(n):
        return '\x1b[' + str(n) + 'A'

    @staticmethod
    def cursor_down(n):
        return '\x1b[' + str(n) + 'B'

    @staticmethod
    def clear_line():
        return '\x1b[2K\r'

    @staticmethod
    def hide_cursor():
        return '\x1b[?25l'

    @staticmethod
    def show_cursor():
        return '\x1b[?25h'


# Style function
def style(text, fg=None, bg=None, bold=False, dim=False, italic=False, underline=False, strikethrough=False):
    codes = []
    if bold:
        codes.append('1')
    if dim:
        codes.append('2')
    if italic:
        codes.append('3')
    if underline:
        codes.append('4')
    if strikethrough:
        codes.append('9')

    color_map = {
        'black': 30, 'red': 31, 'green': 32, 'yellow': 33,
        'blue': 34, 'magenta': 35, 'cyan': 36, 'white': 37,
        'gray': 90, 'grey': 90,
    }

    if fg:
        if fg in color_map:
            codes.append(str(color_map[fg]))
        elif fg.startswith('#') and len(fg) == 7:
            r = int(fg[1:3], 16)
            g = int(fg[3:5], 16)
            b = int(fg[5:7], 16)
            codes.append('38;2;' + str(r) + ';' + str(g) + ';' + str(b))

    if bg:
        if bg in color_map:
            codes.append(str(color_map[bg] + 10))
        elif bg.startswith('#') and len(bg) == 7:
            r = int(bg[1:3], 16)
            g = int(bg[3:5], 16)
            b = int(bg[5:7], 16)
            codes.append('48;2;' + str(r) + ';' + str(g) + ';' + str(b))

    if not codes:
        return text

    return '\x1b[' + ';'.join(codes) + 'm' + text + '\x1b[0m'


# Box component
def box(content, title=None, border="rounded", border_color=None, padding=1):
    border_styles = {"rounded": 0, "square": 1, "double": 2, "heavy": 3}
    border_style = border_styles.get(border, 0)
    chars = ui.box_chars(border_style)
    lines = content.split('\n')

    max_content_width = max(ui.visible_len(line) for line in lines)
    title_width = len(title) + 4 if title else 0
    inner_width = max(max_content_width, title_width - 2) + (padding * 2)

    def bc(t):
        return style(t, fg=border_color) if border_color else t

    # Top border
    if title:
        title_text = ' ' + title + ' '
        title_styled = style(title_text, bold=True)
        remaining = inner_width - len(title_text) - 1
        top = bc(chars['tl'] + chars['h']) + title_styled + bc(chars['h'] * remaining + chars['tr'])
    else:
        top = bc(chars['tl'] + chars['h'] * inner_width + chars['tr'])
    print(top)

    # Content lines
    pad = ' ' * padding
    content_width = inner_width - (padding * 2)
    for line in lines:
        visible = ui.visible_len(line)
        right_pad = ' ' * (content_width - visible)
        print(bc(chars['v']) + pad + line + right_pad + pad + bc(chars['v']))

    # Bottom border
    print(bc(chars['bl'] + chars['h'] * inner_width + chars['br']))


def rule(title=None, char='─', color=None, width=None):
    if width is None:
        width = 80
    if title:
        t = ' ' + title + ' '
        side = (width - len(t)) // 2
        line = char * side + t + char * (width - side - len(t))
    else:
        line = char * width
    if color:
        line = style(line, fg=color)
    print(line)


def success(message):
    print(style(ui.symbol_success() + ' ', fg='green', bold=True) + message)


def error(message):
    print(style(ui.symbol_error() + ' ', fg='red', bold=True) + message)


def warning(message):
    print(style(ui.symbol_warning() + ' ', fg='yellow', bold=True) + message)


def info(message):
    print(style(ui.symbol_info() + ' ', fg='blue', bold=True) + message)


# Input components
def _read_key():
    """Read a single keypress."""
    try:
        import term
        return term.read_key()
    except ImportError:
        pass
    # Fallback for standard input
    import sys
    return sys.stdin.read(1)


def _set_raw_mode(enable):
    """Enable/disable raw terminal mode."""
    try:
        import term
        term.raw_mode(enable)
        return
    except ImportError:
        pass


def select(prompt, choices, default=0):
    """Interactive select menu."""
    if not choices:
        return None

    selected = default
    print(style('? ', fg='cyan', bold=True) + prompt)
    sys.stdout.write(ui.hide_cursor())
    sys.stdout.flush()

    # Print initial choices
    for i, choice in enumerate(choices):
        if i == selected:
            print(style('  ' + ui.select_indicator() + choice, fg='cyan'))
        else:
            print('    ' + choice)

    _set_raw_mode(True)
    try:
        while True:
            key = _read_key()
            
            if key in ('j', '\x1b[B'):  # down
                selected = (selected + 1) % len(choices)
            elif key in ('k', '\x1b[A'):  # up
                selected = (selected - 1) % len(choices)
            elif key in ('\r', '\n', ' '):  # enter/space
                break
            elif key in ('q', '\x1b', '\x03'):  # q, escape, ctrl-c
                _set_raw_mode(False)
                sys.stdout.write(ui.show_cursor())
                sys.stdout.flush()
                return None

            # Redraw
            sys.stdout.write(ui.cursor_up(len(choices)))
            for i, choice in enumerate(choices):
                sys.stdout.write(ui.clear_line())
                if i == selected:
                    print(style('  ' + ui.select_indicator() + choice, fg='cyan'))
                else:
                    print('    ' + choice)
            sys.stdout.flush()
    finally:
        _set_raw_mode(False)

    sys.stdout.write(ui.show_cursor())
    sys.stdout.flush()
    return choices[selected]


def confirm(prompt, default=True):
    """Yes/no confirmation prompt."""
    hint = '(Y/n)' if default else '(y/N)'
    sys.stdout.write(style('? ', fg='cyan', bold=True) + prompt + ' ' + style(hint, fg='gray') + ' ')
    sys.stdout.flush()

    _set_raw_mode(True)
    try:
        while True:
            key = _read_key()
            if key in ('y', 'Y'):
                result = True
                break
            elif key in ('n', 'N'):
                result = False
                break
            elif key in ('\r', '\n'):
                result = default
                break
            elif key in ('\x03', '\x1b'):  # ctrl-c, escape
                _set_raw_mode(False)
                print()
                return False
    finally:
        _set_raw_mode(False)

    print(style('Yes' if result else 'No', fg='cyan'))
    return result
