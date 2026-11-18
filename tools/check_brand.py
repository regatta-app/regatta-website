#!/usr/bin/env python3
"""Brand check for the website: new lines in site/ stay inside the brand guidelines (BRAND.md, v1.0, Daniela, 18 Nov 2026).

Purpose: BRAND.md section 7 (rules 1, 2, 5, 6, 8, 9 of section 6 apply here too). This check reads only the lines a branch
ADDS to the site's pages, styles and scripts, compared with a base ref, so the old off-guide values that are there today
(BRAND.md section 8) never fail it. Clean-ups of old values are their own proposal. It lives in tools/, outside site/, so
it is never published.
Inputs: `git diff -U0 <base>` of site/**/*.html, *.css, *.js (the working tree against the base, so uncommitted lines count
too), or a unified diff given with --diff. Read as text; nothing is built or run.
Outputs: one line per finding (file:line, what, the value, the nearest allowed value) and exit 1; or an ok line and exit 0.
With no changed line in site/ it prints ok and exits 0. A base ref that cannot be found is reported as skipped, exit 0.
--all counts the off-guide values in the whole site today, as a report only, and always exits 0.
Callers: by hand before a PR that touches site/ (put its result in the PR body).

What is flagged on an added line:
  1. a font size not on the website scale (px; phones 24, 32, 40 too), a decimal px size, a rem, vw or clamp() size;
  2. a font family other than Tenor Sans, Inter or Playfair Display SC first in the list (system fallbacks after it are
     fine; Cormorant SC, the wordmark today, is tolerated on unchanged lines only);
  3. a font weight other than 400 or 600 (500 is retired);
  4. a hex, rgb() or rgba() colour not in ALLOWED_COLOURS (a retired one names its replacement);
  5. a section title `<h2` whose font size is not 44;
  6. a corner radius not in RADII;
  7. orange (#F05910, rgba(240,89,16,..), the retired #FF5A1F) on a line that also has :hover, :focus, :active or border;
  8. an outside font link (Google Fonts and the like): fonts are self-hosted.
A new inline style attribute is printed as a note and does not fail the check: the website is styled inline today and
BRAND.md section 7 does not carry the app's no-inline-style rule (its rule 2 asks for one shared stylesheet instead).
Its limits, said plainly: it reads line by line, so a rule split over lines is judged by the line the value is on; a
moved line counts as added; a unitless size (an SVG attribute font-size="7") is not read. It never changes a file.

Run from the repository root:  python3 tools/check_brand.py                    (added lines vs origin/main)
                               python3 tools/check_brand.py --base <ref>
                               python3 tools/check_brand.py --all              (report of the whole site, exit 0)
                               python3 tools/check_brand.py --diff <file|->    (read a unified diff instead of git)
"""
import argparse, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------- the allowed values (BRAND.md v1.0): edit only here
SIZES_PX = [13, 15, 17, 20, 28, 44, 64] + [24, 32, 40]            # BRAND.md section 3, website scale + phone sizes
SIZES_PX = sorted(SIZES_PX)
SECTION_TITLE_PX = 44                                             # section 7 rule 3 (32 on phones, set in the stylesheet)
WEIGHTS = [400, 600]                                              # section 3; 'normal' is 400; 500 is retired
FAMILIES = ['tenor sans', 'inter', 'playfair display sc']         # section 2, website column
FONT_VARS = ['--rg-fh', '--rg-fb', '--rg-fm']                     # the app-demo widgets' own font variables
TOLERATED_FAMILIES = ['cormorant sc']                             # the wordmark today: unchanged lines only
FALLBACKS = ['serif', 'sans-serif', 'monospace', 'system-ui', '-apple-system', 'blinkmacsystemfont', 'segoe ui',
             'georgia', 'times new roman', 'helvetica neue', 'helvetica', 'arial', 'playfair display', 'inherit']
RADII = ['10px', '7px', '999px', '50%', '0']                      # section 5
ALLOWED_COLOURS = (
    ['#0D3769', '#F5EEE3', '#CAA229', '#F05910']                  # brand: navy, cream, gold, orange
    + ['#071833', '#F3F6FB', '#4E5A6B', '#C3CFDF', '#8397B3']     # website extras: deep navy, light text, grey, line, muted
)
RETIRED_COLOURS = {'#FF5A1F': '#F05910 (Orange)', '#7E8DA6': '#8397B3 (Muted)', '#3A5BB0': 'a colour from BRAND.md section 4'}
OPEN_COLOURS = {}
FONT_LINK_HOSTS = ['fonts.googleapis', 'fonts.gstatic', 'use.typekit', 'fonts.bunny', 'fonts.adobe']
FRONT_END = ['site/**/*.html', 'site/**/*.css', 'site/**/*.js', 'site/*.html', 'site/*.css', 'site/*.js']
NOTE_ONLY = {'new inline style'}                                  # printed, never fails (see above)
# ---------------------------------------------------------------- end of the allowed values

