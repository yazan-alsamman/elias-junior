const mongoose = require('mongoose');

function isAtlasUri(uri) {
  if (uri.startsWith('mongodb+srv://')) return true;
  // Standard (non-SRV) Atlas strings list *.mongodb.net replica set members.
  if (uri.startsWith('mongodb://') && uri.includes('.mongodb.net')) return true;
  return false;
}

function mongooseOptions(uri) {
  if (isAtlasUri(uri)) {
    return {
      serverSelectionTimeoutMS: 30000,
      maxPoolSize: 10,
      // Prefer IPv4 after SRV resolve; helps some Windows / ISP setups that stall on IPv6.
      family: 4,
    };
  }
  // Local standalone: directConnection + family:4 reduces "monitor closed" issues on Windows.
  return {
    serverSelectionTimeoutMS: 15000,
    family: 4,
    directConnection: true,
    maxPoolSize: 5,
  };
}

async function connectDB() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error('Missing MONGODB_URI in .env');
    process.exit(1);
  }
  try {
    await mongoose.connect(uri, mongooseOptions(uri));
    console.log('MongoDB connected');
    console.log(
      isAtlasUri(uri)
        ? '  → persistence: MongoDB Atlas (cloud)'
        : '  → persistence: local mongod only (this machine)',
    );
    console.log(
      `  → writing to database "${mongoose.connection.name}" (auth users live in collection "users")`,
    );
  } catch (err) {
    console.error('MongoDB connection error:', err.message);
    if (isAtlasUri(uri)) {
      if (uri.startsWith('mongodb+srv://') && String(err.message).includes('querySrv')) {
        console.error(
          'Atlas SRV DNS timed out. Try: (1) Atlas Connect → turn OFF "SRV" and use the standard mongodb:// URI, (2) set PC DNS to 1.1.1.1 or 8.8.8.8, (3) disable VPN, (4) run: ipconfig /flushdns',
        );
      } else {
        console.error(
          'Atlas: set MONGODB_URI with your password (URL-encode special chars). In Atlas → Network Access, allow your IP.',
        );
      }
    } else {
      console.error(
        'Tip: 27017 must be mongod (not another app). Check: netstat -ano | findstr :27017 then tasklist /FI "PID eq <pid>".',
      );
    }
    process.exit(1);
  }
}

module.exports = connectDB;
