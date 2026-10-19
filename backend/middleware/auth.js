const jwt = require('jsonwebtoken');
const User = require('../models/User');

/**
 * Authentication Middleware: Protects private routes using JWT Bearer tokens
 */
const protect = async (req, res, next) => {
  let token;

  // Read Authorization header
  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer ')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }

  // Reject if token is missing
  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access denied. Authentication token is missing.',
    });
  }

  try {
    const secret = process.env.JWT_SECRET || 'diaryapp_fallback_secret_key_2026';
    
    // Verify signature & expiration
    const decoded = jwt.verify(token, secret);

    // Fetch user from DB (excluding password)
    const user = await User.findById(decoded.id).select('-password');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid session. User account not found.',
      });
    }

    // Attach authenticated user to request object
    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Session expired. Please log in again.',
      });
    }
    return res.status(401).json({
      success: false,
      message: 'Invalid authentication token.',
    });
  }
};

module.exports = { protect };
