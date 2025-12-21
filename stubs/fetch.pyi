"""HTTP/HTTPS client module for making web requests."""

from typing import Any

def request(
    method: str,
    url: str,
    data: bytes | str | None = None,
    headers: dict[str, str] | None = None,
    timeout: float | None = None,
    json: Any = None,
    verify: bool = True,
    cafile: str | None = None,
) -> dict[str, Any]:
    """Make an HTTP request.

    Args:
        method: HTTP method (GET, POST, etc.)
        url: URL to request
        data: Request body as bytes or string
        headers: Request headers
        timeout: Request timeout in seconds (not yet implemented)
        json: JSON data to send (auto-serialized)
        verify: Whether to verify SSL certificates
        cafile: Path to CA certificate file

    Returns:
        Dict with status (int), reason (str), headers (dict), body (bytes), url (str)
    """
    ...

def get(
    url: str,
    headers: dict[str, str] | None = None,
    timeout: float | None = None,
    verify: bool = True,
    cafile: str | None = None,
) -> dict[str, Any]:
    """Make an HTTP GET request.

    Args:
        url: URL to request
        headers: Request headers
        timeout: Request timeout in seconds (not yet implemented)
        verify: Whether to verify SSL certificates
        cafile: Path to CA certificate file

    Returns:
        Dict with status (int), reason (str), headers (dict), body (bytes), url (str)
    """
    ...

def post(
    url: str,
    data: bytes | str | None = None,
    headers: dict[str, str] | None = None,
    timeout: float | None = None,
    json: Any = None,
    verify: bool = True,
    cafile: str | None = None,
) -> dict[str, Any]:
    """Make an HTTP POST request.

    Args:
        url: URL to request
        data: Request body as bytes or string
        headers: Request headers
        timeout: Request timeout in seconds (not yet implemented)
        json: JSON data to send (auto-serialized)
        verify: Whether to verify SSL certificates
        cafile: Path to CA certificate file

    Returns:
        Dict with status (int), reason (str), headers (dict), body (bytes), url (str)
    """
    ...
