# Generates natives.c from KitABI.h: every env function registered with WAMR,
# implemented ones extern to the Swift host (wamr_ prefix), the rest stubs.
import re, sys

hdr, out = sys.argv[1], sys.argv[2]
text = open(hdr).read()
protos = re.findall(r"WABI\s+([^;]+);", text)

implemented = {
    "js_log", "gfx_clear", "gfx_save", "gfx_restore", "gfx_translate",
    "gfx_rotate", "gfx_scale", "gfx_set_alpha", "gfx_set_blend",
    "gfx_stroke_poly", "gfx_fill_poly", "gfx_fill_circle", "gfx_stroke_circle",
    "gfx_fill_rect", "gfx_stroke_rect", "evt_poll", "snd_by_name", "snd_play",
    "snd_stop", "snd_set_volume", "snd_set_pan", "store_get", "store_set",
    "gp_connected",
}

def ctype_tok(t):
    t = t.strip()
    if "*" in t: return "*"
    if t in ("float",): return "f"
    if t in ("double",): return "F"
    if "int64" in t: return "I"
    return "i"

def sig_and_params(p):
    m = re.match(r"([A-Za-z0-9_*\s]+?)\s*\b([a-z_0-9]+)\s*\((.*)\)$", p)
    ret, name, args = m.group(1).strip(), m.group(2), m.group(3).strip()
    toks, ctypes = [], []
    if args and args != "void":
        depth = 0; cur = ""; parts = []
        for ch in args:
            if ch == "," and depth == 0: parts.append(cur); cur = ""
            else:
                cur += ch
                if ch == "(": depth += 1
                if ch == ")": depth -= 1
        parts.append(cur)
        prev_ptr = False
        for part in parts:
            tok = ctype_tok(re.sub(r"\b[a-zA-Z_0-9]+$", "", part.strip()))
            if tok == "i" and prev_ptr:
                tok = "~"
            prev_ptr = tok == "*"
            toks.append(tok)
            ctypes.append(part.strip())
    if ret == "void": rtok = ""
    elif ret == "float": rtok = "f"
    elif ret == "double": rtok = "F"
    else: rtok = "i"
    return name, "(" + "".join(toks) + ")" + rtok, ret, ctypes

lines = ['#include <stddef.h>', '#include "wasm_export.h"', '#include "KitABI.h"', ""]
entries = []
for p in protos:
    p = " ".join(p.split())
    if not re.match(r"[A-Za-z0-9_*\s]+?\s*\b[a-z_0-9]+\s*\(.*\)$", p):
        continue
    name, sig, ret, ctypes = sig_and_params(p)
    if name in implemented:
        cargs = ", ".join(["wasm_exec_env_t e"] + ctypes) if ctypes else "wasm_exec_env_t e"
        lines.append(f"extern {ret} wamr_{name}({cargs});")
        entries.append((name, f"wamr_{name}", sig))
    else:
        cargs = ", ".join(["wasm_exec_env_t e"] + ctypes) if ctypes else "wasm_exec_env_t e"
        body = "{}" if ret == "void" else "{ return 0; }"
        lines.append(f"static {ret} stub_{name}({cargs}) {body}")
        entries.append((name, f"stub_{name}", sig))

lines.append("")
lines.append("NativeSymbol kit_natives[] = {")
for name, fn, sig in entries:
    lines.append(f'    {{ "{name}", (void *){fn}, "{sig}", NULL }},')
lines.append("};")
lines.append(f"int kit_natives_count = {len(entries)};")
lines.append("")
lines.append("bool kit_register_natives(void) {")
lines.append('    return wasm_runtime_register_natives("env", kit_natives, (uint32_t)kit_natives_count);')
lines.append("}")
open(out, "w").write("\n".join(lines) + "\n")
print(f"natives.c: {len(entries)} env functions ({len(implemented)} live)")
