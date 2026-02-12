#!/usr/bin/env python3
"""
Warm-up Client for LLM Serving

This script sends warm-up requests to LLM serving pods to ensure
the model is loaded before the pod is marked as "Ready".

Usage:
    python warmup-client.py --service vllm-readiness-probe --namespace default

Author: nano-k8s-cluster examples
"""

import argparse
import time
import logging
import sys
from typing import Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class WarmupClient:
    """Client for sending warm-up requests to LLM serving pods."""

    def __init__(self, base_url: str, timeout: int = 120):
        """
        Initialize the warm-up client.

        Args:
            base_url: Base URL of the LLM service
            timeout: Timeout for warm-up requests
        """
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout

        # Configure retry strategy
        retry_strategy = Retry(
            total=timeout // 5,  # Retry every 5 seconds
            backoff_factor=1,
            status_forcelist=[503, 504],
            allowed_methods=["GET", "POST"]
        )

        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session = requests.Session()
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)

    def check_health(self) -> dict:
        """
        Check if the service is healthy.

        Returns:
            Health check response
        """
        try:
            response = self.session.get(
                f"{self.base_url}/health",
                timeout=5
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logger.error(f"Health check failed: {e}")
            return {}

    def wait_for_model_loaded(self, timeout: int = 120) -> bool:
        """
        Wait for the model to be loaded.

        Args:
            timeout: Maximum time to wait in seconds

        Returns:
            True if model loaded successfully
        """
        logger.info("Waiting for model to be loaded...")

        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                health = self.check_health()
                if health.get("model_loaded"):
                    logger.info("✓ Model is loaded!")
                    return True

                progress = health.get("loading_progress", 0)
                logger.info(f"  Model loading... {progress:.0f}%")

            except Exception as e:
                logger.debug(f"  Not ready yet: {e}")

            time.sleep(3)

        logger.error("Timeout waiting for model to load")
        return False

    def send_warmup_request(self) -> bool:
        """
        Send a warm-up completion request.

        Returns:
            True if warm-up request succeeded
        """
        logger.info("Sending warm-up request...")

        try:
            response = self.session.post(
                f"{self.base_url}/v1/completions",
                json={
                    "model": "meta-llama/Llama-3-70B",
                    "prompt": "warmup",
                    "max_tokens": 1
                },
                timeout=30
            )
            response.raise_for_status()
            logger.info("✓ Warm-up request successful")
            return True

        except requests.RequestException as e:
            logger.error(f"Warm-up request failed: {e}")
            return False

    def warmup(self, wait_for_load: bool = True) -> bool:
        """
        Perform full warm-up process.

        Args:
            wait_for_load: Wait for model to be loaded first

        Returns:
            True if warm-up successful
        """
        start_time = time.time()

        if wait_for_load:
            if not self.wait_for_model_loaded(self.timeout):
                return False

        # Send warm-up request
        if not self.send_warmup_request():
            return False

        elapsed = time.time() - start_time
        logger.info(f"✓ Warm-up complete in {elapsed:.1f} seconds")
        return True

    def get_metrics(self) -> dict:
        """
        Get metrics from the service.

        Returns:
            Metrics dict
        """
        try:
            response = self.session.get(
                f"{self.base_url}/metrics",
                timeout=5
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logger.error(f"Failed to get metrics: {e}")
            return {}


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Send warm-up requests to LLM serving pods"
    )
    parser.add_argument(
        "--service",
        required=True,
        help="Kubernetes service name"
    )
    parser.add_argument(
        "--namespace",
        default="default",
        help="Kubernetes namespace (default: default)"
    )
    parser.add_argument(
        "--port",
        type=int,
        default=80,
        help="Service port (default: 80)"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=120,
        help="Timeout in seconds (default: 120)"
    )
    parser.add_argument(
        "--no-wait",
        action="store_true",
        help="Don't wait for model to load before sending request"
    )
    parser.add_argument(
        "--metrics",
        action="store_true",
        help="Show metrics after warm-up"
    )

    args = parser.parse_args()

    # Build base URL
    base_url = f"http://{args.service}.{args.namespace}.svc.cluster.local:{args.port}"

    logger.info("=" * 60)
    logger.info("LLM Warm-up Client")
    logger.info("=" * 60)
    logger.info(f"Service: {args.service}.{args.namespace}")
    logger.info(f"URL: {base_url}")
    logger.info(f"Timeout: {args.timeout}s")
    logger.info("=" * 60)

    # Create client
    client = WarmupClient(base_url, timeout=args.timeout)

    # Perform warm-up
    success = client.warmup(wait_for_load=not args.no_wait)

    if not success:
        logger.error("Warm-up failed!")
        sys.exit(1)

    # Show metrics if requested
    if args.metrics:
        logger.info("")
        logger.info("Metrics:")
        metrics = client.get_metrics()
        for key, value in metrics.items():
            logger.info(f"  {key}: {value}")

    logger.info("")
    logger.info("✓ Warm-up complete!")
    sys.exit(0)


if __name__ == "__main__":
    main()
