const jwt = require("jsonwebtoken");

const JWT_SECRET = process.env.JWT_SECRET || "radar-glasses-secret-2026";

function authRequired(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ error: "未提供认证令牌" });
  }

  try {
    const token = header.slice(7);
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = { userId: decoded.userId, role: decoded.role };
    next();
  } catch {
    return res.status(401).json({ error: "令牌无效或已过期" });
  }
}

function riderOnly(req, res, next) {
  if (req.user.role !== "rider") {
    return res.status(403).json({ error: "仅骑行者可执行此操作" });
  }
  next();
}

function signToken(userId, role) {
  return jwt.sign({ userId, role }, JWT_SECRET, { expiresIn: "30d" });
}

module.exports = { authRequired, riderOnly, signToken, JWT_SECRET };
