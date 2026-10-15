"""Calc source: safe arithmetic. AST allowlist only (no eval, no
names except a few math constants) - typed text is untrusted input."""

import ast
import math

_ALLOWED_BINOP = (ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Mod,
                  ast.Pow, ast.FloorDiv)
_ALLOWED_UNARY = (ast.UAdd, ast.USub)
_CONSTS = {"pi": math.pi, "e": math.e, "tau": math.tau}


def _eval(node):
    if isinstance(node, ast.Expression):
        return _eval(node.body)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.BinOp) and isinstance(node.op, _ALLOWED_BINOP):
        l, r = _eval(node.left), _eval(node.right)
        if isinstance(node.op, ast.Add):
            return l + r
        if isinstance(node.op, ast.Sub):
            return l - r
        if isinstance(node.op, ast.Mult):
            return l * r
        if isinstance(node.op, ast.Div):
            return l / r
        if isinstance(node.op, ast.Mod):
            return l % r
        if isinstance(node.op, ast.FloorDiv):
            return l // r
        return l ** r
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, _ALLOWED_UNARY):
        v = _eval(node.operand)
        return +v if isinstance(node.op, ast.UAdd) else -v
    if isinstance(node, ast.Name) and node.id in _CONSTS:
        return _CONSTS[node.id]
    raise ValueError("not arithmetic")


def looks_like_math(text):
    t = (text or "").strip()
    if len(t) < 1 or len(t) > 64:
        return False
    allowed = set("0123456789+-*/().%^ \tpieatau")
    return all(c in allowed for c in t) and any(c.isdigit() for c in t)


def compute(text):
    try:
        val = _eval(ast.parse(text.replace("^", "**"), mode="eval"))
    except Exception:
        return None
    if isinstance(val, float) and val.is_integer():
        val = int(val)
    return val


class CalcSource:
    name = "Calculator"
    show_subtitles = False

    def items(self, query):
        if not looks_like_math(query):
            return []
        val = compute(query)
        if val is None:
            return []
        return [(str(val), "enter copies to clipboard", "accessories-calculator", str(val))]

    def activate(self, payload):
        from PyQt6.QtWidgets import QApplication
        QApplication.clipboard().setText(payload)
        return True
