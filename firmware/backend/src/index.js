const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");

const authRoutes = require("./routes/auth");
const radarRoutes = require("./routes/radar");

const app = express();
app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({ status: "ok", service: "radar-backend" });
});

app.use("/api/auth", authRoutes);
app.use("/api/radar", radarRoutes);

const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27017/radar";
const PORT = process.env.PORT || 3000;

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log("MongoDB 连接成功");
    app.listen(PORT, () => {
      console.log(`后端已启动: http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error("MongoDB 连接失败:", err.message);
    process.exit(1);
  });
