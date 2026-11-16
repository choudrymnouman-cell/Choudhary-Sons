"""Verify the release migration with a disposable CI database."""
import argparse

from sqlalchemy import inspect, text

from app.db.session import engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("step", choices=["seed", "check"])
    step = parser.parse_args().step
    with engine.begin() as db:
        tables = set(inspect(db).get_table_names())
        new_tables = {"invoice_receipts", "purchase_deliveries", "applicant_profiles", "hr_messages"}
        if step == "seed":
            assert not new_tables & tables
            db.execute(text("INSERT INTO projects (code, name, contract_value, status, created_at) "
                            "VALUES ('CI-LEGACY', 'Existing project', 123, 'ACTIVE', CURRENT_TIMESTAMP)"))
        else:
            assert new_tables <= tables
            value = db.execute(text("SELECT contract_value FROM projects WHERE code='CI-LEGACY'")).scalar_one()
            assert value == 123


if __name__ == "__main__":
    main()
