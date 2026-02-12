#!/usr/bin/env python3
"""
Simulated vLLM Server for Warm-up Testing

This application simulates vLLM's behavior with realistic:
- Model loading times (configurable)
- Health endpoints
- Generation endpoints
- Warm-up tracking

Author: nano-k8s-cluster examples
"""

import os
import time
import random
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from dataclasses import dataclass, field

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from starlette.middleware.cors import CORSMiddleware

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
MODEL_LOADING_TIME = int(os.getenv("MODEL_LOADING_TIME", "30"))  # seconds
WARMUP_REQUEST_TIME = int(os.getenv("WARMUP_REQUEST_TIME", "2"))   # seconds
MODEL_NAME = os.getenv("MODEL_NAME", "meta-llama/Llama-3-70B")

# FastAPI app
app = FastAPI(title="vLLM Warm-up Simulator", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@dataclass
class ModelStatus:
    """Track model state and timing."""
    loading: bool = False
    loaded: bool = False
    load_start_time: Optional[datetime] = None
    load_complete_time: Optional[datetime] = None
    warmup_requests: int = 0
    total_requests: int = 0
    first_request_time: Optional[datetime] = None

    def get_load_duration(self) -> Optional[float]:
        """Get time taken to load model."""
        if self.load_start_time and self.load_complete_time:
            return (self.load_complete_time - self.load_start_time).total_seconds()
        return None

    def get_time_to_first_request(self) -> Optional[float]:
        """Get time from pod start to first request."""
        if self.start_time and self.first_request_time:
            return (self.first_request_time - self.start_time).total_seconds()
        return None


# Global model status
model_status = ModelStatus()
model_status.start_time = datetime.now()


# Pydantic models
class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_name: str
    loading_progress: Optional[float] = None
    load_duration: Optional[float] = None
    uptime_seconds: float


class CompletionRequest(BaseModel):
    model: str
    prompt: str
    max_tokens: int = 100
    temperature: float = 0.7


class CompletionResponse(BaseModel):
    id: str
    object: str = "text_completion"
    created: int
    model: str
    choices: list[Dict[str, Any]]
    usage: Dict[str, int]


class MetricsResponse(BaseModel):
    uptime_seconds: float
    model_loaded: bool
    load_duration: Optional[float]
    warmup_requests: int
    total_requests: int
    avg_request_latency_ms: Optional[float]


def load_model():
    """Simulate model loading."""
    global model_status

    if model_status.loaded or model_status.loading:
        return

    logger.info(f"Starting model load: {MODEL_NAME}")
    model_status.loading = True
    model_status.load_start_time = datetime.now()

    # Simulate loading with progress updates
    steps = 10
    for i in range(steps):
        time.sleep(MODEL_LOADING_TIME / steps)
        progress = (i + 1) / steps * 100
        logger.info(f"Loading model: {progress:.0f}%")

    model_status.loading = False
    model_status.loaded = True
    model_status.load_complete_time = datetime.now()

    load_duration = model_status.get_load_duration()
    logger.info(f"Model loaded successfully in {load_duration:.2f} seconds")


def generate_text(prompt: str, max_tokens: int = 100) -> Dict[str, Any]:
    """Simulate text generation with realistic latency."""
    global model_status

    # Track first request
    if model_status.first_request_time is None:
        model_status.first_request_time = datetime.now()

    # Check if this is a warm-up request
    is_warmup = prompt.lower() in ["warmup", "warm-up", "test"]
    if is_warmup:
        model_status.warmup_requests += 1
        generation_time = WARMUP_REQUEST_TIME
    else:
        generation_time = random.uniform(0.5, 2.0)  # Normal request

    model_status.total_requests += 1

    # Simulate generation
    time.sleep(generation_time)

    # Generate response
    tokens = min(max_tokens, random.randint(10, 50))
    response_text = f"Generated response to: {prompt[:50]}... " + " ".join(["token"] * tokens)

    return {
        "text": response_text,
        "tokens": tokens,
        "generation_time": generation_time
    }


@app.get("/health")
async def health_check() -> HealthResponse:
    """
    Health check endpoint.

    This is used by readiness probes to determine if the pod is ready.
    Returns 200 OK only when the model is actually loaded.
    """
    uptime = (datetime.now() - model_status.start_time).total_seconds()

    if model_status.loaded:
        return HealthResponse(
            status="ok",
            model_loaded=True,
            model_name=MODEL_NAME,
            load_duration=model_status.get_load_duration(),
            uptime_seconds=uptime
        )

    # Start loading if not started
    if not model_status.loading:
        # Start loading in background (non-blocking for health check)
        import threading
        threading.Thread(target=load_model, daemon=True).start()

    # Model not loaded yet
    return HealthResponse(
        status="loading",
        model_loaded=False,
        model_name=MODEL_NAME,
        loading_progress=0.0 if not model_status.loading else 50.0,
        uptime_seconds=uptime
    )


@app.get("/ready")
async def ready_check() -> Dict[str, Any]:
    """
    Dedicated readiness endpoint.

    Returns 200 only when model is fully loaded and ready.
    Returns 503 while model is loading.
    """
    if model_status.loaded:
        return {"ready": True, "model": MODEL_NAME}

    raise HTTPException(status_code=503, detail="Model not loaded")


@app.get("/metrics")
async def metrics() -> MetricsResponse:
    """Get detailed metrics about the server."""
    uptime = (datetime.now() - model_status.start_time).total_seconds()

    return MetricsResponse(
        uptime_seconds=uptime,
        model_loaded=model_status.loaded,
        load_duration=model_status.get_load_duration(),
        warmup_requests=model_status.warmup_requests,
        total_requests=model_status.total_requests,
        avg_request_latency_ms=None  # Could track this if needed
    )


@app.post("/v1/completions")
async def create_completion(request: CompletionRequest) -> CompletionResponse:
    """
    Create a completion (OpenAI-compatible endpoint).

    If model is not loaded, it will start loading and return 503.
    """
    if not model_status.loaded:
        if not model_status.loading:
            import threading
            threading.Thread(target=load_model, daemon=True).start()
        raise HTTPException(
            status_code=503,
            detail=f"Model loading... Please wait. Use /health to check status."
        )

    result = generate_text(request.prompt, request.max_tokens)

    return CompletionResponse(
        id=f"cmpl-{random.randint(100000, 999999)}",
        created=int(datetime.now().timestamp()),
        model=request.model,
        choices=[{
            "text": result["text"],
            "index": 0,
            "finish_reason": "length"
        }],
        usage={
            "prompt_tokens": len(request.prompt.split()),
            "completion_tokens": result["tokens"],
            "total_tokens": len(request.prompt.split()) + result["tokens"]
        }
    )


@app.get("/")
async def root():
    """Root endpoint with server info."""
    uptime = (datetime.now() - model_status.start_time).total_seconds()

    return {
        "name": "vLLM Warm-up Simulator",
        "model_name": MODEL_NAME,
        "model_loaded": model_status.loaded,
        "uptime_seconds": uptime,
        "endpoints": {
            "health": "/health",
            "ready": "/ready",
            "metrics": "/metrics",
            "completions": "/v1/completions"
        }
    }


@app.on_event("startup")
async def startup_event():
    """Log startup information."""
    logger.info("=" * 60)
    logger.info("vLLM Warm-up Simulator Starting")
    logger.info("=" * 60)
    logger.info(f"Model: {MODEL_NAME}")
    logger.info(f"Simulated loading time: {MODEL_LOADING_TIME} seconds")
    logger.info(f"Simulated warmup request time: {WARMUP_REQUEST_TIME} seconds")
    logger.info("")
    logger.info("Endpoints:")
    logger.info("  GET  /              - Server info")
    logger.info("  GET  /health        - Health check (always returns 200)")
    logger.info("  GET  /ready         - Readiness check (503 until model loaded)")
    logger.info("  GET  /metrics       - Detailed metrics")
    logger.info("  POST /v1/completions - Generate completions")
    logger.info("")
    logger.info("Warm-up Strategy: Model loads on first request to /health")
    logger.info("=" * 60)


if __name__ == "__main__":
    import uvicorn
    import os

    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
