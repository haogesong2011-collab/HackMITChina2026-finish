const express = require("express");
const User = require("../models/User");
const { authRequired, signToken } = require("../middleware/auth");

const router = express.Router();

router.post("/register", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: "username 和 password 均为必填" });
    }

    const exists = await User.findOne({ username });
    if (exists) {
      return res.status(409).json({ error: "用户名已存在" });
    }

    // 新版统一用户模型，不再按 rider/viewer 区分账号能力。
    const user = await User.create({ username, password, role: "user" });
    const token = signToken(user._id, user.role);

    res.status(201).json({
      token,
      user: user.toSafeJSON(),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: "username 和 password 均为必填" });
    }

    const user = await User.findOne({ username });
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ error: "用户名或密码错误" });
    }

    const token = signToken(user._id, user.role);
    res.json({ token, user: user.toSafeJSON() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/bind", authRequired, async (req, res) => {
  try {
    const { inviteCode } = req.body;

    if (!inviteCode) {
      return res.status(400).json({ error: "inviteCode 为必填" });
    }

    const targetUser = await User.findOne({ inviteCode });
    if (!targetUser) {
      return res.status(404).json({ error: "邀请码无效" });
    }
    if (targetUser._id.toString() === req.user.userId) {
      return res.status(400).json({ error: "不能绑定自己" });
    }

    const me = await User.findById(req.user.userId);
    if (me.watchList.some((id) => id.toString() === targetUser._id.toString())) {
      return res.status(409).json({ error: "该用户已在监护列表中" });
    }

    me.watchList.push(targetUser._id);
    await me.save();

    // 双向绑定
    const alreadyInTarget = targetUser.watchList.some(
      (id) => id.toString() === req.user.userId
    );
    if (!alreadyInTarget) {
      targetUser.watchList.push(me._id);
      await targetUser.save();
    }

    res.json({ message: "绑定成功，已双向关联", targetUserId: targetUser._id, targetUserName: targetUser.username });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/watch", authRequired, async (req, res) => {
  try {
    const { inviteCode } = req.body;

    if (!inviteCode) {
      return res.status(400).json({ error: "inviteCode 为必填" });
    }

    const targetUser = await User.findOne({ inviteCode });
    if (!targetUser) {
      return res.status(404).json({ error: "邀请码无效" });
    }
    if (targetUser._id.toString() === req.user.userId) {
      return res.status(400).json({ error: "不能添加自己" });
    }

    const me = await User.findById(req.user.userId);
    if (me.watchList.some((id) => id.toString() === targetUser._id.toString())) {
      return res.status(409).json({ error: "该用户已在监护列表中" });
    }

    me.watchList.push(targetUser._id);
    await me.save();

    // 双向绑定：也把自己加到对方的监护列表
    const alreadyInTarget = targetUser.watchList.some(
      (id) => id.toString() === req.user.userId
    );
    if (!alreadyInTarget) {
      targetUser.watchList.push(me._id);
      await targetUser.save();
    }

    res.status(201).json({
      message: "添加成功，已双向关联",
      user: { _id: targetUser._id, username: targetUser.username },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/watchlist", authRequired, async (req, res) => {
  try {
    const me = await User.findById(req.user.userId).populate(
      "watchList",
      "_id username inviteCode"
    );
    if (!me) {
      return res.status(404).json({ error: "用户不存在" });
    }

    res.json({ watchList: me.watchList });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete("/watch/:userId", authRequired, async (req, res) => {
  try {
    const targetId = req.params.userId;

    const result = await User.findByIdAndUpdate(
      req.user.userId,
      { $pull: { watchList: targetId } },
      { new: true }
    );

    if (!result) {
      return res.status(404).json({ error: "用户不存在" });
    }

    // 双向移除
    await User.findByIdAndUpdate(targetId, {
      $pull: { watchList: req.user.userId },
    });

    res.json({ message: "已移除监护对象" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/me", authRequired, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ error: "用户不存在" });
    }
    res.json({ user: user.toSafeJSON() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
