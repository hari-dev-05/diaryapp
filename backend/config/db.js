const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const connUri = process.env.MONGO_URI;

    if (!connUri) {
      console.error('Error: MONGO_URI is not defined in backend/.env');
      return false;
    }

    if (connUri.includes('<username>') || connUri.includes('<password>')) {
      console.warn('⚠️ Warning: MONGO_URI contains placeholder credentials (<username> or <password>).');
      console.warn('Please update backend/.env with your actual MongoDB Atlas connection string.');
    }

    const conn = await mongoose.connect(connUri, {
      dbName: 'diaryapp',
    });

    console.log(`MongoDB Connected successfully: ${conn.connection.host} [Database: ${conn.connection.name}]`);
    return true;
  } catch (error) {
    console.error(`MongoDB connection error: ${error.message}`);
    // Don't exit process immediately so server can display helpful diagnostics to the developer
    return false;
  }
};

module.exports = connectDB;
