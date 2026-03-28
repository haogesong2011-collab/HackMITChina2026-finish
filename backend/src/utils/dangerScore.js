"use strict";

const SAFE_TTC_SECONDS = 3.5;
const MIN_SPEED_KMH = 5;
const COUNT_BOOST_STEP = 0.10;

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function normalizeNumber(value) {
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
}

function calculateDangerScore(targets) {
  const list = Array.isArray(targets) ? targets : [];
  const details = [];

  for (const target of list) {
    const speed = normalizeNumber(target && target.speed);
    const distance = normalizeNumber(target && target.distance);
    const direction = target && target.direction;

    if (
      direction !== "近" ||
      speed == null ||
      distance == null ||
      speed < MIN_SPEED_KMH ||
      distance < 0
    ) {
      continue;
    }

    const speedMs = speed / 3.6;
    const ttc = distance / Math.max(0.1, speedMs);
    const threat = clamp(1 - ttc / SAFE_TTC_SECONDS, 0, 1);
    details.push({ speed, distance, direction, ttc, threat });
  }

  const approachingCount = details.length;
  const maxThreat =
    approachingCount > 0
      ? Math.max(...details.map((item) => item.threat))
      : 0;
  const countBoost =
    approachingCount > 0 ? 1 + COUNT_BOOST_STEP * (approachingCount - 1) : 1;
  const score = Math.min(100, Math.round(maxThreat * countBoost * 100));

  return { score, approachingCount, maxThreat, details };
}

module.exports = {
  calculateDangerScore,
  SAFE_TTC_SECONDS,
  MIN_SPEED_KMH,
  COUNT_BOOST_STEP,
};
