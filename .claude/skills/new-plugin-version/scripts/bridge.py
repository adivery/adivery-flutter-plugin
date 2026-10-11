#!/usr/bin/env python3
"""Check the Flutter plugin's bridges against an Adivery SDK AAR and against each other.

The Java plugin (android/src/main/java) calls the SDK's public API, so javac catches SDK
renames/removals - but not a callback the SDK added to a listener class the plugin subclasses (it
compiles fine and the event is silently never forwarded to Dart). And Dart (lib/) reaches Java
only by string over method channels: channel names, method names, event names, payload keys and
shapes, the platform-view type and its creation params. None of that is compile-checked. This is.

  bridge.py api   <sdk.aar> <repo>                       SDK classes the Java uses, with their API
  bridge.py check <sdk.aar> <repo> [--baseline <old.aar>]
      Java vs AAR: used SDK classes exist; static calls on them exist with that arity; listener
      `@Override`s exist in the SDK class; SDK callbacks not forwarded (with --baseline: only the
      ones new since it).
      Dart vs Java, per channel: methods Dart invokes vs `case`s Java handles (and the argument
      keys/shape Java reads, and invokeList/MapMethod on a case that returns `true`); events Java
      sends vs `case`s Dart handles (and payload keys/shape); platform-view type and creation
      params; Dart `_onX` callback fields that are called but never assigned.
      Exit 1 on errors. "NOT FORWARDED" items are reported for a human to decide, not errors.

Diff two `api` outputs to see what a new SDK version changed. Run with `python3 -I`; needs javap.
"""
import os
import re
import subprocess
import sys
import tempfile
import zipfile

SDK = "com.adivery.sdk."
# R8 gives internal classes/members one- or two-letter names that change between builds.
OBFUSCATED_NAME = re.compile(r"^[a-z]{1,2}$")
OBFUSCATED_TYPE = re.compile(r"\bcom\.adivery\.sdk\.(?:\w+\.)*[A-Za-z]{1,2}\b")
STRING_OR_COMMENT = re.compile(r"(\"(?:\\.|[^\"\\\n])*\"|'(?:\\.|[^'\\\n])*')|//[^\n]*|/\*.*?\*/", re.S)


def real(m):
    """Not an R8/Kotlin artifact: no obfuscated name or type, no synthetic `access$`/`$default`."""
    return not OBFUSCATED_NAME.match(m[0]) and "$" not in m[0] and not any(OBFUSCATED_TYPE.search(p) for p in m[1])


# ---------- AAR side ----------

def load_sdk(aar, wanted):
    """{fqcn: {"super": fqcn|None, "kind": str, "methods": [(name, params, static, final, abstract)]}}
    for the wanted classes and their com.adivery.sdk superclasses. A class missing from the AAR maps to None."""
    api = {}
    with tempfile.TemporaryDirectory() as tmp:
        jar = os.path.join(tmp, "classes.jar")
        with zipfile.ZipFile(aar) as z, open(jar, "wb") as f:
            f.write(z.read("classes.jar"))
        with zipfile.ZipFile(jar) as j:
            present = {n[:-6].replace("/", ".") for n in j.namelist() if n.endswith(".class")}
        todo = list(wanted)
        while todo:
            batch = [c for c in dict.fromkeys(todo) if c not in api]
            todo = []
            for c in batch:
                if c not in present:
                    api[c] = None
            names = [c for c in batch if c in present]
            if not names:
                continue
            out = subprocess.run(["javap", "-public", "-cp", jar] + names, capture_output=True, text=True).stdout
            cur = None
            for line in out.splitlines():
                line = line.strip()
                m = re.match(r"public (?:abstract |final )*(class|interface) ([\w.$]+)(?: extends ([\w.$]+))?", line)
                if m:
                    cur = api[m.group(2)] = {"kind": m.group(1), "super": m.group(3), "methods": []}
                    if m.group(3) and m.group(3).startswith(SDK) and m.group(3) not in api:
                        todo.append(m.group(3))
                    continue
                if cur is None or "(" not in line:
                    continue
                m = re.match(r"public ((?:[\w.$\[\]<>?,]+ )*?)([\w.$\[\]<>?,]+ )?([\w$]+)\((.*)\);$", line)
                if not m or m.group(2) is None:  # constructors ("public com.adivery.sdk.X(...)") don't match
                    continue
                mods, name = m.group(1).split(), m.group(3)
                params = tuple(p.strip() for p in re.split(r",(?![^<]*>)", m.group(4)) if p.strip())
                cur["methods"].append((name, params, "static" in mods, "final" in mods, "abstract" in mods))
    return api


