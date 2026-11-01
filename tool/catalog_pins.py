#!/usr/bin/env python3
"""Relève l'empreinte de signature de chaque app Android du catalogue.

Pour chaque entrée avec `repo` : dernière release retenue par les règles du
catalogue (tagPattern, apkPattern, apkExclude, includePrereleases), téléchargement
de l'APK, lecture du certificat par `apksigner`, puis :

- pas encore d'empreinte  -> `signingCertSha256` est ajouté ;
- empreinte identique     -> rien ;
- empreinte différente    -> signalé, catalogue NON modifié (changement de clé à valider à la main) ;
- clé de debug (DN « Debug ») -> signalée, jamais épinglée : une clé publique ne protège de rien.

Usage (sur un runner GitHub, `gh` authentifié) :
    python3 tool/catalog_pins.py catalog/apps.json <apksigner> <rapport.md>
"""
import json
import re
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path


def gh_api(path):
    out = subprocess.run(["gh", "api", path], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def pick_apk(entry):
    rules = entry.get("release") or {}
    tag_re = re.compile(rules.get("tagPattern") or r"^v?(\d+(?:\.\d+)*(?:-[0-9A-Za-z.\-]+)?)$")
    apk_re = re.compile(rules["apkPattern"]) if rules.get("apkPattern") else None
    excl_re = re.compile(rules["apkExclude"]) if rules.get("apkExclude") else None
    pre = rules.get("includePrereleases") is True
    for rel in gh_api(f"repos/{entry['repo']}/releases?per_page=30"):
        if rel.get("draft") or (rel.get("prerelease") and not pre):
            continue
        if not tag_re.search(rel.get("tag_name") or ""):
            continue
        for a in rel.get("assets") or []:
            name = a.get("name") or ""
            if not name.lower().endswith(".apk"):
                continue
            if apk_re and not apk_re.search(name):
                continue
            if excl_re and excl_re.search(name):
                continue
            return rel["tag_name"], name, a["browser_download_url"]
    return None


def signer(apksigner, apk):
    out = subprocess.run([apksigner, "verify", "--print-certs", apk],
                         capture_output=True, text=True).stdout
    dns = re.findall(r"^Signer #\d+ certificate DN: (.*)$", out, re.M)
    fps = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-f]{64})$", out, re.M)
    return dns, fps


def main():
    catalog_path, apksigner, report_path = sys.argv[1:4]
    text = Path(catalog_path).read_text(encoding="utf-8")
    catalog = json.loads(text)
    rows, changed = [], False
    for entry in catalog["apps"]:
        if entry.get("type", "android") != "android" or not entry.get("repo"):
            continue
        name, current = entry["name"], entry.get("signingCertSha256")
        current = current.replace(":", "").lower() if current else None
        try:
            picked = pick_apk(entry)
            if not picked:
                rows.append((name, "—", "—", "⚠️ aucune release/APK retenu"))
                continue
            tag, asset, url = picked
            with tempfile.TemporaryDirectory() as d:
                apk = f"{d}/app.apk"
                urllib.request.urlretrieve(url, apk)
                dns, fps = signer(apksigner, apk)
        except Exception as e:  # noqa: BLE001 — une app en échec ne bloque pas les autres
            rows.append((name, "—", "—", f"⚠️ erreur : {e}"))
            continue
        if len(fps) != 1:
            rows.append((name, tag, ", ".join(dns) or "—", f"⚠️ {len(fps)} signataires, non épinglé"))
            continue
        dn, fp = dns[0], fps[0]
        if re.search(r"debug", dn, re.I):
            status = "🔴 clé de debug (publique ?) : non épinglée, à remplacer"
        elif current == fp:
            status = "✅ déjà épinglée"
        elif current:
            status = f"🔴 DIFFÉRENTE de l'empreinte épinglée ({current[:16]}…) : non modifiée"
        else:
            entry["signingCertSha256"] = fp
            changed = True
            status = "🆕 épinglée"
        rows.append((name, tag, dn, status + f"<br>`{fp}`"))

    if changed:
        Path(catalog_path).write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["## Empreintes de signature du catalogue", "",
             "| App | Release | Certificat | État |", "|---|---|---|---|"]
    lines += [f"| {a} | {b} | {c} | {d} |" for a, b, c, d in rows]
    lines += ["", "Catalogue modifié." if changed else "Catalogue inchangé."]
    Path(report_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
