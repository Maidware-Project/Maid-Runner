"""Optional KDE layer-shell integration for Wayland.

A toplevel window always earns a taskbar entry, and a launcher does not
want one. KRunner sidesteps that by living on a layer-shell surface;
this module lets Maid Runner do the same - same window, same look, but
KWin leaves it out of the taskbar and alt-tab.

The switch is per window and completely optional. LayerShellQt ships
with Plasma; it is called through its stable C++ ABI. When the library
is missing, or the compositor has no layer-shell protocol, the lib
logs one line and the window stays a plain toplevel - the app keeps
working exactly as before. No env vars, no Qt plugins, no dependency.

attach_layer() runs after the window has a handle (winId()) and before
its first show(), so the anchor lands in the first surface commit.
"""

import ctypes
import os

# The client control library (LayerShellQt::Window). Shipped by Plasma;
# a machine without it simply stays on plain toplevels.
_LIB = "libLayerShellQtInterface.so.6"

# LayerShellQt::Window enums (from layer-shell-qt's window.h).
_ANCHOR_ALL = 1 | 2 | 4 | 8          # top | bottom | left | right
_LAYER_TOP = 2
# OnDemand: the compositor hands us the keyboard when the surface is
# activated, never sooner; Exclusive would swallow it entirely.
_KEYBOARD_ON_DEMAND = 2

# Mangled member symbols, pinned against layer-shell-qt's exported ABI.
# A missing symbol is treated like a missing library.
_SYMBOLS = {
    "get": "_ZN12LayerShellQt6Window3getEP7QWindow",
    "set_anchors": "_ZN12LayerShellQt6Window10setAnchorsE6QFlagsINS0_6AnchorEE",
    "set_layer": "_ZN12LayerShellQt6Window8setLayerENS0_5LayerE",
    "set_keyboard":
        "_ZN12LayerShellQt6Window24setKeyboardInteractivityENS0_21KeyboardInteractivityE",
    "set_exclusive_zone": "_ZN12LayerShellQt6Window16setExclusiveZoneEi",
    "set_activate": "_ZN12LayerShellQt6Window17setActivateOnShowEb",
    "set_active_screen": "_ZN12LayerShellQt6Window26setWantsToBeOnActiveScreenEb",
}

_funcs = None


def _load():
    """Resolve the library once. None when this machine cannot take it."""
    try:
        lib = ctypes.CDLL(_LIB)
        funcs = {name: getattr(lib, sym) for name, sym in _SYMBOLS.items()}
    except (OSError, AttributeError):
        return None
    funcs["get"].restype = ctypes.c_void_p
    funcs["get"].argtypes = [ctypes.c_void_p]
    for name in ("set_anchors", "set_layer", "set_keyboard",
                 "set_exclusive_zone"):
        funcs[name].argtypes = [ctypes.c_void_p, ctypes.c_int]
    for name in ("set_activate", "set_active_screen"):
        funcs[name].argtypes = [ctypes.c_void_p, ctypes.c_bool]
    return funcs


def attach_layer(qwindow):
    """Aim this QWindow at a fullscreen layer surface. False if not.

    The window must have a handle already (winId()) and must not have
    been shown yet; after return, showFullScreen() still sizes it, so
    both outcomes keep one code path in the app.
    """
    global _funcs
    if qwindow is None:
        return False
    from PyQt6 import sip
    from PyQt6.QtGui import QGuiApplication
    if QGuiApplication.platformName() != "wayland":
        return False
    if _funcs is None:
        _funcs = _load() or {}
    if not _funcs:
        return False
    win = _funcs["get"](ctypes.c_void_p(sip.unwrapinstance(qwindow)))
    if not win:
        return False
    _funcs["set_anchors"](win, _ANCHOR_ALL)
    _funcs["set_layer"](win, _LAYER_TOP)
    _funcs["set_keyboard"](win, _KEYBOARD_ON_DEMAND)
    _funcs["set_exclusive_zone"](win, 0)
    _funcs["set_activate"](win, True)
    _funcs["set_active_screen"](win, True)
    return True
