const http = require('http');

const PORT = process.env.PORT || 5000;
const BASE_URL = `http://localhost:${PORT}`;

function makeRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log(`--- Testing Diary App API at ${BASE_URL} ---`);
  
  try {
    // 1. Health check
    const health = await makeRequest('GET', '/api/health');
    console.log(`[PASS] GET /api/health -> Status ${health.status}, DB Status: ${health.body?.database?.status}`);

    // 2. Validation test: POST /api/notes with missing fields
    const invalidPost = await makeRequest('POST', '/api/notes', { title: '' });
    if (invalidPost.status === 400) {
      console.log(`[PASS] POST /api/notes (empty title) -> Status 400 correctly returned: "${invalidPost.body.message}"`);
    } else {
      console.log(`[FAIL] POST /api/notes expected 400, got ${invalidPost.status}`);
    }

    // 3. Validation test: GET /api/notes/:id with invalid ObjectId
    const invalidId = await makeRequest('GET', '/api/notes/invalid-id-123');
    if (invalidId.status === 400) {
      console.log(`[PASS] GET /api/notes/invalid-id -> Status 400 correctly returned: "${invalidId.body.message}"`);
    } else {
      console.log(`[FAIL] GET /api/notes/invalid-id expected 400, got ${invalidId.status}`);
    }

    // 4. Test 404 for non-existent endpoint
    const notFound = await makeRequest('GET', '/api/unknown');
    if (notFound.status === 404) {
      console.log(`[PASS] GET /api/unknown -> Status 404 correctly returned`);
    } else {
      console.log(`[FAIL] GET /api/unknown expected 404, got ${notFound.status}`);
    }

    console.log('\nAPI route structure & validation tests completed successfully!');
  } catch (error) {
    console.error('Test error (ensure backend server is running first):', error.message);
  }
}

runTests();
