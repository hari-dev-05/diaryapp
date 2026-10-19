const http = require('http');

const PORT = process.env.PORT || 5000;
const BASE_URL = `http://localhost:${PORT}`;

function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const headers = {
      'Content-Type': 'application/json',
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: headers,
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
  console.log(`=== Testing Diary App Auth & User Isolation API at ${BASE_URL} ===\n`);
  let passedCount = 0;
  let failedCount = 0;

  function assert(condition, testName, details = '') {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passedCount++;
    } else {
      console.error(`[FAIL] ${testName} - Details: ${details}`);
      failedCount++;
    }
  }

  try {
    // 1. Health check
    const health = await makeRequest('GET', '/api/health');
    assert(health.status === 200, 'GET /api/health -> Status 200');

    // 2. Validation: Short password (< 4 characters)
    const shortPassRes = await makeRequest('POST', '/api/auth/signup', {
      name: 'Test Short',
      email: 'shortpass@example.com',
      password: '123',
    });
    assert(
      shortPassRes.status === 400 && shortPassRes.body.message.includes('4 characters'),
      'POST /api/auth/signup rejects password < 4 chars (Status 400)',
      JSON.stringify(shortPassRes.body)
    );

    // 3. Validation: Missing token on protected /api/notes
    const noTokenRes = await makeRequest('GET', '/api/notes');
    assert(
      noTokenRes.status === 401,
      'GET /api/notes without token rejects with 401 Unauthorized',
      `Status: ${noTokenRes.status}`
    );

    // 4. Scenario A: Register User A
    const userAEmail = `user_a_${Date.now()}@example.com`;
    const signupARes = await makeRequest('POST', '/api/auth/signup', {
      name: 'User A',
      email: userAEmail,
      password: 'password123',
    });
    assert(
      signupARes.status === 201 && signupARes.body.token,
      'POST /api/auth/signup for User A succeeds with 201 and JWT token',
      JSON.stringify(signupARes.body)
    );
    const tokenA = signupARes.body.token;

    // 5. Validation: Duplicate email registration rejected
    const dupRes = await makeRequest('POST', '/api/auth/signup', {
      name: 'User A Duplicate',
      email: userAEmail,
      password: 'password123',
    });
    assert(
      dupRes.status === 400,
      'POST /api/auth/signup with existing email rejects with 400 Bad Request',
      JSON.stringify(dupRes.body)
    );

    // 6. Validation: Invalid login credentials
    const badLoginRes = await makeRequest('POST', '/api/auth/login', {
      email: userAEmail,
      password: 'wrongpassword',
    });
    assert(
      badLoginRes.status === 401 && badLoginRes.body.message === 'Invalid email or password',
      'POST /api/auth/login with wrong password rejects with generic 401 error',
      JSON.stringify(badLoginRes.body)
    );

    // 7. Login as User A
    const loginARes = await makeRequest('POST', '/api/auth/login', {
      email: userAEmail,
      password: 'password123',
    });
    assert(
      loginARes.status === 200 && loginARes.body.token,
      'POST /api/auth/login for User A succeeds with 200',
      JSON.stringify(loginARes.body)
    );

    // 8. Scenario A (cont.): User A creates a private note
    const noteARes = await makeRequest(
      'POST',
      '/api/notes',
      {
        title: 'USER_A_PRIVATE_NOTE',
        content: 'This note belongs only to User A.',
      },
      tokenA
    );
    assert(
      noteARes.status === 201 && noteARes.body.data?.title === 'USER_A_PRIVATE_NOTE',
      'POST /api/notes creates note for User A',
      JSON.stringify(noteARes.body)
    );
    const noteAId = noteARes.body.data.id || noteARes.body.data._id;

    // 9. Scenario B: Register User B
    const userBEmail = `user_b_${Date.now()}@example.com`;
    const signupBRes = await makeRequest('POST', '/api/auth/signup', {
      name: 'User B',
      email: userBEmail,
      password: 'passwordB123',
    });
    assert(
      signupBRes.status === 201 && signupBRes.body.token,
      'POST /api/auth/signup for User B succeeds with 201 and JWT token',
      JSON.stringify(signupBRes.body)
    );
    const tokenB = signupBRes.body.token;

    // 10. Scenario B (cont.): Verify User B cannot see User A's note in GET /api/notes
    const listBRes = await makeRequest('GET', '/api/notes', null, tokenB);
    const hasUserANoteInB = listBRes.body.data?.some(
      (n) => n.title === 'USER_A_PRIVATE_NOTE' || (n.id || n._id) === noteAId
    );
    assert(
      listBRes.status === 200 && !hasUserANoteInB && listBRes.body.count === 0,
      'GET /api/notes for User B returns ONLY User B notes (User A note is NOT visible)',
      `Found note: ${hasUserANoteInB}, Count: ${listBRes.body.count}`
    );

    // 11. Scenario B (cont.): User B creates their own note
    const noteBRes = await makeRequest(
      'POST',
      '/api/notes',
      {
        title: 'USER_B_PRIVATE_NOTE',
        content: 'This note belongs only to User B.',
      },
      tokenB
    );
    assert(
      noteBRes.status === 201 && noteBRes.body.data?.title === 'USER_B_PRIVATE_NOTE',
      'POST /api/notes creates note for User B',
      JSON.stringify(noteBRes.body)
    );

    // 12. Scenario C: User A still sees only User A's note, NOT User B's note
    const listARes = await makeRequest('GET', '/api/notes', null, tokenA);
    const hasUserANoteInA = listARes.body.data?.some((n) => (n.id || n._id) === noteAId);
    const hasUserBNoteInA = listARes.body.data?.some(
      (n) => n.title === 'USER_B_PRIVATE_NOTE'
    );
    assert(
      listARes.status === 200 && hasUserANoteInA && !hasUserBNoteInA,
      'GET /api/notes for User A returns User A note and excludes User B note',
      JSON.stringify(listARes.body)
    );

    // 13. Scenario D: User B attempts to GET User A's note directly
    const crossGetRes = await makeRequest('GET', `/api/notes/${noteAId}`, null, tokenB);
    assert(
      crossGetRes.status === 404,
      'GET /api/notes/:id for unauthorized user returns 404 Not Found',
      `Status: ${crossGetRes.status}`
    );

    // 14. Scenario D: User B attempts to PUT User A's note directly
    const crossPutRes = await makeRequest(
      'PUT',
      `/api/notes/${noteAId}`,
      { title: 'HACKED_BY_B' },
      tokenB
    );
    assert(
      crossPutRes.status === 404,
      'PUT /api/notes/:id for unauthorized user returns 404 Not Found',
      `Status: ${crossPutRes.status}`
    );

    // 15. Scenario D: User B attempts to DELETE User A's note directly
    const crossDeleteRes = await makeRequest('DELETE', `/api/notes/${noteAId}`, null, tokenB);
    assert(
      crossDeleteRes.status === 404,
      'DELETE /api/notes/:id for unauthorized user returns 404 Not Found',
      `Status: ${crossDeleteRes.status}`
    );

    // 16. Verify User A's note was untouched after malicious attempts
    const verifyNoteARes = await makeRequest('GET', `/api/notes/${noteAId}`, null, tokenA);
    assert(
      verifyNoteARes.status === 200 &&
        verifyNoteARes.body.data?.title === 'USER_A_PRIVATE_NOTE',
      'User A note is safe and unchanged after cross-user attack attempts',
      JSON.stringify(verifyNoteARes.body)
    );

    // 17. User A deletes their own note successfully
    const deleteARes = await makeRequest('DELETE', `/api/notes/${noteAId}`, null, tokenA);
    assert(
      deleteARes.status === 200,
      'DELETE /api/notes/:id for owner succeeds with 200',
      JSON.stringify(deleteARes.body)
    );

    console.log(`\n=== Test Results: ${passedCount} PASSED, ${failedCount} FAILED ===\n`);
    if (failedCount > 0) {
      process.exit(1);
    }
  } catch (error) {
    console.error('Fatal test error:', error.message);
    process.exit(1);
  }
}

runTests();
