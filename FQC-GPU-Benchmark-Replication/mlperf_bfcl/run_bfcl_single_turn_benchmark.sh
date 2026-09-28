#!/usr/bin/env bash
# ============================================================================
# Replicates the "MLPerf Edge Agentic accuracy gate" (BFCL v4) benchmark run
# used for the FQC-Chat-Demo GPU (RTX 5070) deployment, documented in the
# "FQC-Chat-Demo Benchmark Status Report — GPU (RTX 5070)" report, section
# 1.22 / 2.6.
#
# Real result obtained with this exact procedure (Llama-3.2-3B-Instruct,
# GGUF Q8_0, via llama.cpp):
#   Non-Live AST accuracy: 81.92%
#   Live AST accuracy:     57.44%
#   Overall (blended, 2276/3641 questions): 62.51%
#
# This uses the ACTUAL, OFFICIAL MLCommons/Berkeley bfcl-eval package —
# real dataset, real AST scoring code — not a custom reimplementation.
# It runs BFCL's "single_turn" category group only (non_live + live), which
# is what "MLPerf Edge Agentic" uses as its accuracy gate. Multi-turn,
# memory, and web_search categories are official BFCL v4 categories too,
# but were NOT run for this result (see report for why) — see the bottom
# of this script for how to add them if you want a fuller run.
#
# EXACT CATEGORY / QUESTION-COUNT BREAKDOWN (3,641 questions total):
#   non_live (1,390 questions):
#     simple_python       400
#     multiple             200
#     parallel              200
#     parallel_multiple     200
#     irrelevance           240
#     simple_java           100
#     simple_javascript      50
#   live (2,251 questions):
#     live_multiple        1053
#     live_irrelevance       884
#     live_simple             258
#     live_parallel_multiple   24
#     live_relevance           16
#     live_parallel            16
#
# To replicate on a different model/machine: change MODEL_ID and GGUF_PATH
# in bfcl_wrapper_server.py (or write an equivalent wrapper for a different
# serving runtime), then run this script end to end.
# ============================================================================
set -euo pipefail

MODEL_ID="meta-llama/Llama-3.2-3B-Instruct-FC"     # BFCL's registered id for this model family
LOCAL_MODEL_PATH="/home/wgtech/bfcl-model-files"    # tokenizer/config bundle BFCL needs (no weights here — wrapper serves those)
WRAPPER_PORT=9100
BFCL_VENV="/home/wgtech/bfcl-venv"                  # isolated venv with bfcl-eval installed, kept separate from app deps
WRAPPER_SCRIPT="$(dirname "$0")/bfcl_wrapper_server.py"

echo "== Step 1: start the OpenAI-compatible wrapper around the target model =="
echo "   (edit bfcl_wrapper_server.py's GGUF_PATH first if replicating on a different model)"
python3 "$WRAPPER_SCRIPT" > /tmp/bfcl_wrapper.log 2>&1 &
WRAPPER_PID=$!
echo "   wrapper pid: $WRAPPER_PID (logs: /tmp/bfcl_wrapper.log)"

echo "== Step 2: wait for the wrapper to report ready =="
for i in $(seq 1 60); do
  if grep -q "Model loaded." /tmp/bfcl_wrapper.log 2>/dev/null; then
    echo "   wrapper ready."
    break
  fi
  sleep 2
done

echo "== Step 3: point bfcl-eval's local-inference handler at the wrapper =="
export LOCAL_SERVER_ENDPOINT="127.0.0.1"
export LOCAL_SERVER_PORT="$WRAPPER_PORT"

source "$BFCL_VENV/bin/activate"

echo "== Step 4: run REAL official BFCL v4 generation for the single_turn categories =="
# --skip-server-setup: use our own wrapper instead of bfcl-eval's built-in vLLM/SGLang launcher
# --local-model-path: tokenizer/config bundle for offline generation-side tokenization
bfcl generate \
  --model "$MODEL_ID" \
  --test-category single_turn \
  --skip-server-setup \
  --local-model-path "$LOCAL_MODEL_PATH" \
  --temperature 0.001 \
  --allow-overwrite

echo "== Step 5: score with BFCL's own OFFICIAL AST checker (not a custom reimplementation) =="
bfcl evaluate \
  --model "$MODEL_ID" \
  --test-category single_turn

echo "== Step 6: stop the wrapper =="
kill "$WRAPPER_PID" 2>/dev/null || true

echo "== Step 7: compute the real blended Non-Live / Live / Overall accuracy =="
python3 "$(dirname "$0")/compute_bfcl_blended_accuracy.py" "$MODEL_ID"

# ----------------------------------------------------------------------------
# To ALSO attempt the remaining official categories (multi-turn, memory,
# web_search) for a fuller run — NOTE: these are much more expensive, since
# each "question" is a multi-step conversation requiring several sequential
# generations; on this hardware this took roughly 13 hours for 1,576 items
# and was intentionally NOT completed for this report (it would keep the
# live chatbot deployment offline for that whole duration, since the GPU
# only has enough VRAM for one loaded model at a time):
#
#   bfcl generate --model "$MODEL_ID" \
#     --test-category memory_kv,memory_rec_sum,memory_vector,multi_turn_base,multi_turn_long_context,multi_turn_miss_func,multi_turn_miss_param,web_search_base,web_search_no_snippet \
#     --skip-server-setup --local-model-path "$LOCAL_MODEL_PATH" --temperature 0.001 --allow-overwrite
#
#   bfcl evaluate --model "$MODEL_ID" \
#     --test-category memory_kv,memory_rec_sum,memory_vector,multi_turn_base,multi_turn_long_context,multi_turn_miss_func,multi_turn_miss_param,web_search_base,web_search_no_snippet
# ----------------------------------------------------------------------------
