#!/usr/bin/env python3
"""
Reads BFCL v4's own scored result JSON files (correct_count/total_count per
category, as written by `bfcl evaluate`) and computes the real Non-Live,
Live, and blended Overall accuracy — the same method used to get the
FQC-Chat-Demo GPU (RTX 5070) report's 81.92% / 57.44% / 62.51% numbers.

Usage: python compute_bfcl_blended_accuracy.py <model-id>
  e.g. python compute_bfcl_blended_accuracy.py meta-llama/Llama-3.2-3B-Instruct-FC
"""
import json
import sys
from pathlib import Path

NON_LIVE_CATEGORIES = [
    "simple_python", "simple_java", "simple_javascript",
    "multiple", "parallel", "parallel_multiple", "irrelevance",
]
LIVE_CATEGORIES = [
    "live_simple", "live_multiple", "live_parallel",
    "live_parallel_multiple", "live_irrelevance", "live_relevance",
]


def find_score_dir(model_id: str) -> Path:
    safe_name = model_id.replace("/", "_")
    import bfcl_eval  # noqa: local import so this works once the bfcl-venv is active
    pkg_root = Path(bfcl_eval.__file__).parent
    for candidate in [pkg_root.parent / "score" / safe_name, Path("score") / safe_name]:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"Could not find BFCL score directory for {model_id}")


def load_counts(score_dir: Path, category: str) -> tuple[int, int]:
    subdir = "non_live" if category in NON_LIVE_CATEGORIES else "live"
    fname = f"BFCL_v4_{category}_score.json"
    path = score_dir / subdir / fname
    with open(path) as f:
        row = json.loads(f.readline())
    return row["correct_count"], row["total_count"]


def main():
    model_id = sys.argv[1] if len(sys.argv) > 1 else "meta-llama/Llama-3.2-3B-Instruct-FC"
    score_dir = find_score_dir(model_id)

    def sum_group(categories):
        correct = total = 0
        for cat in categories:
            c, t = load_counts(score_dir, cat)
            correct += c
            total += t
        return correct, total

    nl_correct, nl_total = sum_group(NON_LIVE_CATEGORIES)
    live_correct, live_total = sum_group(LIVE_CATEGORIES)
    overall_correct = nl_correct + live_correct
    overall_total = nl_total + live_total

    print(f"Non-Live AST accuracy: {nl_correct}/{nl_total} = {100 * nl_correct / nl_total:.2f}%")
    print(f"Live AST accuracy:     {live_correct}/{live_total} = {100 * live_correct / live_total:.2f}%")
    print(f"Overall (blended):     {overall_correct}/{overall_total} = {100 * overall_correct / overall_total:.2f}%")


if __name__ == "__main__":
    main()
