// Test the Cloud Function directly via REST
const nodeFetch = require('node-fetch');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize to get auth token
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readmev2'
});

async function testQuizGeneration() {
  try {
    console.log('Getting access token...');
    
    // Get an ID token for the service account
    const token = await admin.app().auth().createCustomToken('test-user');
    
    console.log('Calling function...');
    const response = await nodeFetch('https://us-central1-readmev2.cloudfunctions.net/generateBookQuiz', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        data: { bookId: '6VfAndi5Yf85f6TJe9ti' }
      })
    });
    
    const data = await response.json();
    console.log('Response status:', response.status);
    console.log('Response:', JSON.stringify(data, null, 2));
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

testQuizGeneration();
