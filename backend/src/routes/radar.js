const express = require("express");
const crypto = require("crypto");
const RadarFrame = require("../models/RadarFrame");
const DangerRecord = require("../models/DangerRecord");
const User = require("../models/User");
const { authRequired } = require("../middleware/auth");
const { calculateDangerScore } = require("../utils/dangerScore");

const DANGER_RECORD_THRESHOLD = 70;

const router = express.Router();

async function resolveTargetId(req) {
  const targetParam = req.query.target;

  if (!targetParam) {
    return { ok: true, targetId: req.user.userId };
  }

  const currentUser = await User.findById(req.user.userId);
  if (!currentUser) {
    return { ok: false, status: 404, error: "用户不存在" };
  }

  const allowed = currentUser.watchList.some(
    (id) => id.toString() === targetParam
  );
  if (!allowed) {
    return { ok: false, status: 403, error: "该用户不在你的监护列表中" };
  }

  return { ok: true, targetId: targetParam };
}

router.post("/frame", authRequired, async (req, res) => {
  try {
    const { target_id, angle, distance, speed, direction } = req.body;

    if (target_id == null || angle == null || distance == null || speed == null || !direction) {
      return res.status(400).json({ error: "缺少必填字段" });
    }

    const frame = await RadarFrame.create({
      userId: req.user.userId,
      targetId: target_id,
      angle,
      distance,
      speed,
      direction,
    });

    res.status(201).json({ stored: true, id: frame._id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/scan", authRequired, async (req, res) => {
  try {
    const { targets } = req.body;
    if (!Array.isArray(targets) || targets.length === 0) {
      return res.status(400).json({ error: "targets 必须是非空数组" });
    }

    const invalidTarget = targets.find(
      (item) =>
        item.target_id == null ||
        item.angle == null ||
        item.distance == null ||
        item.speed == null ||
        !item.direction
    );

    if (invalidTarget) {
      return res.status(400).json({ error: "targets 中存在缺少必填字段的数据" });
    }

    const danger = calculateDangerScore(targets);
    const scanId = crypto.randomUUID();

    const docs = targets.map((item) => ({
      userId: req.user.userId,
      scanId,
      targetId: item.target_id,
      angle: item.angle,
      distance: item.distance,
      speed: item.speed,
      direction: item.direction,
    }));

    await RadarFrame.insertMany(docs);

    if (danger.score >= DANGER_RECORD_THRESHOLD && targets.length > 0) {
      const approaching = targets.filter(
        (t) => t.direction === "近" && t.speed >= 10
      );
      const threat =
        approaching.length > 0
          ? approaching.reduce((a, b) => {
              const ttcA = a.distance / (a.speed / 3.6);
              const ttcB = b.distance / (b.speed / 3.6);
              return ttcA < ttcB ? a : b;
            })
          : targets[0];
      await DangerRecord.create({
        userId: req.user.userId,
        dangerScore: danger.score,
        targetId: threat.target_id,
        angle: threat.angle,
        distance: threat.distance,
        speed: threat.speed,
        direction: threat.direction,
      });
    }

    res.status(201).json({
      stored: true,
      count: docs.length,
      dangerScore: danger.score,
      scanId,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/latest", authRequired, async (req, res) => {
  try {
    const resolved = await resolveTargetId(req);
    if (!resolved.ok) {
      return res.status(resolved.status).json({ error: resolved.error });
    }

    const frame = await RadarFrame.findOne({ userId: resolved.targetId })
      .sort({ timestamp: -1 })
      .lean();

    if (!frame) {
      return res.json({ frame: null });
    }
    res.json({ frame });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/frames", authRequired, async (req, res) => {
  try {
    const resolved = await resolveTargetId(req);
    if (!resolved.ok) {
      return res.status(resolved.status).json({ error: resolved.error });
    }

    const { from, to, limit } = req.query;
    const query = { userId: resolved.targetId };

    if (from || to) {
      query.timestamp = {};
      if (from) query.timestamp.$gte = new Date(from);
      if (to) query.timestamp.$lte = new Date(to);
    }

    const maxLimit = Math.min(parseInt(limit) || 100, 1000);

    const frames = await RadarFrame.find(query)
      .sort({ timestamp: -1 })
      .limit(maxLimit)
      .lean();

    res.json({ count: frames.length, frames });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/danger", authRequired, async (req, res) => {
  try {
    const resolved = await resolveTargetId(req);
    if (!resolved.ok) {
      return res.status(resolved.status).json({ error: resolved.error });
    }

    const now = new Date();
    const windowStart = new Date(now.getTime() - 2000);
    const frames = await RadarFrame.find({
      userId: resolved.targetId,
      timestamp: { $gte: windowStart, $lte: now },
    })
      .sort({ timestamp: -1 })
      .lean();

    const targets = frames.map((frame) => ({
      speed: frame.speed,
      distance: frame.distance,
      direction: frame.direction,
    }));
    const danger = calculateDangerScore(targets);

    res.json({
      dangerScore: danger.score,
      approachingCount: danger.approachingCount,
      maxThreat: danger.maxThreat,
      calculatedAt: now.toISOString(),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/danger-records", authRequired, async (req, res) => {
  try {
    const resolved = await resolveTargetId(req);
    if (!resolved.ok) {
      return res.status(resolved.status).json({ error: resolved.error });
    }

    const maxLimit = Math.min(parseInt(req.query.limit) || 50, 200);
    const records = await DangerRecord.find({ userId: resolved.targetId })
      .sort({ createdAt: -1 })
      .limit(maxLimit)
      .lean();

    res.json({ count: records.length, records });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
