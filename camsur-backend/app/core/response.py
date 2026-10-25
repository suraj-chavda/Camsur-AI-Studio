from typing import Any


def ok(data: Any = None, message: str = "ok") -> dict:
    return {"success": True, "message": message, "data": data}


def fail(message: str, data: Any = None) -> dict:
    return {"success": False, "message": message, "data": data}
