// Simple test without Playwright test framework
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    // Navigate to login
    await page.goto('http://localhost:4000/login');
    
    // Login
    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'password123');
    await page.click('button[type="submit"]');
    
    // Wait for dashboard
    await page.waitForURL('http://localhost:4000/dashboard');
    
    // Go to scrape page
    await page.goto('http://localhost:4000/dashboard/job-interests/scrape');
    
    // Enter URL
    const url = 'https://example.com/jobs/senior-site-reliability-engineer';
    await page.fill('input[type="url"]', url);
    
    // Check button state
    const importButton = await page.$('button:has-text("Import")');
    const isDisabled = await importButton.getAttribute('disabled');
    
    console.log('Import button disabled:', isDisabled);
    
    if (isDisabled === null) {
      console.log('Import button is enabled, clicking...');
      await importButton.click();
      await page.waitForTimeout(10000); // Wait for processing
    } else {
      console.log('Import button is disabled');
      // Check if Ollama is being checked
      const status = await page.$('text=Checking Ollama server...');
      if (status) {
        console.log('Ollama is being checked, waiting...');
        await page.waitForTimeout(6000); // Wait for timeout
      }
    }
    
    // Check final state
    const error = await page.$('text=Ollama server is not available');
    if (error) {
      console.log('Ollama is not available');
    } else {
      console.log('Import completed or in progress');
    }
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await browser.close();
  }
})();