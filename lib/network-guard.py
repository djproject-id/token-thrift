"""token-thrift runtime network egress guard.

Loaded by the wrapper before invoking the underlying CLI as MCP server.
Patches socket.socket.connect to refuse connections to hosts listed in
~/.token-thrift/data/blocked-hosts.txt. Suffix match: an entry like
"openai.com" blocks api.openai.com, www.openai.com, etc.

This is a runtime safety net. The wrapper already unsets cloud env vars,
so under normal operation the guarded code never tries to reach these hosts.
The guard exists in case an exploit or misconfiguration tries to anyway.
"""

from __future__ import annotations

import os
import socket
import sys


def _load_blocklist() -> frozenset[str]:
    path = os.path.expanduser("~/.token-thrift/data/blocked-hosts.txt")
    hosts: set[str] = set()
    try:
        with open(path, encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                hosts.add(line.lower())
    except FileNotFoundError:
        pass
    return frozenset(hosts)


_BLOCKED = _load_blocklist()
_orig_getaddrinfo = socket.getaddrinfo
_orig_create_connection = socket.create_connection
_orig_connect = socket.socket.connect


def _is_blocked(host: str | None) -> bool:
    if not host:
        return False
    h = host.lower().rstrip(".")
    if h in _BLOCKED:
        return True
    return any(h == b or h.endswith("." + b) for b in _BLOCKED)


def _guard_getaddrinfo(host, *args, **kwargs):
    if _is_blocked(host):
        raise PermissionError(f"token-thrift: DNS lookup for {host!r} blocked")
    return _orig_getaddrinfo(host, *args, **kwargs)


def _guard_create_connection(address, *args, **kwargs):
    host, _ = address[0], address[1] if len(address) > 1 else (address, 0)
    if _is_blocked(host):
        raise PermissionError(f"token-thrift: connection to {host!r} blocked")
    return _orig_create_connection(address, *args, **kwargs)


def _guard_connect(self, address):
    host = address[0] if isinstance(address, tuple) else None
    if _is_blocked(host):
        raise PermissionError(f"token-thrift: socket.connect to {host!r} blocked")
    return _orig_connect(self, address)


if _BLOCKED:
    socket.getaddrinfo = _guard_getaddrinfo
    socket.create_connection = _guard_create_connection
    socket.socket.connect = _guard_connect
    if os.environ.get("TOKEN_THRIFT_GUARD_VERBOSE") == "1":
        print(
            f"[token-thrift guard] {len(_BLOCKED)} host suffixes blocked",
            file=sys.stderr,
        )