HEX = re.compile(r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b')
RGB = re.compile(r'rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:[,/]\s*([\d.]+%?)\s*)?\)', re.I)
SIZE = re.compile(r'(?:font-size|fontSize)\s*[:=]\s*[\'"`]?([^;}"\'`\n]+)', re.I)
SHORTHAND = re.compile(r'(?<![\w-])font\s*:\s*([^;}"\'`\n]+)', re.I)
FAMILY = re.compile(r'(?:font-family|fontFamily)\s*[:=]\s*([^;}`\n]+)', re.I)
WEIGHT = re.compile(r'(?:font-weight|fontWeight)\s*[:=]\s*[\'"`]?([\w.-]+)', re.I)
RADIUS = re.compile(r'(?:border-radius|borderRadius|border-(?:top|bottom)-(?:left|right)-radius)\s*[:=]\s*[\'"`]?([^;}"\'`\n]+)', re.I)
INLINE = re.compile(r'\bstyle\s*=\s*\\?["\']')
STATE = re.compile(r':hover|:focus|:active|\bborder(?![\w-]*radius)', re.I)
H2 = re.compile(r'<h2\b[^>]*>', re.I)
VAR = re.compile(r'var\([^()]*(?:\([^()]*\)[^()]*)*\)')


def rgba_key(r, g, b, a=1.0):
    return (int(r), int(g), int(b), round(float(a), 2))


def colour_key(text):
    """(r, g, b, alpha) of a colour literal, None when it does not parse."""
    if text.startswith('#'):
        h = text[1:]
        if len(h) in (3, 4):
            h = ''.join(c * 2 for c in h)
        a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
        return rgba_key(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
    m = RGB.fullmatch(text.strip())
    if not m:
        return None
    a = m.group(4)
    a = 1.0 if a is None else (float(a[:-1]) / 100 if a.endswith('%') else float(a))
    return rgba_key(m.group(1), m.group(2), m.group(3), a)


ALLOWED = {colour_key(c): c for c in ALLOWED_COLOURS}
RETIRED = {colour_key(c): (c, v) for c, v in RETIRED_COLOURS.items()}
OPEN = {colour_key(c): (c, v) for c, v in OPEN_COLOURS.items()}


def nearest_colour(key):
    return min(ALLOWED, key=lambda k: sum((x - y) ** 2 for x, y in zip(k[:3], key[:3])) + (255 * (k[3] - key[3])) ** 2)


def is_orange(text):
    k = colour_key(text)
    return bool(k) and (k[:3] in ((240, 89, 16), (255, 90, 31)))


def nearest(n, steps):
    return min(steps, key=lambda s: (abs(s - n), s))


def size_findings(value):
    """[(what, value, nearest)] for one font-size value."""
    v = re.sub(r'\s*!important\s*$', '', VAR.sub(' ', value).strip())
    out = []
    if re.search(r'clamp\(|\d(?:\.\d+)?rem\b|\d(?:\.\d+)?v[wh]\b', v):
        out.append(('font size not in px', v, 'a px step: %s' % ', '.join(map(str, SIZES_PX))))
        return out
    for m in re.finditer(r'(?<![\w.])(\d+(?:\.\d+)?)px\b', v):
        n = float(m.group(1))
        if n != int(n):
            out.append(('decimal font size', m.group(0), '%dpx' % nearest(n, SIZES_PX)))
        elif int(n) not in SIZES_PX:
            out.append(('font size off the scale', m.group(0), '%dpx' % nearest(n, SIZES_PX)))
    return out


QUOTES = '\'"`'


def family_findings(value, tolerate=False):
    value = re.split(r'"\s*(?:/?>|[\w-]+=)', value)[0]                # the end of an HTML style attribute
    v = re.sub(r'!important', '', value).strip().strip(QUOTES + ',').strip()
    if re.fullmatch(r'(?:inherit|initial|unset)', v, re.I):
        return []
    if re.fullmatch(r'var\(\s*(?:%s)\b[^)]*\)' % '|'.join(map(re.escape, FONT_VARS)), v):
        return []
    names = [n.strip().strip(QUOTES + '\\ ').lower() for n in VAR.sub('', v).split(',') if n.strip()]
    if not names:
        return []
    first, rest = names[0], names[1:]
    out = []
    if first in TOLERATED_FAMILIES:
        if not tolerate:
            out.append(('font family not in the guide', v[:60], "'Playfair Display SC' (the wordmark, BRAND.md section 2)"))
    elif first not in FAMILIES:
        out.append(('font family not in the guide', v[:60], "'Tenor Sans' | 'Inter' | 'Playfair Display SC'"))
    bad = [n for n in rest if n not in FALLBACKS + FAMILIES + TOLERATED_FAMILIES]
    if bad and not out:
        out.append(('font family not in the guide', ', '.join(bad)[:60], 'system fallbacks only after the brand face'))
    return out


def weight_findings(value):
    v = value.strip().lower()
    if v in ('inherit', 'initial', 'unset', 'normal') or v.startswith('var'):
        return []
    n = {'bold': 700, 'bolder': 700, 'lighter': 300}.get(v)
    if n is None:
        try:
            n = int(float(v))
        except ValueError:
            return []
    return [] if n in WEIGHTS else [('font weight not 400 or 600', value.strip(), str(nearest(n, WEIGHTS)))]


def shorthand_findings(value, tolerate=False):
    """font: [style] [weight] size[/line-height] family"""
    v = VAR.sub(' VAR ', value)
    out = []
    m = re.search(r'(?<![\w.#-])(\d+(?:\.\d+)?(?:px|rem)|clamp\([^)]*\))(?:\s*/\s*[\w.]+)?', v)
    if not m:
        return []
    out += size_findings(m.group(1))
    head = v[:m.start()].split()
    for w in head:
        if re.fullmatch(r'\d{3}|bold|bolder|lighter', w, re.I):
            out += weight_findings(w)
    fam = value[value.find(m.group(1)) + len(m.group(1)):] if m.group(1) in value else ''
    fam = re.sub(r'^\s*/\s*[\w.]+', '', fam).strip()
    if fam:
        out += family_findings(fam, tolerate)
    return out


def radius_findings(value):
    v = VAR.sub(' ', value).replace('!important', '').strip()
    out = []
    for part in v.split():
        if part not in RADII and not re.fullmatch(r'0(?:px)?|inherit|initial', part):
            n = re.fullmatch(r'(\d+(?:\.\d+)?)px', part)
            near = nearest(float(n.group(1)), [10, 7, 999]) if n else None
            out.append(('corner radius off the guide', part, '%spx' % near if near is not None else '10px | 7px | 999px | 50%'))
    return out


def colour_findings(line):
    out = []
    for m in list(HEX.finditer(line)) + list(RGB.finditer(line)):
        text = m.group(0)
        if text.startswith('#') and len(text) == 4 and not re.search(r'(?:color|background|fill|stroke|border|outline|shadow)[^;]*$', line[:m.start()], re.I):
            continue                                              # a short #abc outside a colour property is an id or anchor
        k = colour_key(text)
        if k is None or k in ALLOWED:
            continue
        if k in RETIRED:
            out.append(('retired colour', text, RETIRED[k][1]))
        elif k in OPEN:
            out.append(('colour not decided', text, OPEN[k][1]))
        else:
            out.append(('colour not in the guide', text, ALLOWED[nearest_colour(k)]))
    return out


def line_findings(line, tolerate=False):
    """Every finding on one line of HTML, CSS or JS: [(what, value, nearest allowed)]. tolerate: an unchanged line (--all),
    where Cormorant SC is not counted."""
    out = []
    for m in SIZE.finditer(line):
        out += size_findings(m.group(1))
    for m in SHORTHAND.finditer(line):
        out += shorthand_findings(m.group(1), tolerate)
    for m in FAMILY.finditer(line):
        out += family_findings(m.group(1), tolerate)
    for m in WEIGHT.finditer(line):
        out += weight_findings(m.group(1))
    for m in RADIUS.finditer(line):
        out += radius_findings(m.group(1))
    out += colour_findings(line)
    for m in H2.finditer(line):
        for s in re.finditer(r'font-size\s*:\s*(\d+(?:\.\d+)?)px', m.group(0)):
            if float(s.group(1)) != SECTION_TITLE_PX:
                out.append(('section title not 44', s.group(1) + 'px', '%dpx (32px on phones, in the stylesheet)' % SECTION_TITLE_PX))
    for _ in INLINE.finditer(line):
        out.append(('new inline style', 'style="..."', 'a class in the shared stylesheet (BRAND.md section 7 rule 2)'))
    if STATE.search(line) and any(is_orange(m.group(0)) for m in list(HEX.finditer(line)) + list(RGB.finditer(line))):
        out.append(('orange on hover, focus, click or a line', STATE.search(line).group(0), 'navy, gold or opacity: orange is for the logo and charts'))
    low = line.lower()
    for host in FONT_LINK_HOSTS:
        if host in low:
            out.append(('outside font link', host, 'self-hosted fonts (site/assets/fonts)'))
    return out


# ---------------------------------------------------------------- which files, which lines
def pattern_of(rel):
    return rel if rel.startswith('site/') and rel.endswith(('.html', '.css', '.js')) else None


def front_end_files():
    return sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'site').rglob('*')
                  if p.is_file() and p.suffix in ('.html', '.css', '.js'))