def all_methods(api, fqcn):
    seen, out = set(), []
    while fqcn and fqcn.startswith(SDK) and api.get(fqcn):
        for m in api[fqcn]["methods"]:
            if (m[0], m[1]) not in seen:
                seen.add((m[0], m[1]))
                out.append(m)
        fqcn = api[fqcn]["super"]
    return out


def callbacks(api, fqcn):
    """Methods a subclass can usefully override: public, non-static, non-final, real names/types."""
    return [m for m in all_methods(api, fqcn) if not m[2] and not m[3] and real(m)]


# ---------- source helpers ----------

def strip_comments(src):
    """Blank out comments (keeping newlines, so line numbers hold) but not strings that contain //."""
    return STRING_OR_COMMENT.sub(lambda m: m.group(1) or re.sub(r"[^\n]", " ", m.group(0)), src)


def read_tree(root, exts):
    files = {}
    for d, dirs, fs in os.walk(root):
        dirs[:] = [x for x in dirs if x not in ("build", ".dart_tool")]
        for f in fs:
            if f.endswith(exts):
                p = os.path.join(d, f)
                files[p] = strip_comments(open(p, encoding="utf-8").read())
    return files


def matching(src, start, open_ch, close_ch):
    """Index just past the bracket matching src[start] (which must be open_ch)."""
    depth = 0
    for i in range(start, len(src)):
        if src[i] == open_ch:
            depth += 1
        elif src[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
    return len(src)


def split_args(text):
    depth, args, cur = 0, [], ""
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            args.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        args.append(cur.strip())
    return args


def call_args(src, paren_idx):
    end = matching(src, paren_idx, "(", ")")
    return split_args(src[paren_idx + 1:end - 1])


def lineno(src, pos):
    return src.count("\n", 0, pos) + 1


def first_literal(expr):
    m = re.search(r"[\"']([^\"']*)[\"']", expr or "")
    return m.group(1) if m else None


def case_blocks(body):
    """[(label, block_text, offset_in_body)] for each `case "label":` in a switch body."""
    labels = list(re.finditer(r"case\s+[\"'](\w+)[\"']\s*:", body))
    out = []
    for i, m in enumerate(labels):
        end = labels[i + 1].start() if i + 1 < len(labels) else len(body)
        d = re.search(r"\bdefault\s*:", body[m.end():end])
        out.append((m.group(1), body[m.end():m.end() + d.start()] if d else body[m.end():end], m.start()))
    return out


def map_keys(expr):
    """Keys of a literal map `{"k": v, ...}`, or None if expr isn't one."""
    expr = expr.strip()
    if not expr.startswith("{"):
        return None
    return set(re.findall(r"[\"'](\w+)[\"']\s*:", expr))


# ---------- Java side ----------

def java_sdk_refs(java):
    """({short name: fqcn} for imports, set of every SDK fqcn the Java names)."""
    imports, fq = {}, set()
    for src in java.values():
        for m in re.finditer(r"^import (com\.adivery\.sdk\.[\w.]+);", src, re.M):
            imports[m.group(1).rsplit(".", 1)[1]] = m.group(1)
        fq.update(re.findall(r"\b(com\.adivery\.sdk\.(?:[a-z]\w*\.)*[A-Z]\w*)", src))
    return imports, set(imports.values()) | fq


JAVA_METHOD = re.compile(r"(?:public|private|protected)\s+(?:static\s+)?(?:final\s+)?(?:[\w.<>\[\]?,]+\s+)+?(\w+)\s*\(")


def java_channels(java):
    """Per channel prefix: {"handles": {method: info}, "emits": {event: [info]}, "files": [path]}."""
    channels = {}
    for path, src in sorted(java.items()):
        c = re.search(r"new\s+MethodChannel\s*\(", src)
        if not c:
            continue
        args = call_args(src, c.end() - 1)
        name = first_literal(args[-1]) if args else None
        if name is None:
            continue
        ch = channels.setdefault(name, {"handles": {}, "emits": {}, "files": []})
        ch["files"].append(path)

        h = re.search(r"public\s+void\s+onMethodCall\s*\([^)]*\)\s*\{", src)
        if h:
            body_start = h.end() - 1
            body = src[body_start:matching(src, body_start, "{", "}")]
            for label, block, off in case_blocks(body):
                ch["handles"][label] = {
                    "keys": set(re.findall(r"call\.argument\(\s*\"(\w+)\"\s*\)", block)),
                    "scalar": bool(re.search(r"call\.arguments\b", block)),
                    "own_result": bool(re.search(r"result\.(?:success|error)\s*\(", block)),
                    "where": "%s:%d" % (path, lineno(src, body_start + off)),
                }

        for e in re.finditer(r"\b\w*[cC]hannel\.invokeMethod\s*\(", src):
            args = call_args(src, e.end() - 1)
            event = first_literal(args[0]) if args else None
            if event is None:
                continue
            payload = args[1] if len(args) > 1 else "null"
            headers = [m for m in JAVA_METHOD.finditer(src, 0, e.start())]
            method_body = src[headers[-1].start():e.start()] if headers else ""
            keys = set(re.findall(r"\b%s\.put\(\s*\"(\w+)\"" % re.escape(payload), method_body)) \
                if re.match(r"^\w+$", payload) else set()
            shape = "none" if payload == "null" else ("map" if keys else "scalar")
            ch["emits"].setdefault(event, []).append({
                "shape": shape, "keys": keys, "where": "%s:%d" % (path, lineno(src, e.start()))})
    return channels


# ---------- Dart side ----------

def dart_classes(dart):
    """[(path, class name, body, body offset)]"""
    out = []
    for path, src in sorted(dart.items()):
        for m in re.finditer(r"^(?:abstract\s+)?class\s+(\w+)[^{]*\{", src, re.M):
            start = m.end() - 1
            out.append((path, m.group(1), src[start:matching(src, start, "{", "}")], start))
    return out


# ---------- commands ----------

def cmd_api(aar, repo):
    java = read_tree(os.path.join(repo, "android", "src", "main", "java"), (".java",))
    _, used = java_sdk_refs(java)
    api = load_sdk(aar, sorted(used))
    # One block per used class with inherited SDK methods folded in, so a method moving to a
    # superclass between versions doesn't show up as a change.
    for fqcn in sorted(used):
        info = api.get(fqcn)
        if info is None:
            print("MISSING %s" % fqcn)
            continue
        print("%s %s" % (info["kind"], fqcn[len(SDK):]))
        for name, params, static, final, abstract in sorted(m for m in all_methods(api, fqcn) if real(m)):
            mods = " ".join(x for x, on in (("static", static), ("final", final), ("abstract", abstract)) if on)
            print("  %s%s(%s)" % (mods + " " if mods else "", name, ", ".join(params)))


def cmd_check(aar, repo, baseline=None):
    java = read_tree(os.path.join(repo, "android", "src", "main", "java"), (".java",))
    dart = read_tree(os.path.join(repo, "lib"), (".dart",))
    imports, used = java_sdk_refs(java)
    api = load_sdk(aar, sorted(used))
    base = load_sdk(baseline, sorted(used)) if baseline else None
    errors, warnings, unforwarded, checked = [], [], [], 0
    rel = lambda p: os.path.relpath(p, repo)
    relw = lambda w: (lambda p, n: "%s:%s" % (rel(p), n))(*w.rsplit(":", 1))

    # --- Java vs AAR ---
    for fqcn in sorted(used):
        checked += 1
        if api.get(fqcn) is None:
            errors.append("%s - used by the Java, not in the AAR" % fqcn)

    for path, src in sorted(java.items()):
        # Listener subclasses: anonymous `new X() {` and `class Y extends X [implements ...] {`.
        blocks = []
        for m in re.finditer(r"\bnew\s+(\w+)\s*\(\s*\)\s*\{", src):
            blocks.append((m.group(1), m.end() - 1, m.start(), True))
        for m in re.finditer(r"\bclass\s+\w+\s+extends\s+(\w+)(\s+implements\s+[^{]+)?\{", src):
            # A class that also implements an interface (PlatformView) has overrides that aren't
            # the SDK's (getView, dispose); javac checks those, so don't flag them here.
            blocks.append((m.group(1), m.end() - 1, m.start(), not m.group(2)))
        for short, brace, start, strict in blocks:
            cls = imports.get(short)
            if not cls or not api.get(cls):
                continue
            block = src[brace:matching(src, brace, "{", "}")]
            overrides = {}
            for o in re.finditer(r"@Override\s+(?:public|protected)\s+(?:[\w.<>\[\]?,]+\s+)+?(\w+)\s*\(", block):
                overrides.setdefault(o.group(1), set()).add(len(call_args(block, o.end() - 1)))
            sdk_methods = all_methods(api, cls)
            for name, arities in sorted(overrides.items()):
                have = {len(p) for n, p, *_ in sdk_methods if n == name}
                if not have and not strict:
                    continue
                checked += 1
                if not have:
                    errors.append("%s:%d: @Override %s.%s - no such method in the AAR (won't compile)" % (
                        rel(path), lineno(src, start), short, name))
                elif not arities & have:
                    errors.append("%s:%d: @Override %s.%s%s - AAR has arity %s" % (
                        rel(path), lineno(src, start), short, name, sorted(arities), sorted(have)))
            base_keys = {(n, p) for n, p, *_ in callbacks(base, cls)} if base and base.get(cls) else None
            for n, p, *_ in callbacks(api, cls):
                if len(p) in overrides.get(n, set()):
                    continue
                checked += 1
                if base_keys is None or (n, p) not in base_keys:
                    unforwarded.append("%s:%d: %s.%s(%s)%s" % (
                        rel(path), lineno(src, start), short, n, ", ".join(p),
                        "  [new since baseline]" if base_keys is not None else ""))

        # Static calls on imported SDK classes, e.g. Adivery.prepareOfferWallAd(activity, id).
        for c in re.finditer(r"\b([A-Z]\w+)\.(\w+)\s*\(", src):
            cls = imports.get(c.group(1))
            if not cls or not api.get(cls):
                continue
            name, nargs = c.group(2), len(call_args(src, c.end() - 1))
            statics = {len(p) for n, p, st, *_ in all_methods(api, cls) if n == name and st}
            checked += 1
            if not statics:
                errors.append("%s:%d: %s.%s - no such static method in the AAR" % (
                    rel(path), lineno(src, c.start()), c.group(1), name))
            elif nargs not in statics:
                errors.append("%s:%d: %s.%s called with %d args - AAR has %s" % (
                    rel(path), lineno(src, c.start()), c.group(1), name, nargs, sorted(statics)))

    # --- Dart <-> Java over method channels ---
    jch = java_channels(java)
    classes = dart_classes(dart)
    invoked = {}   # channel -> set(method)
    handled = {}   # channel -> {event: [(where, reads)]}
    for path, cls, body, off in classes:
        src = dart[path]
        c = re.search(r"MethodChannel\s*\(", body)
        if not c:
            continue
        name = first_literal(call_args(body, c.end() - 1)[0])
        where = lambda pos: "%s:%d" % (rel(path), lineno(src, off + pos))
        if name not in jch:
            errors.append("%s: Dart class %s opens channel \"%s\" - no Java `new MethodChannel(..., \"%s...\")`" % (
                where(c.start()), cls, name, name))
            continue
        java_side = jch[name]

        # Dart -> Java method calls.
        for i in re.finditer(r"\b\w*[cC]hannel\.(invoke(?:List|Map)?Method)(?:<[^>]*>)?\s*\(", body):
            args = call_args(body, i.end() - 1)
            meth = first_literal(args[0]) if args else None
            if meth is None:
                continue
            checked += 1
            invoked.setdefault(name, set()).add(meth)
            h = java_side["handles"].get(meth)
            w = "%s: %s.%s(\"%s\") on \"%s\"" % (where(i.start()), cls, i.group(1), meth, name)
            if h is None:
                errors.append(w + " - Java's onMethodCall has no case \"%s\" (notImplemented)" % meth)
                continue
            payload = args[1] if len(args) > 1 else None
            keys = map_keys(payload) if payload else None
            if h["keys"]:
                if keys is None:
                    errors.append(w + " - Java reads call.argument(%s) but Dart sends %s" % (
                        ", ".join(sorted(h["keys"])), "a scalar" if payload else "nothing"))
                else:
                    for k in sorted(h["keys"] - keys):
                        errors.append(w + " - Java reads call.argument(\"%s\"), Dart's map has %s" % (k, sorted(keys)))
            if h["scalar"] and (payload is None or keys is not None):
                errors.append(w + " - Java casts call.arguments as a value, Dart sends %s" % (
                    "a map" if payload else "nothing"))
            if keys:
                for k in sorted(keys - h["keys"]):
                    warnings.append(w + " - sends key \"%s\" that Java never reads" % k)
            if i.group(1) != "invokeMethod" and not h["own_result"]:
                errors.append(w + " - Java's case falls through to result.success(true); %s casts that bool "
                              "to a %s and throws" % (i.group(1), "List" if "List" in i.group(1) else "Map"))

        # Java -> Dart events: what this class's handler reads.
        for label, block, boff in case_blocks(body):
            reads = set(re.findall(r"\bcall\.arguments\s*\[\s*[\"'](\w+)", block))
            for v in re.findall(r"\b(\w+)\s*=\s*call\.arguments\b", block):
                reads |= set(re.findall(r"\b%s\s*\[\s*[\"'](\w+)" % re.escape(v), block))
            cast = re.search(r"call\.arguments\s+as\s+(\w+)", block)
            shape = "map" if reads or (cast and cast.group(1).startswith("Map")) else (
                "scalar" if cast else "opaque")
            handled.setdefault(name, {}).setdefault(label, []).append(
                (where(boff), shape, reads, cast.group(1) if cast else None))

    for name, ch in sorted(jch.items()):
        for meth, h in sorted(ch["handles"].items()):
            if meth not in invoked.get(name, set()):
                warnings.append("%s: Java case \"%s\" on \"%s\" isn't invoked from lib/ (not exposed to Dart)" % (
                    relw(h["where"]), meth, name))
        dart_cases = handled.get(name, {})
        for event, sends in sorted(ch["emits"].items()):
            for s in sends:
                checked += 1
                w = "%s: Java sends \"%s\" on \"%s\"" % (relw(s["where"]), event, name)
                if event not in dart_cases:
                    errors.append(w + " - no Dart `case \"%s\":` handles it (silently dropped)" % event)
                    continue
                for dwhere, shape, reads, cast in dart_cases[event]:
                    if shape == "map" and s["shape"] != "map":
                        errors.append(w + " as %s - %s reads it as a map %s" % (s["shape"], dwhere, sorted(reads)))
                    elif shape == "map":
                        for k in sorted(reads - s["keys"]):
                            errors.append(w + " - %s reads \"%s\", Java puts %s" % (dwhere, k, sorted(s["keys"])))
                    elif shape == "scalar" and s["shape"] != "scalar":
                        errors.append(w + " as %s - %s casts call.arguments as %s" % (s["shape"], dwhere, cast))
        for event, cases in sorted(dart_cases.items()):
            if event not in ch["emits"]:
                for dwhere, *_ in cases:
                    warnings.append("%s: Dart handles \"%s\" on \"%s\" but Java never sends it" % (dwhere, event, name))

    # --- Platform views: type and creation params ---
    registered = {}
    view_keys = set()
    for path, src in java.items():
        for r in re.finditer(r"registerViewFactory\s*\(\s*\"([^\"]+)\"", src):
            registered[r.group(1)] = path
        if re.search(r"implements\s+[^{]*\bPlatformView\b", src):
            view_keys |= set(re.findall(r"\.get\(\s*\"(\w+)\"\s*\)", src))
    for path, src in sorted(dart.items()):
        for v in re.finditer(r"viewType\s*:\s*[\"']([^\"']+)[\"']", src):
            checked += 1
            w = "%s:%d: viewType \"%s\"" % (rel(path), lineno(src, v.start()), v.group(1))
            if v.group(1) not in registered:
                errors.append(w + " - Java never registerViewFactory()s it")
                continue
            p = re.search(r"creationParams\s*:\s*\{", src[v.start():])
            if not p:
                continue
            brace = v.start() + p.end() - 1
            keys = map_keys(src[brace:matching(src, brace, "{", "}")]) or set()
            for k in sorted(view_keys - keys):
                errors.append(w + " - the PlatformView reads \"%s\", creationParams has %s" % (k, sorted(keys)))
            for k in sorted(keys - view_keys):
                warnings.append(w + " - creationParams \"%s\" is never read by the PlatformView" % k)

    # --- Dart callback fields: a field that's called but never assigned never fires ---
    for path, cls, body, off in classes:
        src = dart[path]
        for f in re.finditer(r"\b(?:static\s+)?(?:final\s+)?\w+\?\s+(_on\w+)\s*;", body):
            field = f.group(1)
            checked += 1
            assigned = re.search(r"\b%s\s*=[^=]" % re.escape(field), body)
            called = re.search(r"\b%s\s*(?:\?\.call|!)\s*\(" % re.escape(field), body)
            w = "%s:%d: %s.%s" % (rel(path), lineno(src, off + f.start()), cls, field)
            if called and not assigned:
                errors.append(w + " is called but never assigned (add it to addListener)")
            elif assigned and not called:
                warnings.append(w + " is assigned but never called (no `case` invokes it)")

    for w in warnings:
        print("WARN          " + w)
    for u in unforwarded:
        print("NOT FORWARDED " + u)
    for e in errors:
        print("ERROR         " + e)
    print("%d reference(s) checked: %d error(s), %d warning(s), %d not forwarded%s against %s" % (
        checked, len(errors), len(warnings), len(unforwarded),
        " (new since baseline)" if baseline else "", os.path.basename(aar)))
    return 1 if errors else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) == 3 and a[0] == "api":
        cmd_api(a[1], a[2])
    elif len(a) == 3 and a[0] == "check":
        sys.exit(cmd_check(a[1], a[2]))
    elif len(a) == 5 and a[0] == "check" and a[3] == "--baseline":
        sys.exit(cmd_check(a[1], a[2], a[4]))
    else:
        sys.exit(__doc__)
