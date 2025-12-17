# ucharm/compat/textwrap.py
"""
Pure Python implementation of textwrap for MicroPython.

Provides:
- wrap: Wrap text to specified width
- fill: Wrap and join with newlines
- dedent: Remove common leading whitespace
- indent: Add prefix to lines
- shorten: Truncate text to width with placeholder
"""


def wrap(
    text,
    width=70,
    initial_indent="",
    subsequent_indent="",
    expand_tabs=True,
    tabsize=8,
    replace_whitespace=True,
    fix_sentence_endings=False,
    break_long_words=True,
    drop_whitespace=True,
    break_on_hyphens=True,
    max_lines=None,
    placeholder=" [...]",
):
    """
    Wrap a single paragraph of text to fit in lines of specified width.

    Returns a list of output lines, without final newlines.

    Args:
        text: The text to wrap
        width: Maximum line length
        initial_indent: String prepended to first line
        subsequent_indent: String prepended to all other lines
        expand_tabs: Expand tabs to spaces
        replace_whitespace: Replace whitespace chars with spaces
        break_long_words: Break words longer than width
        drop_whitespace: Drop leading/trailing whitespace from lines
        break_on_hyphens: Allow breaking at hyphens
        max_lines: Maximum number of lines to return
        placeholder: String appended if text is truncated
    """
    # Preprocess text
    if expand_tabs:
        # MicroPython doesn't have str.expandtabs()
        text = text.replace("\t", " " * tabsize)

    if replace_whitespace:
        # Replace all whitespace with single spaces
        text = " ".join(text.split())

    if not text:
        return []

    # Split into words
    words = text.split()
    if not words:
        return []

    lines = []
    current_line = []
    current_width = 0

    for i, word in enumerate(words):
        # Determine indent for this line
        if not lines:
            indent = initial_indent
        else:
            indent = subsequent_indent

        indent_width = len(indent)
        available = width - indent_width

        # Check if word fits on current line
        word_width = len(word)

        if not current_line:
            # First word on line
            if word_width <= available:
                current_line.append(word)
                current_width = word_width
            elif break_long_words:
                # Break the word
                while word:
                    chunk = word[:available]
                    word = word[available:]
                    if current_line:
                        lines.append(indent + " ".join(current_line))
                        indent = subsequent_indent
                        indent_width = len(indent)
                        available = width - indent_width
                        current_line = []
                    current_line.append(chunk)
                    if not word:
                        current_width = len(chunk)
            else:
                current_line.append(word)
                current_width = word_width
        else:
            # Adding to existing line
            new_width = current_width + 1 + word_width  # +1 for space

            if new_width <= available:
                current_line.append(word)
                current_width = new_width
            else:
                # Start new line
                lines.append(indent + " ".join(current_line))

                # Update indent for new line
                indent = subsequent_indent
                indent_width = len(indent)
                available = width - indent_width

                if word_width <= available:
                    current_line = [word]
                    current_width = word_width
                elif break_long_words:
                    current_line = []
                    current_width = 0
                    while word:
                        chunk = word[:available]
                        word = word[available:]
                        if current_line:
                            lines.append(subsequent_indent + " ".join(current_line))
                        current_line = [chunk]
                        current_width = len(chunk)
                else:
                    current_line = [word]
                    current_width = word_width

    # Don't forget the last line
    if current_line:
        indent = subsequent_indent if lines else initial_indent
        lines.append(indent + " ".join(current_line))

    # Handle max_lines
    if max_lines is not None and len(lines) > max_lines:
        lines = lines[:max_lines]
        # Add placeholder to last line if it fits, otherwise replace last line
        last_line = lines[-1]
        if len(last_line) + len(placeholder) <= width:
            lines[-1] = last_line.rstrip() + placeholder
        else:
            # Truncate last line to make room for placeholder
            available = width - len(placeholder)
            if available > 0:
                lines[-1] = last_line[:available].rstrip() + placeholder
            else:
                lines[-1] = placeholder[:width]

    return lines


def fill(text, width=70, **kwargs):
    """
    Wrap text and return as a single string with newlines.

    Shortcut for '\\n'.join(wrap(text, ...))
    """
    return "\n".join(wrap(text, width, **kwargs))


