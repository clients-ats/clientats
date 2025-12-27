const { test, expect } = require('@playwright/test');

// Test configuration
const BASE_URL = 'http://localhost:4000';
const EMAIL = 'test@example.com';
const PASSWORD = 'password123';
const JOB_URL = 'https://example.com/jobs/senior-site-reliability-engineer';

// Helper function to login
async function login(page) {
  await page.goto(`${BASE_URL}/login`);
  await page.fill('input[name="email"]', EMAIL);
  await page.fill('input[name="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL(`${BASE_URL}/dashboard`);
}

// Helper function to navigate to scrape page
async function navigateToScrape(page) {
  await page.goto(`${BASE_URL}/dashboard/job-interests/scrape`);
  await expect(page).toHaveURL(`${BASE_URL}/dashboard/job-interests/scrape`);
}

test('Import job from URL', async ({ page }) => {
  // Login
  await login(page);
  
  // Navigate to scrape page
  await navigateToScrape(page);
  
  // Test 1: Check if page loads
  await expect(page.locator('h1:has-text("Import Job from URL")')).toBeVisible();
  
  // Test 2: Enter URL
  const urlInput = page.locator('input[type="url"]');
  await urlInput.fill(JOB_URL);
  
  // Test 3: Check if import button is enabled
  const importButton = page.locator('button:has-text("Import")');
  const isDisabled = await importButton.getAttribute('disabled');
  
  if (isDisabled) {
    console.log('Import button is disabled');
    // Check why it's disabled
    const providerStatus = page.locator('text=Checking Ollama server...');
    if (await providerStatus.isVisible()) {
      console.log('Ollama is being checked');
      // Wait for check to complete
      await page.waitForTimeout(6000); // Wait for timeout
    }
  }
  
  // Test 4: Click import button if enabled
  if (!isDisabled) {
    await importButton.click();
    console.log('Import button clicked');
    
    // Wait for processing
    await page.waitForTimeout(10000); // Wait for LLM processing
    
    // Check for results or errors
    const errorMessage = page.locator('text=Ollama server is not available');
    if (await errorMessage.isVisible()) {
      console.log('Ollama is not available');
    } else {
      console.log('Import completed or in progress');
    }
  } else {
    console.log('Button still disabled after timeout');
  }
});

// Test provider selection
async function testProviderSelection(page) {
  await login(page);
  await navigateToScrape(page);
  
  // Open provider settings
  const settingsButton = page.locator('button:has-text("Show Settings")');
  await settingsButton.click();
  
  // Check if providers are visible
  const openaiProvider = page.locator('text=OpenAI (GPT-4)');
  await expect(openaiProvider).toBeVisible();
  
  // Select Ollama
  const ollamaRadio = page.locator('input[value="ollama"]');
  await ollamaRadio.click();
  
  // Check status
  const statusMessage = page.locator('text=Checking Ollama server...');
  await expect(statusMessage).toBeVisible();
};

// Run tests
(async () => {
  const { chromium } = require('playwright');
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    await testImport(page);
    // await testProviderSelection(page);
  } catch (error) {
    console.error('Test failed:', error);
  } finally {
    await browser.close();
  }
})();