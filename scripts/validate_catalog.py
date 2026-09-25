#!/usr/bin/env python3
"""Validatorul catalogului GDC Plugin Manager (docs/catalog.json).

Rulează local, în CI și înainte de orice publicare. Nu modifică nimic.

    scripts/validate_catalog.py                    # structură + contracte (fără rețea, fără repo-uri private)
    scripts/validate_catalog.py --files-root ~/Developer   # + fișierele există și SHA-256 corespunde
    scripts/validate_catalog.py --history          # + produse șterse și republicate ulterior (git)
    scripts/validate_catalog.py --json             # ieșire machine-readable

Cod de ieșire: 0 = fără erori (avertismentele nu blochează), 1 = erori, 2 = catalog ilizibil.
Regulile oglindesc decodorul Swift (Sources/GDCPluginManagerCore/CatalogModel.swift):
o valoare pe care clientul instalat nu o poate decoda e EROARE, fiindcă strică întregul catalog.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CATALOG = os.path.join(REPO_ROOT, "docs", "catalog.json")

PLUGIN_TYPES = {"dctl", "lut", "fuse", "powerGrade", "ofx", "scripts"}
SUPPORTED_OS = {"macOS", "windows", "crossPlatform"}  # altă valoare => catalog nedecodabil pe clienți
PRIVATE_REPOS = {"files": "gdc-plugin-manager-files", "pdfs": "gdc-plugin-manager-pdfs",
                 "scripts": "gdc-plugin-manager-scripts", None: "gdc-plugin-manager-files"}
PRODUCT_KEYS = ("items", "scriptItems")
RESOURCE_KEYS = ("downloadableResources", "pdfResources", "scriptResources")
URL_FIELDS = ("url", "youtubeURL", "purchaseURL", "demoURL", "downloadURL", "externalURL",
              "websiteURL", "contactURL", "thumbnailURL")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
VERSION_RE = re.compile(r"^\d+(\.\d+){1,3}$")


class Report:
    def __init__(self):
        self.findings = []

    def add(self, level, code, where, message):
        self.findings.append({"level": level, "code": code, "where": where, "message": message})

    def error(self, *a):
        self.add("error", *a)

    def warn(self, *a):
        self.add("warning", *a)

    @property
    def errors(self):
        return [f for f in self.findings if f["level"] == "error"]


def check_url(r, where, field, value):
    if not isinstance(value, str) or not value:
        return
    if not value.startswith("https://"):
        r.error("url-not-https", where, f"{field} nu e https: {value}")


def check_files(r, where, files, seen_paths):
    if not isinstance(files, list) or not files:
        r.error("files-missing", where, "fără fișiere (files gol sau absent)")
        return
    local = set()
    for f in files:
        path, sha, repo = f.get("path"), f.get("sha256"), f.get("repo")
        if not isinstance(path, str) or not path:
            r.error("file-path-missing", where, "fișier fără path")
            continue
        if path.startswith("/") or ".." in path.split("/"):
            r.error("file-path-unsafe", where, f"cale nesigură: {path}")
        if not isinstance(sha, str) or not SHA_RE.match(sha):
            r.error("sha256-invalid", where, f"SHA-256 invalid pentru {path}")
        if repo not in PRIVATE_REPOS:
            r.error("repo-unknown", where, f"repo necunoscut '{repo}' pentru {path}")
        key = (repo or "files", path)
        if key in local:
            r.error("file-duplicate", where, f"cale duplicată în același produs: {path}")
        local.add(key)
        if key in seen_paths and seen_paths[key] != where:
            r.warn("file-shared", where, f"{path} e folosit și de {seen_paths[key]}")
        seen_paths.setdefault(key, where)


def validate_products(r, catalog, seen_paths):
    ids = []
    for key in PRODUCT_KEYS:
        for i, p in enumerate(catalog.get(key) or []):
            pid = p.get("id") or f"{key}[{i}]"
            where = f"{key}/{pid}"
            ids.append(pid)
            for field, typ in (("id", str), ("name", str), ("type", str), ("description", str), ("version", str)):
                if not isinstance(p.get(field), typ) or (typ is str and not p.get(field)):
                    r.error("field-missing", where, f"câmp obligatoriu lipsă/invalid: {field}")
            if not isinstance(p.get("priceEUR"), (int, float)) or isinstance(p.get("priceEUR"), bool):
                r.error("field-missing", where, "câmp obligatoriu lipsă/invalid: priceEUR")
            elif p["priceEUR"] < 0:
                r.error("price-negative", where, "priceEUR negativ")
            if p.get("type") and p["type"] not in PLUGIN_TYPES:
                r.error("type-unknown", where, f"tip necunoscut '{p['type']}' (clientul îl afișează „Necunoscut” și nu-l instalează)")
            if "supportedOS" in p and p["supportedOS"] not in SUPPORTED_OS:
                r.error("os-unknown", where, f"supportedOS '{p['supportedOS']}' face TOT catalogul nedecodabil pe clienții instalați")
            if isinstance(p.get("version"), str) and not VERSION_RE.match(p["version"]):
                r.error("version-invalid", where, f"versiune invalidă: {p['version']}")
            if p.get("isTrial") and not p.get("isFree"):
                r.warn("trial-not-free", where, "isTrial fără isFree")
            if not p.get("coverImage"):
                r.warn("cover-missing", where, "fără copertă (coverImage)")
            if "files" in p:
                check_files(r, where, p["files"], seen_paths)
            elif not (p.get("filePath") and p.get("sha256")):
                r.error("files-missing", where, "nici files, nici filePath+sha256 (legacy)")
            for field in URL_FIELDS:
                check_url(r, where, field, p.get(field))
    for pid, n in Counter(ids).items():
        if n > 1:
            r.error("id-duplicate", f"items/{pid}", f"ID de produs duplicat ({n}x) în items/scriptItems")


def validate_collections(r, catalog, seen_paths):
    for key, value in catalog.items():
        if not isinstance(value, list) or key in PRODUCT_KEYS:
            continue
        ids = [x.get("id") for x in value if isinstance(x, dict)]
        for pid, n in Counter(ids).items():
            if pid is not None and n > 1:
                r.error("id-duplicate", f"{key}/{pid}", f"ID duplicat ({n}x)")
        for i, x in enumerate(value):
            where = f"{key}/{x.get('id') or i}"
            if not x.get("id"):
                r.error("field-missing", where, "fără id")
            if "supportedOS" in x and x["supportedOS"] not in SUPPORTED_OS:
                r.error("os-unknown", where, f"supportedOS '{x['supportedOS']}' face TOT catalogul nedecodabil")
            for field in URL_FIELDS:
                check_url(r, where, field, x.get(field))
            if key in RESOURCE_KEYS and x.get("files"):
                check_files(r, where, x["files"], seen_paths)


def validate_covers(r, catalog):
    docs = os.path.join(REPO_ROOT, "docs")
    for key, value in catalog.items():
        if not isinstance(value, list):
            continue
        for x in value:
            for field in ("coverImage", "imagePath"):
                cover = x.get(field) if isinstance(x, dict) else None
                if not cover:
                    continue
                if cover.startswith("https://"):
                    continue
                if cover.startswith("http://"):
                    r.error("url-not-https", f"{key}/{x.get('id')}", f"{field} nu e https: {cover}")
                elif not os.path.isfile(os.path.join(docs, cover.split("?", 1)[0])):  # "?v=" = cache-busting
                    # O intrare dezactivată nu e afișată nicăieri: referință moartă, nu defect vizibil.
                    report = r.warn if x.get("isEnabled") is False else r.error
                    report("cover-file-missing", f"{key}/{x.get('id')}", f"{field} lipsește din docs/: {cover}")


def verify_private_files(r, catalog, files_root):
    for key in PRODUCT_KEYS + RESOURCE_KEYS:
        for x in catalog.get(key) or []:
            where = f"{key}/{x.get('id')}"
            for f in x.get("files") or []:
                repo_dir = os.path.join(files_root, PRIVATE_REPOS.get(f.get("repo"), "?"))
                path = os.path.join(repo_dir, f.get("path", ""))
                if not os.path.isdir(repo_dir):
                    r.error("private-repo-missing", where, f"repo privat absent local: {repo_dir}")
                    return
                if not os.path.isfile(path):
                    r.error("asset-missing", where, f"fișier lipsă în repo-ul privat: {f.get('path')}")
                    continue
                h = hashlib.sha256()
                with open(path, "rb") as fh:
                    for chunk in iter(lambda: fh.read(8 << 20), b""):
                        h.update(chunk)
                if h.hexdigest() != f.get("sha256"):
                    r.error("sha256-mismatch", where, f"SHA-256 diferit pentru {f.get('path')}")


def history_resurrections(r, catalog, catalog_path):
    """Produse prezente acum care au fost ȘTERSE anterior din catalog (republicate)."""
    rel = os.path.relpath(catalog_path, REPO_ROOT)
    try:
        commits = subprocess.run(["git", "-C", REPO_ROOT, "log", "--reverse", "--format=%H %cs", "--", rel],
                                 check=True, capture_output=True, text=True).stdout.split("\n")
    except (subprocess.CalledProcessError, FileNotFoundError):
        r.warn("history-unavailable", rel, "istoric git indisponibil")
        return
    current = {p.get("id") for k in PRODUCT_KEYS for p in (catalog.get(k) or [])}
    previous, removed_at = set(), {}
    for line in filter(None, commits):
        sha, date = line.split()
        blob = subprocess.run(["git", "-C", REPO_ROOT, "show", f"{sha}:{rel}"], capture_output=True, text=True).stdout
        try:
            data = json.loads(blob)
        except json.JSONDecodeError:
            continue
        ids = {p.get("id") for k in PRODUCT_KEYS for p in (data.get(k) or []) if isinstance(p, dict)}
        for gone in previous - ids:
            removed_at[gone] = (sha[:7], date)
        for back in ids & set(removed_at):
            if back in current and back not in previous:
                sha_r, date_r = removed_at[back]
                r.warn("republished-after-delete", f"items/{back}",
                       f"șters în {sha_r} ({date_r}), republicat în {sha[:7]} ({date}) — confirmă că e intenționat")
        previous = ids


def main():
    ap = argparse.ArgumentParser(description="Validează docs/catalog.json")
    ap.add_argument("catalog", nargs="?", default=DEFAULT_CATALOG)
    ap.add_argument("--files-root", help="folderul care conține repo-urile private (ex. ~/Developer)")
    ap.add_argument("--history", action="store_true", help="caută produse șterse și republicate (git)")
    ap.add_argument("--json", action="store_true", help="ieșire JSON")
    args = ap.parse_args()

    r = Report()
    try:
        with open(args.catalog, encoding="utf-8") as fh:
            catalog = json.load(fh)
    except (OSError, json.JSONDecodeError) as e:
        print(json.dumps({"ok": False, "fatal": str(e)}) if args.json else f"✗ catalog ilizibil: {e}")
        return 2
    if not isinstance(catalog, dict):
        print("✗ catalogul trebuie să fie un obiect JSON")
        return 2

    seen_paths = {}
    validate_products(r, catalog, seen_paths)
    validate_collections(r, catalog, seen_paths)
    validate_covers(r, catalog)
    if args.files_root:
        verify_private_files(r, catalog, os.path.expanduser(args.files_root))
    if args.history:
        history_resurrections(r, catalog, args.catalog)

    r.findings.sort(key=lambda f: (f["level"] != "error", f["where"], f["code"], f["message"]))
    counts = {k: len(catalog.get(k) or []) for k in PRODUCT_KEYS + RESOURCE_KEYS}
    if args.json:
        print(json.dumps({"ok": not r.errors, "counts": counts, "findings": r.findings}, ensure_ascii=False, indent=2))
    else:
        for f in r.findings:
            mark = "✗" if f["level"] == "error" else "!"
            print(f"{mark} [{f['code']}] {f['where']}: {f['message']}")
        n_err, n_warn = len(r.errors), len(r.findings) - len(r.errors)
        print(f"{'✓' if not n_err else '✗'} catalog: {counts} — {n_err} erori, {n_warn} avertismente")
    return 1 if r.errors else 0


if __name__ == "__main__":
    sys.exit(main())
