"""Controlled SafeFleet VPS load test.

The script deliberately uses only authentication and read-only business APIs.
Credentials are supplied through environment variables and are never printed.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import os
import statistics
import time
from collections import Counter
from dataclasses import asdict, dataclass
from typing import Awaitable, Callable

import httpx


@dataclass
class Sample:
    elapsed_ms: float
    status: int
    response_bytes: int


@dataclass
class StageResult:
    scenario: str
    concurrency: int
    requests: int
    passed: int
    failed: int
    error_rate_percent: float
    average_ms: float
    p50_ms: float
    p95_ms: float
    p99_ms: float
    throughput_rps: float
    received_kib_per_second: float
    statuses: dict[str, int]


def percentile(values: list[float], percentile_value: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = (len(ordered) - 1) * percentile_value
    lower = math.floor(index)
    upper = math.ceil(index)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (index - lower)


def summarize(
    scenario: str,
    concurrency: int,
    samples: list[Sample],
    wall_seconds: float,
) -> StageResult:
    elapsed = [sample.elapsed_ms for sample in samples]
    passed = sum(1 for sample in samples if 200 <= sample.status < 400)
    failed = len(samples) - passed
    total_bytes = sum(sample.response_bytes for sample in samples)
    statuses = Counter(str(sample.status) if sample.status else "network_error" for sample in samples)
    return StageResult(
        scenario=scenario,
        concurrency=concurrency,
        requests=len(samples),
        passed=passed,
        failed=failed,
        error_rate_percent=round((failed / len(samples) * 100) if samples else 0.0, 2),
        average_ms=round(statistics.fmean(elapsed) if elapsed else 0.0, 2),
        p50_ms=round(percentile(elapsed, 0.50), 2),
        p95_ms=round(percentile(elapsed, 0.95), 2),
        p99_ms=round(percentile(elapsed, 0.99), 2),
        throughput_rps=round((len(samples) / wall_seconds) if wall_seconds else 0.0, 2),
        received_kib_per_second=round(
            (total_bytes / 1024 / wall_seconds) if wall_seconds else 0.0,
            2,
        ),
        statuses=dict(sorted(statuses.items())),
    )


async def timed_request(call: Callable[[], Awaitable[httpx.Response]]) -> Sample:
    started = time.perf_counter()
    try:
        response = await call()
        return Sample(
            elapsed_ms=(time.perf_counter() - started) * 1000,
            status=response.status_code,
            response_bytes=len(response.content),
        )
    except httpx.HTTPError:
        return Sample(
            elapsed_ms=(time.perf_counter() - started) * 1000,
            status=0,
            response_bytes=0,
        )


async def run_simultaneous_stage(
    scenario: str,
    concurrency: int,
    worker: Callable[[int], Awaitable[Sample]],
) -> StageResult:
    gate = asyncio.Event()

    async def gated_worker(index: int) -> Sample:
        await gate.wait()
        return await worker(index)

    tasks = [asyncio.create_task(gated_worker(index)) for index in range(concurrency)]
    started = time.perf_counter()
    gate.set()
    samples = await asyncio.gather(*tasks)
    wall_seconds = time.perf_counter() - started
    return summarize(scenario, concurrency, samples, wall_seconds)


async def run_read_stage(
    client: httpx.AsyncClient,
    concurrency: int,
    requests_per_user: int,
    paths: tuple[str, ...],
) -> StageResult:
    gate = asyncio.Event()

    async def virtual_user(index: int) -> list[Sample]:
        await gate.wait()
        samples: list[Sample] = []
        for iteration in range(requests_per_user):
            path = paths[(index + iteration) % len(paths)]
            samples.append(await timed_request(lambda path=path: client.get(path)))
        return samples

    tasks = [asyncio.create_task(virtual_user(index)) for index in range(concurrency)]
    started = time.perf_counter()
    gate.set()
    nested_samples = await asyncio.gather(*tasks)
    wall_seconds = time.perf_counter() - started
    samples = [sample for group in nested_samples for sample in group]
    return summarize("mixed_read", concurrency, samples, wall_seconds)


async def login(
    client: httpx.AsyncClient,
    username: str,
    password: str,
) -> httpx.Response:
    return await client.post(
        "/api/v1/auth/login",
        json={"usernameOrEmail": username, "password": password},
    )


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="https://safeflee.duckdns.org")
    parser.add_argument("--login-levels", default="1,5,10,20,50,100")
    parser.add_argument("--read-levels", default="10,25,50,100,200,500")
    parser.add_argument("--requests-per-user", type=int, default=5)
    parser.add_argument("--max-error-rate", type=float, default=5.0)
    parser.add_argument("--max-p95-ms", type=float, default=3000.0)
    args = parser.parse_args()

    username = os.environ.get("SAFEFLEET_LOAD_USERNAME", "admin")
    password = os.environ.get("SAFEFLEET_LOAD_PASSWORD")
    if not password:
        raise SystemExit("SAFEFLEET_LOAD_PASSWORD is required")

    login_levels = [int(value) for value in args.login_levels.split(",") if value]
    read_levels = [int(value) for value in args.read_levels.split(",") if value]
    timeout = httpx.Timeout(connect=10.0, read=15.0, write=15.0, pool=15.0)
    max_connections = max(login_levels + read_levels)
    limits = httpx.Limits(
        max_connections=max_connections,
        max_keepalive_connections=max_connections,
        keepalive_expiry=30.0,
    )
    results: list[StageResult] = []

    async with httpx.AsyncClient(
        base_url=args.base_url,
        timeout=timeout,
        limits=limits,
        follow_redirects=False,
    ) as client:
        preflight = await login(client, username, password)
        preflight.raise_for_status()
        payload = preflight.json()
        access_token = payload["data"]["accessToken"]

        for concurrency in login_levels:
            result = await run_simultaneous_stage(
                "login",
                concurrency,
                lambda _index: timed_request(lambda: login(client, username, password)),
            )
            results.append(result)
            print(json.dumps(asdict(result), ensure_ascii=False), flush=True)
            if (
                result.error_rate_percent > args.max_error_rate
                or result.p95_ms > args.max_p95_ms
            ):
                break

        client.headers["Authorization"] = f"Bearer {access_token}"
        paths = (
            "/api/v1/dashboard/summary",
            "/api/v1/trips?page=0&size=20",
            "/api/v1/vehicles?page=0&size=20",
            "/api/v1/flood-reports/map",
        )
        for path in paths:
            warmup = await client.get(path)
            warmup.raise_for_status()

        for concurrency in read_levels:
            result = await run_read_stage(
                client,
                concurrency,
                args.requests_per_user,
                paths,
            )
            results.append(result)
            print(json.dumps(asdict(result), ensure_ascii=False), flush=True)
            if (
                result.error_rate_percent > args.max_error_rate
                or result.p95_ms > args.max_p95_ms
            ):
                break

    print(
        json.dumps(
            {
                "summary": {
                    "base_url": args.base_url,
                    "thresholds": {
                        "max_error_rate_percent": args.max_error_rate,
                        "max_p95_ms": args.max_p95_ms,
                    },
                    "stages_completed": len(results),
                }
            },
            ensure_ascii=False,
        ),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
