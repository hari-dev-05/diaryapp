const mongoose = require('mongoose');

const noteSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, 'Title is required'],
      trim: true,
    },
    content: {
      type: String,
      required: [true, 'Content is required'],
      trim: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
      // Existing legacy notes created before authentication do not have userId.
      // Keeping this optional at schema level ensures legacy documents remain valid in Atlas,
      // while new notes will always be tagged with the authenticated user's ID.
    },
  },
  {
    timestamps: true, // Automatically manages createdAt and updatedAt as Dates
    toJSON: {
      virtuals: true,
      transform: (doc, ret) => {
        ret.id = ret._id.toString();
        return ret;
      },
    },
    toObject: {
      virtuals: true,
      transform: (doc, ret) => {
        ret.id = ret._id.toString();
        return ret;
      },
    },
  }
);

const Note = mongoose.model('Note', noteSchema);

module.exports = Note;
