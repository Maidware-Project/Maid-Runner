"""Web source: URLs open directly, prefixes search, bare text asks
DuckDuckGo. Opens in the default browser, never in the runner."""

from PyQt6.QtCore import QUrl
from PyQt6.QtGui import QDesktopServices

SHORTCUTS = {
    "g": ("Google", "https://www.google.com/search?q={}"),
    "ddg": ("DuckDuckGo", "https://duckduckgo.com/?q={}"),
    "yt": ("YouTube", "https://www.youtube.com/results?search_query={}"),
    "wiki": ("Wikipedia", "https://en.wikipedia.org/wiki/Special:Search?search={}"),
    "gh": ("GitHub", "https://github.com/search?q={}&type=repositories"),
    "aw": ("Arch Wiki", "https://wiki.archlinux.org/index.php?search={}"),
    "aur": ("AUR", "https://aur.archlinux.org/packages?K={}"),
    "so": ("Stack Overflow", "https://stackoverflow.com/search?q={}"),
}


def _quote(s):
    from urllib.parse import quote_plus
    return quote_plus(s)


def _looks_like_url(text):
    t = text.strip()
    if " " in t or "." not in t:
        return False
    if "://" in t:
        return True
    return all(c.isalnum() or c in ".-_~:/?#[]@!$&'()*+,;=%" for c in t)


class WebSource:
    name = "Web"
    show_subtitles = False

    def items(self, query):
        q = (query or "").strip()
        if not q:
            return []
        if q.startswith("!") and len(q) > 1:
            # duckduckgo bang: resolved server-side (!yt, !w, !aw, ...
            # thousands more). never maintained here, never stale.
            return [(q, "duckduckgo bang",
                     f"https://duckduckgo.com/?q={_quote(q)}")]
        if "://" in q:
            return [(q, "open URL", q)]
        first, _, rest = q.partition(" ")
        if first in SHORTCUTS and rest:
            label, tmpl = SHORTCUTS[first]
            return [(rest, f"search {label}", tmpl.format(_quote(rest)))]
        if _looks_like_url(q):
            url = q if "://" in q else "https://" + q
            return [(q, "open URL", url)]
        if len(q) > 1:
            label, tmpl = SHORTCUTS["ddg"]
            return [(q, f"search {label}", tmpl.format(_quote(q)))]
        return []

    def activate(self, url):
        if "://" not in url:
            url = "https://" + url
        QDesktopServices.openUrl(QUrl(url))
        return True
