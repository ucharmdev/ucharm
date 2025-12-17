# ucharm/compat/fnmatch.py
"""
Pure Python implementation of fnmatch for MicroPython.

Provides Unix filename pattern matching WITHOUT using regex,
since MicroPython's regex engine is limited.

Pattern syntax:
- * matches everything
- ? matches any single character
- [seq] matches any character in seq
- [!seq] matches any character not in seq

Note: Patterns are case-sensitive by default.
"""


def _match_pattern(name, pattern):
    """
    Match name against pattern using recursive approach.

    Returns True if name matches pattern.
    """
    ni = 0  # name index
    pi = 0  # pattern index
    nlen = len(name)
    plen = len(pattern)

    # For backtracking on * matches
    star_pi = -1
    star_ni = -1

    while ni < nlen:
        if pi < plen:
            pc = pattern[pi]

            if pc == "?":
                # ? matches any single character
                ni += 1
                pi += 1
                continue

            elif pc == "*":
                # * matches zero or more characters
                # Remember this position for backtracking
                star_pi = pi
                star_ni = ni
                pi += 1
                continue

            elif pc == "[":
                # Character class
                pi += 1
                if pi >= plen:
                    return False

                # Check for negation
                negate = False
                if pattern[pi] == "!":
                    negate = True
                    pi += 1
                elif pattern[pi] == "^":
                    negate = True
                    pi += 1

                # Find closing bracket and check if char matches
                matched = False
                start_pi = pi

                while pi < plen and pattern[pi] != "]":
                    # Check for range like a-z
                    if (
                        pi + 2 < plen
                        and pattern[pi + 1] == "-"
                        and pattern[pi + 2] != "]"
                    ):
                        lo = pattern[pi]
                        hi = pattern[pi + 2]
                        if lo <= name[ni] <= hi:
                            matched = True
                        pi += 3
                    else:
                        if pattern[pi] == name[ni]:
                            matched = True
                        pi += 1

                if pi >= plen:
                    # No closing bracket found
                    return False

                pi += 1  # Skip closing bracket

                if negate:
                    matched = not matched

                if not matched:
                    # No match, try backtracking
                    if star_pi >= 0:
                        pi = star_pi + 1
                        star_ni += 1
                        ni = star_ni
                        continue
                    return False

                ni += 1
                continue

            elif pc == name[ni]:
                # Exact character match
                ni += 1
                pi += 1
                continue

        # No match at current position
        # Try backtracking if we had a * earlier
        if star_pi >= 0:
            pi = star_pi + 1
            star_ni += 1
            ni = star_ni
            continue

        return False

    # Consume any trailing *
    while pi < plen and pattern[pi] == "*":
        pi += 1

    return pi == plen


def fnmatch(name, pattern):
    """
    Test whether name matches pattern.

    Patterns are Unix shell style:
    - * matches everything
    - ? matches any single character
    - [seq] matches any character in seq
    - [!seq] matches any character not in seq

    Example:
        fnmatch('foo.txt', '*.txt')  # True
        fnmatch('bar.py', '*.txt')   # False
    """
    return _match_pattern(name, pattern)


def fnmatchcase(name, pattern):
    """
    Test whether name matches pattern, case-sensitively.

    This is the case-sensitive version of fnmatch.
    """
    return _match_pattern(name, pattern)


def filter(names, pattern):
    """
    Return the subset of names that match pattern.

    Example:
        filter(['a.txt', 'b.py', 'c.txt'], '*.txt')  # ['a.txt', 'c.txt']
    """
    result = []
    for name in names:
        if _match_pattern(name, pattern):
            result.append(name)
    return result


def translate(pattern):
    """
    Translate a shell pattern to a regular expression.

    Note: This is provided for API compatibility but the regex
    may not work on MicroPython's limited regex engine.
    """
    res = []
    i = 0
    n = len(pattern)

    while i < n:
        c = pattern[i]
        i += 1

        if c == "*":
            res.append(".*")
        elif c == "?":
            res.append(".")
        elif c == "[":
            j = i
            if j < n and pattern[j] == "!":
                j += 1
            if j < n and pattern[j] == "]":
                j += 1
            while j < n and pattern[j] != "]":
                j += 1
            if j >= n:
                res.append("\\[")
            else:
                stuff = pattern[i:j]
                if stuff[0:1] == "!":
                    stuff = "^" + stuff[1:]
                res.append("[" + stuff + "]")
                i = j + 1
        else:
            # Escape special characters
            if c in ".^$+{}[]|()\\?":
                res.append("\\")
            res.append(c)

    return "(?s:" + "".join(res) + ")\\Z"
