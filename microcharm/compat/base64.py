# microcharm/compat/base64.py
"""
Base64 encoding/decoding for MicroPython.

This wraps the built-in binascii module which MicroPython has.

Provides:
- b64encode, b64decode: Standard Base64
- urlsafe_b64encode, urlsafe_b64decode: URL-safe Base64
- standard_b64encode, standard_b64decode: Aliases for b64encode/decode
- b32encode, b32decode: Base32 encoding
- b16encode, b16decode: Base16 (hex) encoding
"""

import binascii


def b64encode(data, altchars=None):
    """
    Encode bytes to Base64.

    Args:
        data: Bytes to encode
        altchars: 2-byte string to use instead of '+' and '/'

    Returns:
        Base64 encoded bytes
    """
    result = binascii.b2a_base64(data).rstrip(b"\n")

    if altchars is not None:
        if len(altchars) != 2:
            raise ValueError("altchars must be a 2-character bytes-like object")
        result = result.replace(b"+", altchars[0:1])
        result = result.replace(b"/", altchars[1:2])

    return result


def b64decode(data, altchars=None, validate=False):
    """
    Decode Base64 encoded bytes.

    Args:
        data: Base64 encoded bytes or string
        altchars: 2-byte string used instead of '+' and '/'
        validate: If True, raise error on non-base64 characters

    Returns:
        Decoded bytes
    """
    if isinstance(data, str):
        data = data.encode("ascii")

    if altchars is not None:
        if len(altchars) != 2:
            raise ValueError("altchars must be a 2-character bytes-like object")
        data = data.replace(altchars[0:1], b"+")
        data = data.replace(altchars[1:2], b"/")

    # Add padding if needed
    missing_padding = len(data) % 4
    if missing_padding:
        data += b"=" * (4 - missing_padding)

    return binascii.a2b_base64(data)


def standard_b64encode(data):
    """Encode bytes using standard Base64 alphabet."""
    return b64encode(data)


def standard_b64decode(data):
    """Decode bytes using standard Base64 alphabet."""
    return b64decode(data)


def urlsafe_b64encode(data):
    """
    Encode bytes using URL-safe Base64 alphabet.

    Uses '-' instead of '+' and '_' instead of '/'.
    """
    return b64encode(data, b"-_")


def urlsafe_b64decode(data):
    """
    Decode bytes using URL-safe Base64 alphabet.

    Accepts '-' instead of '+' and '_' instead of '/'.
    """
    return b64decode(data, b"-_")


def b16encode(data):
    """
    Encode bytes to Base16 (hex).

    Returns uppercase hex string as bytes.
    """
    return binascii.hexlify(data).upper()


def b16decode(data, casefold=False):
    """
    Decode Base16 (hex) encoded bytes.

    Args:
        data: Hex encoded bytes or string
        casefold: If True, accept lowercase letters
    """
    if isinstance(data, str):
        data = data.encode("ascii")

    if casefold:
        data = data.upper()

    return binascii.unhexlify(data)


# Base32 alphabet
_B32_ALPHABET = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
_B32_DECODE = {c: i for i, c in enumerate(_B32_ALPHABET)}


def b32encode(data):
    """
    Encode bytes to Base32.

    Returns Base32 encoded bytes (uppercase with padding).
    """
    if isinstance(data, str):
        data = data.encode("utf-8")

    result = []

    # Process 5 bytes at a time (40 bits = 8 base32 chars)
    i = 0
    while i < len(data):
        chunk = data[i : i + 5]
        i += 5

        # Pad chunk to 5 bytes
        chunk = chunk + b"\x00" * (5 - len(chunk))

        # Convert 5 bytes to 8 5-bit values
        n = 0
        for b in chunk:
            n = (n << 8) | b

        # Extract 5-bit values and map to alphabet
        chars = []
        for j in range(8):
            chars.append(_B32_ALPHABET[(n >> (35 - j * 5)) & 0x1F])

        result.extend(chars)

    # Add padding - Base32 output is always multiple of 8
    result = bytes(result)
    if len(data) % 5:
        # Calculate how many output chars we actually need
        # Each input byte = 8 bits, base32 char = 5 bits
        # So n bytes needs ceil(n*8/5) chars, padded to multiple of 8
        encoded_len = (len(data) * 8 + 4) // 5
        padding_len = (8 - encoded_len % 8) % 8
        result = result[:encoded_len] + b"=" * padding_len

    return result


def b32decode(data, casefold=False):
    """
    Decode Base32 encoded bytes.

    Args:
        data: Base32 encoded bytes or string
        casefold: If True, accept lowercase letters
    """
    if isinstance(data, str):
        data = data.encode("ascii")

    if casefold:
        data = data.upper()

    # Remove padding
    data = data.rstrip(b"=")

    # Decode
    result = []
    n = 0
    bits = 0

    for c in data:
        if c not in _B32_DECODE:
            raise ValueError("Invalid Base32 character: " + chr(c))

        n = (n << 5) | _B32_DECODE[c]
        bits += 5

        if bits >= 8:
            bits -= 8
            result.append((n >> bits) & 0xFF)

    return bytes(result)


def encodebytes(data):
    """
    Encode bytes to Base64 with newlines every 76 characters.

    This is the legacy format used by email (MIME).
    """
    result = []
    encoded = b64encode(data)

    for i in range(0, len(encoded), 76):
        result.append(encoded[i : i + 76])
        result.append(b"\n")

    return b"".join(result)


def decodebytes(data):
    """
    Decode Base64 bytes, ignoring newlines.
    """
    if isinstance(data, str):
        data = data.encode("ascii")

    # Remove whitespace
    data = b"".join(data.split())

    return b64decode(data)


# Legacy aliases
encodestring = encodebytes
decodestring = decodebytes
