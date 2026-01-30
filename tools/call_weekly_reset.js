// Simple test to call the deployed manualWeeklyReset function
// This uses the Firebase Admin SDK to call the deployed function

const functions = require('firebase-functions');
const fetch = require('node-fetch');

const PROJECT_ID = 'readmev2';
const REGION = 'us-central1';
const FUNCTION_NAME = 'manualWeeklyReset';

async function callResetFunction() {
  try {
    console.log('📞 Calling deployed manualWeeklyReset function...\n');
    
    const url = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({})
    });
    
    const result = await response.json();
    
    console.log('✅ Response:', result);
    console.log('\n📊 Weekly reset completed successfully!\n');
    
  } catch (error) {
    console.error('❌ Error calling function:', error.message);
  }
}

callResetFunction();
