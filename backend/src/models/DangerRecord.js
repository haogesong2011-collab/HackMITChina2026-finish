const mongoose = require("mongoose");

const dangerRecordSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    dangerScore: { type: Number, required: true },
    targetId: { type: Number },
    angle: { type: Number },
    distance: { type: Number },
    speed: { type: Number },
    direction: { type: String },
  },
  { timestamps: true }
);

dangerRecordSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model("DangerRecord", dangerRecordSchema);
