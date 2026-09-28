"""
OpenAI-compatible completions server wrapping a local llama.cpp GGUF model,
used to point the official BFCL v4 (bfcl-eval) harness at a locally-served
model for the "MLPerf Edge Agentic accuracy gate" benchmark.

This is the exact wrapper used to benchmark the FQC-Chat-Demo GPU (RTX 5070)
deployment's Llama-3.2-3B-Instruct model. To replicate elsewhere, point
GGUF_PATH at the target model's GGUF weights and adjust n_gpu_layers/n_ctx
for the target hardware.

Run: python bfcl_wrapper_server.py
Serves on http://127.0.0.1:9100/v1/completions (OpenAI legacy completions API).
"""
import os, time, threading
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import uvicorn
from llama_cpp import Llama

GGUF_PATH = "/home/wgtech/slm-llama3b/models/Llama-3.2-3B-Instruct-GGUF/Llama-3.2-3B-Instruct-Q8_0.gguf"

print("Loading model...", flush=True)
llm = Llama(model_path=GGUF_PATH, n_gpu_layers=-1, n_ctx=16384, verbose=False)
print("Model loaded.", flush=True)

lock = threading.Lock()
app = FastAPI()

@app.get("/v1/models")
def models():
    return {"data": [{"id": "meta-llama/Llama-3.2-3B-Instruct", "object": "model"}]}

@app.post("/v1/completions")
async def completions(req: Request):
    body = await req.json()
    prompt = body.get("prompt", "")
    max_tokens = body.get("max_tokens", 512)
    temperature = body.get("temperature", 0.001)
    stop = body.get("stop", None)
    with lock:
        try:
            out = llm(
                prompt,
                max_tokens=max_tokens,
                temperature=max(temperature, 0.0),
                stop=stop,
            )
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})
    text = out["choices"][0]["text"]
    finish = out["choices"][0].get("finish_reason", "stop")
    usage = out.get("usage", {})
    return {
        "id": "cmpl-local",
        "object": "text_completion",
        "created": int(time.time()),
        "model": "meta-llama/Llama-3.2-3B-Instruct",
        "choices": [{"text": text, "index": 0, "logprobs": None, "finish_reason": finish}],
        "usage": usage,
    }

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=9100, log_level="warning")