def dedent(text):
    """
    Remove any common leading whitespace from every line.

    This is useful for making triple-quoted strings line up with the
    left edge of the display, while still presenting them in the
    source code in indented form.

    Example:
        dedent('''
            Hello
            World
        ''')
    Returns:
        '\\nHello\\nWorld\\n'
    """
    # Split into lines
    lines = text.split("\n")

    # Find minimum indentation (ignoring blank lines)
    min_indent = None
    for line in lines:
        stripped = line.lstrip(" \t")
        if stripped:  # Non-blank line
            indent = len(line) - len(stripped)
            if min_indent is None or indent < min_indent:
                min_indent = indent

    if min_indent is None or min_indent == 0:
        return text

    # Remove the common indent from each line
    result = []
    for line in lines:
        if line.strip():
            result.append(line[min_indent:])
        else:
            result.append(line.lstrip())

    return "\n".join(result)


def indent(text, prefix, predicate=None):
    """
    Add prefix to the beginning of selected lines.

    Args:
        text: The text to process
        prefix: String to prepend to lines
        predicate: Function that takes a line and returns True if
                   prefix should be added. Default: add to non-empty lines.
    """
    if predicate is None:

        def predicate(line):
            return line.strip()

    lines = text.split("\n")
    result = []

    for line in lines:
        if predicate(line):
            result.append(prefix + line)
        else:
            result.append(line)

    return "\n".join(result)


def shorten(text, width, **kwargs):
    """
    Collapse and truncate text to fit in specified width.

    First the whitespace in text is collapsed. Then the text is truncated
    to fit in width, and a placeholder is appended.

    Args:
        text: Text to shorten
        width: Maximum width including placeholder
        placeholder: String to append (default: ' [...]')
    """
    placeholder = kwargs.get("placeholder", " [...]")

    # Collapse whitespace
    text = " ".join(text.split())

    if len(text) <= width:
        return text

    # Truncate
    available = width - len(placeholder)
    if available <= 0:
        return placeholder[:width]

    # Try to break at word boundary
    truncated = text[:available]

    # Find last space
    last_space = truncated.rfind(" ")
    if last_space > 0:
        truncated = truncated[:last_space]

    return truncated.rstrip() + placeholder


class TextWrapper:
    """
    Object-oriented interface for text wrapping.

    Example:
        wrapper = TextWrapper(width=40, initial_indent='> ')
        print(wrapper.fill(long_text))
    """

    def __init__(
        self,
        width=70,
        initial_indent="",
        subsequent_indent="",
        expand_tabs=True,
        tabsize=8,
        replace_whitespace=True,
        fix_sentence_endings=False,
        break_long_words=True,
        drop_whitespace=True,
        break_on_hyphens=True,
        max_lines=None,
        placeholder=" [...]",
    ):
        self.width = width
        self.initial_indent = initial_indent
        self.subsequent_indent = subsequent_indent
        self.expand_tabs = expand_tabs
        self.tabsize = tabsize
        self.replace_whitespace = replace_whitespace
        self.fix_sentence_endings = fix_sentence_endings
        self.break_long_words = break_long_words
        self.drop_whitespace = drop_whitespace
        self.break_on_hyphens = break_on_hyphens
        self.max_lines = max_lines
        self.placeholder = placeholder

    def wrap(self, text):
        """Wrap text and return list of lines."""
        return wrap(
            text,
            width=self.width,
            initial_indent=self.initial_indent,
            subsequent_indent=self.subsequent_indent,
            expand_tabs=self.expand_tabs,
            tabsize=self.tabsize,
            replace_whitespace=self.replace_whitespace,
            fix_sentence_endings=self.fix_sentence_endings,
            break_long_words=self.break_long_words,
            drop_whitespace=self.drop_whitespace,
            break_on_hyphens=self.break_on_hyphens,
            max_lines=self.max_lines,
            placeholder=self.placeholder,
        )

    def fill(self, text):
        """Wrap text and return as single string."""
        return "\n".join(self.wrap(text))
