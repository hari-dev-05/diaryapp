const express = require('express');
const mongoose = require('mongoose');
const Note = require('../models/Note');
const { protect } = require('../middleware/auth');

const router = express.Router();

// Helper to validate MongoDB ObjectId
const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

// Enforce authentication on all note routes
router.use(protect);

/**
 * @route   GET /api/notes
 * @desc    Retrieve all diary notes belonging to the authenticated user (newest first)
 */
router.get('/', async (req, res, next) => {
  try {
    // Strictly filter by authenticated user ID derived from verified JWT
    const notes = await Note.find({ userId: req.user._id }).sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: notes.length,
      data: notes,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   GET /api/notes/:id
 * @desc    Retrieve a specific note only if owned by the authenticated user
 */
router.get('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid Note ID format',
      });
    }

    // Must match both the note ID and the authenticated user's ID
    const note = await Note.findOne({ _id: id, userId: req.user._id });

    if (!note) {
      return res.status(404).json({
        success: false,
        message: 'Note not found',
      });
    }

    return res.status(200).json({
      success: true,
      data: note,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   POST /api/notes
 * @desc    Save a new diary note assigned to the authenticated user
 */
router.post('/', async (req, res, next) => {
  try {
    const { title, content } = req.body;

    // Validate incoming data
    if (!title || typeof title !== 'string' || title.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Title is required and cannot be empty',
      });
    }

    if (!content || typeof content !== 'string' || content.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Content is required and cannot be empty',
      });
    }

    // Assign userId strictly from req.user._id (ignoring any client-supplied userId)
    const newNote = await Note.create({
      title: title.trim(),
      content: content.trim(),
      userId: req.user._id,
    });

    return res.status(201).json({
      success: true,
      data: newNote,
      message: 'Note created successfully',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   PUT /api/notes/:id
 * @desc    Update an existing note only if owned by the authenticated user
 */
router.put('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { title, content } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid Note ID format',
      });
    }

    // Validate update fields
    if (title !== undefined && (typeof title !== 'string' || title.trim() === '')) {
      return res.status(400).json({
        success: false,
        message: 'Title cannot be empty',
      });
    }

    if (content !== undefined && (typeof content !== 'string' || content.trim() === '')) {
      return res.status(400).json({
        success: false,
        message: 'Content cannot be empty',
      });
    }

    const updateData = {};
    if (title !== undefined) updateData.title = title.trim();
    if (content !== undefined) updateData.content = content.trim();

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Please provide at least one field (title or content) to update',
      });
    }

    // Ensure note exists and belongs to the authenticated user
    const updatedNote = await Note.findOneAndUpdate(
      { _id: id, userId: req.user._id },
      updateData,
      {
        new: true,
        runValidators: true,
      }
    );

    if (!updatedNote) {
      return res.status(404).json({
        success: false,
        message: 'Note not found',
      });
    }

    return res.status(200).json({
      success: true,
      data: updatedNote,
      message: 'Note updated successfully',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route   DELETE /api/notes/:id
 * @desc    Delete a note only if owned by the authenticated user
 */
router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid Note ID format',
      });
    }

    // Ensure note exists and belongs to the authenticated user before deleting
    const deletedNote = await Note.findOneAndDelete({ _id: id, userId: req.user._id });

    if (!deletedNote) {
      return res.status(404).json({
        success: false,
        message: 'Note not found',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Note deleted successfully',
      id: id,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
