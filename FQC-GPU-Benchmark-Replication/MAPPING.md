# FQC Benchmark Replication Bundle

Everything needed to reproduce all 29 benchmark tests (the original 22 plus
19 new additions) against any FQC-Chat-Demo deployment, on any hardware.

## What's in this folder

- **`run_full_suite.py`** — the single master script. Implements all 29
  tests as real functions (`test_01_correctness` ... `test_29_composite`),
  entirely env-var configured (`FQC_API_BASE`, `FQC_REPO_ROOT`,
  `FQC_DB_KIND`, `FQC_MONGO_URI`, `FQC_HARDWARE_COST_INR`, etc. — see its
  own module docstring for the full list). This is the primary entry
  point; run it, don't reimplement anything below by hand.
- **`BENCHMARK_SUITE_SPEC.md`** — the exact method, sample size, and
  question list for all 29 tests, finalized question-by-question. This is
  the spec `run_full_suite.py` was built against; if a test's behavior is
  ever unclear, this doc is the source of truth, not the old `tests/`
  scripts below.
- **`bfcl_mlperf_questions/`** + **`BFCL_MLPerf_3641_questions.txt`** — the
  real official BFCL v4 question set (3,641 questions, 13 categories) used
  by tests #20 (Function-Calling Accuracy) and #22 (MLPerf Edge Agentic
  accuracy gate). The `.txt` file is a human-readable flat list; the
  `bfcl_mlperf_questions/` folder has the 13 raw per-category JSON files
  (full BFCL format with function schemas) needed to actually re-run the
  official `bfcl-eval` harness.
- **`mlperf_bfcl/`** — the OpenAI-compatible wrapper server and run script
  used to point the real `bfcl-eval` package at a locally-served model
  (see its own README section further down). `run_full_suite.py`'s
  `test_20_function_calling`/`test_22_mlperf` construct the same real
  `bfcl generate`/`bfcl evaluate` commands; this folder's scripts are the
  standalone version if you want to run BFCL outside the master suite.
- **`tests/`** — the ORIGINAL, MongoDB-specific per-test scripts from
  `slm-llama3b`'s own `chat/backend/tests/`, copied here for reference
  only. **`run_full_suite.py` does NOT call these** — it reimplements
  tests #1-22 itself against a DB-kind-abstracted oracle layer (SQLite or
  Mongo, chosen via `FQC_DB_KIND`), using the finalized exact question
  sets from `BENCHMARK_SUITE_SPEC.md`, because these scripts are
  Mongo-only and their question sets/sample sizes predate the finalized
  spec. Kept here only because they're a useful reference for the
  MongoDB-pipeline-specific mechanics (e.g. the `sanity_*.py` files test
  Mongo `$facet`/pipeline-repair internals that have no SQL equivalent).
  `BENCHMARKING.md` documents this folder's own original (now superseded)
  usage.

## Running the suite

`run_full_suite.py` needs to run from inside a real deployment checkout
(it imports the app's own `chat.backend` modules for the direct-model-load
tests, #13/#23) — it is not standalone. Point it at whichever deployment
you're testing via env vars:

```bash
cd /path/to/your/deployment/checkout   # e.g. /home/wgtech/slm-llama3b on the Axelera host
export FQC_REPO_ROOT=$(pwd)
export FQC_API_BASE=http://127.0.0.1:8002      # match the deployment's real port
export FQC_DB_KIND=sqlite                       # or "mongo"
export FQC_SQLITE_PATH=$FQC_REPO_ROOT/chat/backend/alerts.sqlite3   # adjust filename
python /home/wgtech/fqc-gpu-benchmark-replication/run_full_suite.py --list
python /home/wgtech/fqc-gpu-benchmark-replication/run_full_suite.py --tier fast
python /home/wgtech/fqc-gpu-benchmark-replication/run_full_suite.py --tier all
python /home/wgtech/fqc-gpu-benchmark-replication/run_full_suite.py --only 1,5,23
```

Heavy tests (#8, #13, #14, #18, #20, #21, #22) are real, not stubs, but
expensive (minutes to hours) — `--tier fast`/`medium` skip them by
default; invoke with `--tier heavy`/`all` or `--only <n>` explicitly, with
time budgeted, matching this project's existing `run_all_benchmarks.py`
convention.

## Test number → what it does (quick reference)

| # | Title | Function |
|---|---|---|
| 1 | Query Correctness | `test_01_correctness` |
| 2 | Hallucination / Groundedness | `test_02_hallucination` |
| 3 | Query Safety | `test_03_safety` |
| 4 | Refusal Correctness | `test_04_refusal` |
| 5 | Speed | `test_05_speed` |
| 6 | Repeatability | `test_06_repeatability` |
| 7 | Answer Quality Grading | `test_07_quality` |
| 8 | Large-Scale Data (31.5M rows) | `test_08_large_scale` |
| 9 | Multiple-People-At-Once | `test_09_concurrency` |
| 10 | Live Data Writing | `test_10_live_write` |
| 11 | Long-Run Stability (soak) | `test_11_soak` |
| 12 | Tricky Question | `test_12_tricky` |
| 13 | Hardware Speed | `test_13_hardware_speed` |
| 14 | Power and Resource Usage | `test_14_power` |
| 15 | Database Size vs Speed | `test_15_db_size_vs_speed` |
| 16 | Role-Based Access Control | `test_16_rbac` — SKIPPED, not implemented |
| 17 | Access Control Bypass | `test_17_rbac_bypass` — SKIPPED, depends on #16 |
| 18 | Live Website Test | `test_18_live_website` |
| 19 | Self-Fixing Test | `test_19_self_fixing` |
| 20 | Function-Calling Accuracy (BFCL) | `test_20_function_calling` |
| 21 | Dashboard Load Test | `test_21_dashboard_load` |
| 22 | Official MLPerf Edge Agentic | `test_22_mlperf` |
| 23 | Joules per Token | `test_23_joules_per_token` |
| 24 | Cost per Query | `test_24_cost_per_query` |
| 25 | Long-Conversation-History Degradation | `test_25_history_degradation` |
| 26 | Timezone/DST Boundary Correctness | `test_26_timezone` |
| 27 | Backup/Restore Correctness (Mongo + SQLite) | `test_27_backup_restore` |
| 28 | Non-English / Localization | `test_28_localization` |
| 29 | Composite Cost-per-Correct-Answer | `test_29_composite` |

Full method/sample-size/question detail for every row: `BENCHMARK_SUITE_SPEC.md`.
