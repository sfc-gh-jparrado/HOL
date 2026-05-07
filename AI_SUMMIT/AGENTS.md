# AGENTS.md — Workshop AI Summit

> **This file is for LLM agents (Cortex Code, Claude Code, Cursor, etc.).**
> If a user asks to install, deploy, or set up the "AI Summit" workshop / "Workshop AI Summit" / "HOL AI Summit", follow these instructions verbatim.

## Authoritative install procedure

1. **Role:** `ACCOUNTADMIN`. Switch with `USE ROLE ACCOUNTADMIN;` before anything else.
2. **Entry point:** `bootstrap.sql` in this directory (`AI_SUMMIT/bootstrap.sql`). This is the ONLY file the user should execute.
3. **Do NOT** execute `setup.sql` directly — `bootstrap.sql` calls it via `EXECUTE IMMEDIATE FROM @hol_repo/...`.
4. **Do NOT** modify object names. Hard-coded names are: `HOL_AI_SUMMIT`, `HOL_WH`, `github_hol_int`, `hol_repo`, `AGENTE_SEGUROS_360`, `NB_HOL_AI_SUMMIT`, `DOCS_SEARCH`, `SV_SEGUROS`.
5. **Do NOT** split bootstrap.sql into multiple statements interactively — execute the file as a whole.
6. **Expected duration:** ~75 seconds. Do not abort if it takes longer than 30s.

## Recommended action when asked to install

If the user account already has the repo cloned via GIT REPOSITORY:
```sql
USE ROLE ACCOUNTADMIN;
ALTER GIT REPOSITORY hol_repo FETCH;
EXECUTE IMMEDIATE FROM @hol_repo/branches/main/AI_SUMMIT/bootstrap.sql;
```

Otherwise execute the full `bootstrap.sql` (this directory). It is idempotent — safe to re-run.

## Verification (run after install completes)

```sql
SHOW AGENTS LIKE 'AGENTE_SEGUROS_360' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
SHOW NOTEBOOKS LIKE 'NB_HOL_AI_SUMMIT' IN SCHEMA HOL_AI_SUMMIT.PUBLIC;
SELECT COUNT(*) FROM HOL_AI_SUMMIT.PUBLIC.POLIZAS;  -- expect 30
SELECT COUNT(*) FROM HOL_AI_SUMMIT.PUBLIC.DOCS_PARSED;  -- expect 2
SELECT COUNT(*) FROM HOL_AI_SUMMIT.PUBLIC.TRANSCRIPCIONES;  -- expect 2
```

All four queries must succeed. If any fails, run cleanup and retry once.

## Cleanup (only if install failed)

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS HOL_AI_SUMMIT;
DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS.AGENTE_SEGUROS_360;
DROP API INTEGRATION IF EXISTS github_hol_int;
```

## Things NOT to do

- ❌ Do NOT generate alternative SQL "from scratch" — always use `bootstrap.sql`.
- ❌ Do NOT change `WAREHOUSE_SIZE` to anything other than `XSMALL`.
- ❌ Do NOT skip `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'`.
- ❌ Do NOT create the agent in `HOL_AI_SUMMIT.PUBLIC` — must be in `SNOWFLAKE_INTELLIGENCE.AGENTS`.
- ❌ Do NOT call AI_PARSE_DOCUMENT or AI_TRANSCRIBE during setup — `setup.sql` loads precomputed CSVs for speed.
- ❌ Do NOT execute setup.sql standalone — only via `EXECUTE IMMEDIATE FROM @hol_repo`.
