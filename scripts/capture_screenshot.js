#!/usr/bin/env node

/**
 * Capture a screenshot of a URL using Playwright
 *
 * Usage: node capture_screenshot.js <url> <output_path> [wait_for]
 *
 * Arguments:
 *   url          - The URL to capture
 *   output_path  - Where to save the screenshot
 *   wait_for     - Optional selector or "load" (default: "load")
 */

const { chromium } = require('playwright');
const path = require('path');

async function captureScreenshot() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('Usage: node capture_screenshot.js <url> <output_path> [wait_for]');
    process.exit(1);
  }

  const url = args[0];
  const outputPath = args[1];
  const waitFor = args[2] || 'load';

  // Validate URL
  try {
    new URL(url);
  } catch (e) {
    console.error(`Invalid URL: ${url}`);
    process.exit(1);
  }

  let browser;
  try {
    console.log(`[Script] Starting browser...`);
    browser = await chromium.launch({
      headless: true,
      executablePath: '/usr/bin/google-chrome',
      args: [
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-sandbox'
      ]
    });

    console.log(`[Script] Creating page context...`);
    const context = await browser.newContext({
      viewport: { width: 1920, height: 1080 },
      // User agent to avoid blocking
      userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    });

    const page = await context.newPage();

    // Set a reasonable timeout
    page.setDefaultTimeout(30000);

    console.log(`[Script] Navigating to: ${url}`);
    try {
      await page.goto(url, { waitUntil: 'networkidle' });
      console.log(`[Script] Page loaded, waiting for content...`);
    } catch (navError) {
      // Page might have timed out but loaded enough to screenshot
      console.log(`[Script] Navigation warning (continuing): ${navError.message}`);
    }

    // Wait for content to be visible
    if (waitFor === 'load') {
      // Wait for body to have content
      try {
        await page.waitForFunction(() => {
          const body = document.body;
          return body && body.offsetHeight > 100;
        }, { timeout: 15000 });
        console.log(`[Script] Page content loaded`);
      } catch (e) {
        console.log(`[Script] Content wait timeout (continuing with screenshot): ${e.message}`);
      }
    } else {
      // Wait for a specific selector
      try {
        await page.waitForSelector(waitFor, { timeout: 15000 });
        console.log(`[Script] Selector found: ${waitFor}`);
      } catch (e) {
        console.log(`[Script] Selector timeout (continuing with screenshot): ${e.message}`);
      }
    }

    // Wait a bit for any remaining rendering
    await page.waitForTimeout(2000);

    console.log(`[Script] Taking screenshot and saving to: ${outputPath}`);
    // Capture the full scrollable page, not just the viewport
    await page.screenshot({ path: outputPath, fullPage: true });

    console.log(`[Script] Screenshot saved successfully`);

    await context.close();
    await browser.close();

    console.log(`[Script] Browser closed`);
    process.exit(0);

  } catch (error) {
    console.error(`[Script] Error: ${error.message}`);
    if (browser) {
      await browser.close();
    }
    process.exit(1);
  }
}

captureScreenshot();
