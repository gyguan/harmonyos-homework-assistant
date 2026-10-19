#!/usr/bin/env python3
"""Real PostgreSQL migration and rule-lifecycle check (no AI API key required)."""
from __future__ import annotations

import sys
from homework_review_outbox_e2e import pg_container, sql
from e2e_smoke import SmokeFailure, require

def main() -> int:
    try:
        container = pg_container()
        count = sql(container, """select
          (select count(*) from homework_organizer_rule
              where scope='GLOBAL' and rule_type='SHORTHAND')::text || '/' ||
          (select count(*) from homework_organizer_rule
              where scope='GLOBAL' and rule_type='PROMPT')::text""")
        require(count == "10/3", f"migration seeded unexpected glossary/template counts: {count}")
        templates = sql(container, """select string_agg(template_key, ',' order by template_key)
            from homework_organizer_rule where rule_type='PROMPT'
            and enabled and length(prompt_text) > 500""")
        require(templates == "BLACKBOARD,ENGLISH,THREE_PART",
                f"migrated full prompt templates missing: {templates}")
        code = "GLOBAL_SHORTHAND_08"
        before = sql(container, f"""select enabled::text || ':' || version
            from homework_organizer_rule where code='{code}'""")
        require(before == "true:1", f"wrong initial version for {code}: {before}")
        try:
            sql(container, f"""update homework_organizer_rule
                set enabled=false, version=version+1, updated_at=now()
                where code='{code}' and version=1""")
            disabled = sql(container, f"""select enabled::text || ':' || version
                from homework_organizer_rule where code='{code}'""")
            require(disabled == "false:2", "disabling global rule must persist new version")
        finally:
            sql(container, f"""update homework_organizer_rule
                set enabled=true, version=version+1, updated_at=now()
                where code='{code}' and enabled=false""")
        restored = sql(container, f"""select enabled::text || ':' || version
            from homework_organizer_rule where code='{code}'""")
        require(restored == "true:3", "re-enabling global rule must persist safely")
        print("HOMEWORK_ORGANIZER_RULES_E2E_PASS 10 shorthand 3 prompts dynamic toggling")
        return 0
    except (SmokeFailure, OSError, ValueError) as exc:
        print("HOMEWORK_ORGANIZER_RULES_E2E_FAIL:", exc, file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
