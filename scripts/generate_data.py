"""Generate deterministic synthetic data for the clinic and write the dbt seed CSVs in seeds/.

Everything here is invented. The generator plants the patterns the queries look for:
30-day readmissions, frequent emergency users, refill gaps, HbA1c trends,
duplicate intake forms and a handful of data-quality defects.

Usage:  python scripts/generate_data.py
"""
from __future__ import annotations

import csv
import random
from datetime import date, timedelta
from pathlib import Path

SEED = 42
YEAR_START = date(2025, 1, 1)
YEAR_END = date(2025, 12, 31)
N_PATIENTS = 600

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "seeds"

rng = random.Random(SEED)

DEPARTMENTS = [
    (1, "Hospital", None),
    (2, "Medicine", 1),
    (3, "Surgery", 1),
    (4, "Emergency", 1),
    (5, "Cardiology", 2),
    (6, "Endocrinology", 2),
    (7, "Internal Medicine", 2),
    (8, "General Surgery", 3),
    (9, "Orthopedics", 3),
    (10, "Adult ED", 4),
    (11, "Pediatric ED", 4),
]
LEAVES = [5, 6, 7, 8, 9, 10, 11]

FIRST_NAMES = ["Lucia", "Hugo", "Martina", "Pablo", "Sofia", "Daniel", "Paula", "Alvaro",
               "Carmen", "Javier", "Elena", "Diego", "Laura", "Mario", "Julia", "Adrian",
               "Irene", "Sergio", "Alba", "Raul", "Noa", "Marcos", "Sara", "Ivan"]
LAST_NAMES = ["Garcia", "Martinez", "Lopez", "Sanchez", "Perez", "Gomez", "Martin", "Jimenez",
              "Ruiz", "Hernandez", "Diaz", "Moreno", "Alvarez", "Romero", "Navarro", "Torres",
              "Dominguez", "Vazquez", "Ramos", "Gil", "Serrano", "Molina", "Ortega", "Delgado"]

CHRONIC = {  # code -> (prevalence, drug)
    "E11": (0.20, "metformin"),      # type 2 diabetes
    "I10": (0.30, "enalapril"),      # hypertension
    "I50": (0.08, "furosemide"),     # heart failure
    "J44": (0.07, "tiotropium"),     # COPD
    "J45": (0.06, "salbutamol"),     # asthma
}
ACUTE = {
    "outpatient": ["Z00.0", "M54.5", "J06.9", "R51"],
    "emergency": ["R07.4", "S93.4", "J18.9", "R10.4", "S52.5"],
    "inpatient": ["J18.9", "K35.8", "S72.0", "N39.0"],
}


def d(x: date) -> str:
    return x.isoformat()


def rand_date(start: date, end: date) -> date:
    return start + timedelta(days=rng.randint(0, (end - start).days))


