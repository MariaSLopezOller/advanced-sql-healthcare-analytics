"""Checks that the semantic layer and the marts give the same numbers.

A metric defined in models/semantic/_semantic_layer.yml must match the mart that answers the
same question. If someone changes one and not the other, this fails.
Run after `dbt build`:

    python scripts/check_metrics.py
"""
import csv
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import duckdb

# MetricFlow prints non-ASCII characters; force UTF-8 so it also works on Windows consoles.
ENV = {**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"}


def mf(metrics, group_by=None):
    """Runs `mf query` and returns the rows as a list of dicts."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "out.csv"
        cmd = ["mf", "query", "--metrics", ",".join(metrics), "--csv", str(out), "--quiet"]
        if group_by:
            cmd += ["--group-by", group_by]
        run = subprocess.run(cmd, env=ENV, capture_output=True, text=True, encoding="utf-8")
        if run.returncode != 0:
            sys.exit("mf query failed:\n" + run.stdout + "\n" + run.stderr)
        with out.open(encoding="utf-8") as f:
            return list(csv.DictReader(f))


problems = []


def check(name, metric_value, mart_value):
    ok = abs(float(metric_value) - float(mart_value)) < 0.001
    print(f"  {'OK  ' if ok else 'FAIL'} {name}: metric {metric_value} vs mart {mart_value}")
    if not ok:
        problems.append(name)


# Query MetricFlow first: DuckDB allows one process at a time to open the file.
totals = mf(["new_patients", "intake_forms_received", "readmission_rate_30d", "adherence_rate"])[0]
by_dept = mf(["readmission_rate_30d"], group_by="department__department_name")
db = duckdb.connect("clinic.duckdb", read_only=True)

print("Semantic layer vs marts")
check("new_patients = rows in dim_patient_intake_golden",
      totals["new_patients"], db.execute("select count(*) from marts.dim_patient_intake_golden").fetchone()[0])
check("intake_forms_received = sum of copies in the golden record",
      totals["intake_forms_received"], db.execute("select sum(copies) from marts.dim_patient_intake_golden").fetchone()[0])
check("readmission_rate_30d = hospital total in rpt_readmission_rates",
      round(float(totals["readmission_rate_30d"]) * 100, 1),
      db.execute("select readmission_rate_pct from marts.rpt_readmission_rates "
             "where department = 'ALL DEPARTMENTS'").fetchone()[0])
check("adherence_rate = adherent share in fct_medication_adherence",
      totals["adherence_rate"],
      db.execute("select avg(case when adherence_status = 'adherent' then 1 else 0 end) "
             "from marts.fct_medication_adherence").fetchone()[0])

mart = dict(db.execute("select department, readmission_rate_pct from marts.rpt_readmission_rates "
                   "where department <> 'ALL DEPARTMENTS'").fetchall())
for row in by_dept:
    dept = row["department__department_name"]
    check(f"readmission_rate_30d for {dept}",
          round(float(row["readmission_rate_30d"]) * 100, 1), mart.get(dept, "missing"))

if problems:
    print(f"\nFAIL: {len(problems)} metric(s) do not match their mart")
    sys.exit(1)
print("\nPASS: every metric matches its mart.")
