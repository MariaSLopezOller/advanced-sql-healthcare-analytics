"""Governance check on the dbt catalogue: fails if any model or seed is undocumented.

Reads target/manifest.json (written by `dbt build` or `dbt docs generate`) and checks that
every model and seed in this project has a description and a data classification, and that
every model has an owner through its group. Prints an inventory of personal data columns.

    python scripts/check_catalog.py
"""
import json
import sys
from pathlib import Path

LEVELS = {"internal", "personal", "special_category"}
manifest = json.loads(Path("target/manifest.json").read_text(encoding="utf-8"))
project = manifest["metadata"].get("project_name") or "healthcare_analytics"
groups = {g["name"]: g for g in manifest.get("groups", {}).values()}

problems, inventory = [], []
nodes = [n for n in manifest["nodes"].values()
         if n["resource_type"] in ("model", "seed") and n["package_name"] == project]
for n in sorted(nodes, key=lambda n: n["name"]):
    meta = n.get("config", {}).get("meta") or n.get("meta") or {}
    if not (n.get("description") or "").strip():
        problems.append(f"{n['name']}: no description")
    if meta.get("data_classification") not in LEVELS:
        problems.append(f"{n['name']}: data_classification missing or not one of {sorted(LEVELS)}")
    if n["resource_type"] == "model":
        g = n.get("group")
        if not g or g not in groups or not (groups[g].get("owner") or {}).get("name"):
            problems.append(f"{n['name']}: no owner (group with an owner name)")
    for col in n.get("columns", {}).values():
        cmeta = col.get("config", {}).get("meta") or col.get("meta") or {}
        if cmeta.get("personal_data"):
            inventory.append((n["name"], col["name"], cmeta["personal_data"]))

print(f"Catalogue check: {len(nodes)} models and seeds")
print(f"Personal data columns ({len(inventory)}):")
for node, col, kind in inventory:
    print(f"  {node}.{col}: {kind}")
if problems:
    print(f"\nFAIL: {len(problems)} problem(s)")
    for p in problems:
        print("  - " + p)
    sys.exit(1)
print("\nPASS: every model and seed has a description and a classification; every model has an owner.")