def main() -> None:
    # Physicians: 3-4 per leaf department
    physicians, phys_by_dept, pid = [], {}, 1
    for dept in LEAVES:
        for _ in range(rng.randint(3, 4)):
            name = f"Dr. {rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}"
            physicians.append((pid, name, dept, d(rand_date(date(2005, 1, 1), date(2024, 6, 30)))))
            phys_by_dept.setdefault(dept, []).append(pid)
            pid += 1

    # Patients and their chronic conditions
    patients, conditions = [], {}
    for p in range(1, N_PATIENTS + 1):
        birth = rand_date(date(1935, 1, 1), date(2022, 12, 31))
        patients.append((p, d(birth), rng.choice("FM"), f"18{rng.randint(0, 99):03d}",
                         d(rand_date(date(2015, 1, 1), date(2024, 12, 31)))))
        conds = set()
        for code, (prev, _) in CHRONIC.items():
            boost = 1.8 if code == "I10" and "E11" in conds else 1.0
            if birth.year < 1975 and code in ("I50", "J44"):
                boost *= 2.0
            if rng.random() < prev * boost:
                conds.add(code)
        conditions[p] = conds

    age_at = {p[0]: 2025 - int(p[1][:4]) for p in patients}
    encounters, diagnoses = [], []
    eid = 1

    def add_encounter(p, etype, admit, los=0, discharge_missing=False):
        nonlocal eid
        conds = conditions[p]
        if etype == "emergency":
            dept = 11 if age_at[p] < 16 else 10
        elif etype == "inpatient":
            if "I50" in conds and rng.random() < 0.6:
                dept = 5
            else:
                dept = rng.choice([7, 7, 8, 9])
        else:
            if "E11" in conds and rng.random() < 0.5:
                dept = 6
            elif ("I50" in conds or "I10" in conds) and rng.random() < 0.5:
                dept = 5
            else:
                dept = rng.choice([7, 7, 9])
        phys = rng.choice(phys_by_dept[dept])
        if etype == "outpatient":
            discharge, cost = admit, rng.uniform(80, 250)
        elif etype == "emergency":
            discharge, cost = admit + timedelta(days=rng.choice([0, 0, 0, 1])), rng.uniform(300, 1200)
        else:
            discharge, cost = admit + timedelta(days=los), 1500 + 900 * los + rng.uniform(-400, 600)
        encounters.append((eid, p, phys, dept, etype, d(admit),
                           None if discharge_missing else d(discharge), round(cost, 2)))
        # Primary diagnosis: chronic condition (if any, sometimes) or an acute code
        chronic_list = sorted(conds)
        if chronic_list and (etype != "emergency" or rng.random() < 0.3) and rng.random() < 0.7:
            primary = rng.choice(chronic_list)
        else:
            primary = rng.choice(ACUTE[etype])
        diagnoses.append((eid, primary, 1))
        for c in chronic_list:
            if c != primary:
                diagnoses.append((eid, c, 0))
        eid += 1
        return discharge

    for p in range(1, N_PATIENTS + 1):
        conds = conditions[p]
        n_visits = rng.randint(0, 3) + 2 * len(conds)
        for _ in range(n_visits):
            r = rng.random()
            etype = "outpatient" if r < 0.68 else ("emergency" if r < 0.88 else "inpatient")
            admit = rand_date(YEAR_START, YEAR_END)
            if etype != "inpatient":
                add_encounter(p, etype, admit)
                continue
            los = rng.randint(1, 12)
            if admit + timedelta(days=los) > YEAR_END:
                add_encounter(p, etype, admit, los, discharge_missing=True)  # still admitted
                continue
            discharge = add_encounter(p, etype, admit, los)
            readmit_p = 0.40 if ("I50" in conds or "J44" in conds) else 0.12
            if rng.random() < readmit_p:
                re_admit = discharge + timedelta(days=rng.randint(2, 30))
                re_los = rng.randint(1, 8)
                if re_admit + timedelta(days=re_los) <= YEAR_END:
                    add_encounter(p, "inpatient", re_admit, re_los)

    # Frequent emergency users: bursts of 3-6 ED visits within ~2 months
    for p in rng.sample(range(1, N_PATIENTS + 1), 18):
        burst_start = rand_date(YEAR_START, date(2025, 10, 15))
        for _ in range(rng.randint(3, 6)):
            add_encounter(p, "emergency", burst_start + timedelta(days=rng.randint(0, 60)))

    # Planted data-quality defects
    encounters.append((eid, 17, 999, 7, "outpatient", "2025-03-04", "2025-03-04", 120.0)); eid += 1  # orphan physician
    for p, phys in ((rng.randint(1, N_PATIENTS), phys_by_dept[7][0]), (rng.randint(1, N_PATIENTS), phys_by_dept[8][0])):
        dept = 7 if phys in phys_by_dept[7] else 8  # discharge typed before admit
        encounters.append((eid, p, phys, dept, "inpatient", "2025-06-10", "2025-06-07", 3200.0)); eid += 1

    # Prescriptions: monthly fills with early refills (overlap) and occasional gaps
    prescriptions, rx = [], 1
    for p in range(1, N_PATIENTS + 1):
        for code in sorted(conditions[p]):
            drug = CHRONIC[code][1]
            start = YEAR_START + timedelta(days=rng.randint(0, 60))
            poor_adherence = rng.random() < 0.3
            while start <= YEAR_END:
                supply = rng.choice([30, 30, 30, 90])
                prescriptions.append((rx, p, drug, d(start), supply)); rx += 1
                gap = rng.randint(-6, 3)
                if rng.random() < (0.25 if poor_adherence else 0.04):
                    gap = rng.randint(15, 70)
                start = start + timedelta(days=supply + gap)

    # Lab results: HbA1c every ~3 months for diabetics, LDL twice a year for hypertensives
    labs, lid = [], 1
    for p in range(1, N_PATIENTS + 1):
        if "E11" in conditions[p]:
            value = rng.uniform(6.4, 10.5)
            trend = rng.choice([-0.45, -0.25, 0.0, 0.0, 0.2, 0.4])
            when = YEAR_START + timedelta(days=rng.randint(0, 40))
            while when <= YEAR_END:
                labs.append((lid, p, "HBA1C", round(max(4.8, value), 1), d(when))); lid += 1
                value += trend + rng.uniform(-0.3, 0.3)
                when += timedelta(days=rng.randint(80, 100))
        if "I10" in conditions[p]:
            for month in (rng.randint(1, 5), rng.randint(7, 11)):
                labs.append((lid, p, "LDL", round(rng.uniform(70, 190), 0),
                             d(date(2025, month, rng.randint(1, 28))))); lid += 1
    for bad in (0.0, 45.0, 99.9):  # out-of-range HbA1c values (unit errors / typos)
        labs.append((lid, rng.randint(1, N_PATIENTS), "HBA1C", bad, "2025-05-20")); lid += 1

    # Raw intake forms: people, some submitting several times with messy variations
    intake, iid = [], 1
    for _ in range(320):
        first, last = rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES)
        birth = rand_date(date(1940, 1, 1), date(2015, 12, 31))
        email = f"{first}.{last}{rng.randint(1, 999)}@example.com".lower() if rng.random() > 0.08 else None
        phone = f"6{rng.randint(10_000_000, 99_999_999)}"
        copies = 1 if rng.random() > 0.22 else rng.randint(2, 3)
        submitted = rand_date(YEAR_START, YEAR_END)
        for c in range(copies):
            f, l, e = first, last, email
            if c > 0:  # variations a human would still recognise as the same person
                f = f.upper() if rng.random() < 0.5 else f"  {f} "
                e = e.upper() if e and rng.random() < 0.5 else (f" {e}" if e else None)
            intake.append((iid, rng.choice(["web", "front_desk"]), f, l, d(birth), e, phone,
                           d(submitted + timedelta(days=c * rng.randint(1, 20))))); iid += 1
    intake.append((iid, "web", "Test", "Test", "2031-01-01", "no-email", None, "2025-07-01")); iid += 1
    intake.append((iid, "web", "Nora", "Ibarra", "1988-04-12", "nora.ibarra@", "600000000", "2025-08-15")); iid += 1

    tables = {
        "raw_departments": (["department_id", "name", "parent_department_id"], DEPARTMENTS),
        "raw_physicians": (["physician_id", "full_name", "department_id", "hire_date"], physicians),
        "raw_patients": (["patient_id", "birth_date", "sex", "postal_code", "registered_at"], patients),
        "raw_encounters": (["encounter_id", "patient_id", "physician_id", "department_id", "encounter_type",
                            "admit_date", "discharge_date", "total_cost"], encounters),
        "raw_diagnoses": (["encounter_id", "icd10_code", "is_primary"], diagnoses),
        "raw_prescriptions": (["prescription_id", "patient_id", "drug_name", "start_date", "days_supply"],
                              prescriptions),
        "raw_lab_results": (["lab_result_id", "patient_id", "test_code", "result_value", "taken_at"], labs),
        "raw_patient_intake": (["intake_id", "source_system", "first_name", "last_name", "birth_date",
                                "email", "phone", "submitted_at"], intake),
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (columns, rows) in tables.items():
        with open(OUT_DIR / f"{name}.csv", "w", newline="", encoding="utf-8") as fh:
            writer = csv.writer(fh, lineterminator="\n")
            writer.writerow(columns)
            writer.writerows(["" if v is None else v for v in r] for r in rows)
    print(f"Wrote {len(tables)} seed files to seeds/: {len(patients)} patients, {len(encounters)} encounters, "
          f"{len(prescriptions)} fills, {len(labs)} lab results, {len(intake)} intake rows")


if __name__ == "__main__":
    main()
