"""Web source: URLs open directly, prefixes search, bare text asks
SearXNG - a free and open source metasearch engine - instead of one
company's results. Opens in the default browser, never in the runner."""

import os
from urllib.parse import quote_plus, urlparse

from .base import open_external

# SearXNG instances, best first (the public searx.space ranking). It is
# open source, so any instance may come and go - point MAID_RUNNER_SEARX
# at another host from this list to switch.
SEARX = [
    "https://search.jeremyh.xyz",
    "https://searxng.site",
    "https://searx.tiekoetter.com",
    "https://searx.linxx.net",
    "https://search.ctq.ro",
    "https://priv.au",
    "https://www.isci.si",
    "https://search.femboy.ad",
    "https://searx.ononoki.org",
    "https://search.yuri.llc",
]

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


def searx_base():
    """The instance bare text searches on; the first one unless told."""
    return (os.environ.get("MAID_RUNNER_SEARX") or SEARX[0]).rstrip("/")


def searx_url(query):
    return f"{searx_base()}/search?q={quote_plus(query)}"


def _host():
    return urlparse(searx_base()).netloc


def _quote(s):
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
            return [(q, "duckduckgo bang", "internet-web-browser",
                     f"https://duckduckgo.com/?q={_quote(q)}")]
        if "://" in q:
            return [(q, "open URL", "internet-web-browser", q)]
        first, _, rest = q.partition(" ")
        if first in SHORTCUTS and rest:
            label, tmpl = SHORTCUTS[first]
            return [(rest, f"search {label}", "internet-web-browser", tmpl.format(_quote(rest)))]
        if _looks_like_url(q):
            url = q if "://" in q else "https://" + q
            return [(q, "open URL", "internet-web-browser", url)]
        if len(q) > 1:
            return [(q, f"search searx · {_host()}", "internet-web-browser", searx_url(q))]
        return []

    def activate(self, url):
        if "://" not in url:
            url = "https://" + url
        return open_external(url)