def file_lines(rel):
    try:
        return (ROOT / rel).read_text(encoding='utf-8', errors='replace').split('\n')
    except OSError:
        return []


def checked(rel):
    return rel.endswith(('.html', '.css', '.js')) and not rel.endswith('.svg') and pattern_of(rel)


def added_lines(diff_text):
    """[(file, line number, text)] for every added line of a unified diff with -U0."""
    out, rel, n = [], None, 0
    for ln in diff_text.split('\n'):
        if ln.startswith('+++ '):
            p = ln[4:].strip()
            rel = None if p == '/dev/null' else (p[2:] if p.startswith(('a/', 'b/')) else p).strip('"')
        elif ln.startswith('@@'):
            m = re.match(r'@@ -\S+ \+(\d+)(?:,\d+)? @@', ln)
            n = int(m.group(1)) if m else 0
        elif ln.startswith('+') and rel is not None:
            out.append((rel, n, ln[1:]))
            n += 1
    return out


def git_diff(base):
    def git(*args):
        return subprocess.run(['git', '-C', str(ROOT)] + list(args), capture_output=True, text=True)
    if git('rev-parse', '--verify', '-q', base + '^{commit}').returncode != 0:
        return None
    mb = git('merge-base', base, 'HEAD')
    ref = mb.stdout.strip() if mb.returncode == 0 and mb.stdout.strip() else base
    d = git('-c', 'core.quotePath=false', 'diff', '-U0', '--no-color', '--no-ext-diff', ref, '--',
            ':(glob)site/**/*.html', ':(glob)site/**/*.css', ':(glob)site/**/*.js')
    return d.stdout if d.returncode == 0 else None


