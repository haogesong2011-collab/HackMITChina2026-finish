const mongoose = require("mongoose");

const radarFrameSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
    index: true,
  },
  targetId: { type: Number, required: true },
  angle: { type: Number, required: true },
  distance: { type: Number, required: true },
  speed: { type: Number, required: true },
  direction: { type: String, required: true },
  scanId: { type: String },
  timestamp: { type: Date, default: Date.now, index: true },
});

radarFrameSchema.index({ userId: 1, timestamp: -1 });
radarFrameSchema.index({ userId: 1, scanId: 1, timestamp: -1 });

module.exports = mongoose.model("RadarFrame", radarFrameSchema);
