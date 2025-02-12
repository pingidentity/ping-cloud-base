import base64


def decode(encoded: str) -> str:
    """
    Decode a base64 encoded string

    Args:
        encoded: base64 encoded string

    Returns: Decoded string
    """
    return base64.b64decode(encoded).decode("ascii")


def encode(decoded: str) -> str:
    """
    Encode a string to base64

    Args:
        decoded: string to encode

    Returns: base64 encoded string
    """
    return base64.b64encode(decoded.encode("ascii")).decode("ascii")
