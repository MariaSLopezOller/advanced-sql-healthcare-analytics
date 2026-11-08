"""Print the first rows of every mart table in clinic.duckdb (run `dbt build` first).

Usage:  python scripts/preview.py [name_filter] [--rows N]
"""
import argparse
from pathlib import Path

import duckdb

DB = Path(__file__).resolve().parent.parent / "clinic.duckdb"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("filter", nargs="?", default="")
    parser.add_argument("--rows", type=int, default=10)
    args = parser.parse_args()

    con = duckdb.connect(str(DB), read_only=True)
    tables = [r[0] for r in con.sql(
        "select table_name from information_schema.tables where table_schema = 'marts' order by 1").fetchall()]
    for t in tables:
        if args.filter not in t:
            continue
        total = con.sql(f"select count(*) from marts.{t}").fetchall()[0][0]
        print(f"\n=== marts.{t}  ({total} rows)")
        con.sql(f"select * from marts.{t}").show(max_rows=args.rows, max_width=250)


if __name__ == "__main__":
    main()