def findings_for(added):
    return [(rel, n, what, value, near) for rel, n, text in added if checked(rel)
            for what, value, near in line_findings(text)]


def report_all():
    totals, per_file = {}, []
    for rel in front_end_files():
        counts = {}
        for ln in file_lines(rel):
            for what, _, _ in line_findings(ln, tolerate=True):
                counts[what] = counts.get(what, 0) + 1
                totals[what] = totals.get(what, 0) + 1
        per_file.append((rel, counts))
    print('brand report (whole site, report only; old lines never fail the default check):')
    for rel, counts in per_file:
        print('  %s: %d' % (rel, sum(counts.values())) + ('  (%s)' % ', '.join('%s %d' % kv for kv in sorted(counts.items())) if counts else ''))
    print('  total: %d' % sum(totals.values()) + ''.join('\n    %s: %d' % kv for kv in sorted(totals.items(), key=lambda kv: -kv[1])))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--base', default='origin/main', help='the ref the added lines are counted against (default origin/main)')
    ap.add_argument('--all', action='store_true', help='count off-guide values in the whole files; report only, exit 0')
    ap.add_argument('--diff', help='read a unified diff (-U0) from this file, or - for stdin, instead of running git')
    a = ap.parse_args()
    if a.all:
        return report_all()
    if a.diff:
        text = sys.stdin.read() if a.diff == '-' else Path(a.diff).read_text(encoding='utf-8')
    else:
        text = git_diff(a.base)
        if text is None:
            print('skipped: base ref %r not found or git failed, so no added lines to read (exit 0); '
                  'fetch it or pass --base' % a.base)
            return 0
    added = [x for x in added_lines(text) if checked(x[0])]
    every = findings_for(added)
    found = [f for f in every if f[2] not in NOTE_ONLY]
    notes = [f for f in every if f[2] in NOTE_ONLY]
    for rel, n, what, value, near in notes:
        print('  note %s:%d: %s (better: %s)' % (rel, n, what, near))
    if found:
        print('BRAND: %d finding(s) on added lines in site/ (BRAND.md):' % len(found))
        for rel, n, what, value, near in found:
            print('  %s:%d: %s: %s (allowed: %s)' % (rel, n, what, value, near))
        return 1
    print('ok: %d added line(s) in site/ checked against BRAND.md, no finding' % len(added)
          + (' (%d note(s) above, not failing)' % len(notes) if notes else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
