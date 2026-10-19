const express = require('express');
const mongoose = require('mongoose');
const Note = require('../models/Note');

const router = express.Router();

// Helper to validate MongoDB ObjectId
const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

/**
 * @route   GET /api/notes
 * @desc    Retrieve all diary notes sorted by newest first
 */
router.get('/', async (req, res, next) => {
  try {
    // Sort by createdAt descending (newest first)
    const notes = await Note.find().sort({ createdAt: -1 });
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
 * @desc    Retrieve a specific note by ID
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

    const note = await Note.findById(id);

    if (!note) {
      return res.status(404).json({
        success: false,
        message: `Note with id ${id} not found`,
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
 * @desc    Save a new diary note
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

    const newNote = await Note.create({
      title: title.trim(),
      content: content.trim(),
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
 * @desc    Update an existing note
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

    const updatedNote = await Note.findByIdAndUpdate(id, updateData, {
      new: true,
      runValidators: true,
    });

    if (!updatedNote) {
      return res.status(404).json({
        success: false,
        message: `Note with id ${id} not found`,
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
 * @desc    Delete a note
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

    const deletedNote = await Note.findByIdAndDelete(id);

    if (!deletedNote) {
      return res.status(404).json({
        success: false,
        message: `Note with id ${id} not found`,
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
