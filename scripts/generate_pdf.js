#!/usr/bin/env node

/**
 * Generate a PDF from HTML content using Playwright
 *
 * Usage: node generate_pdf.js <output_path> <html>
 *
 * Arguments:
 *   output_path  - Where to save the PDF
 *   html         - HTML content to convert to PDF
 */

const { chromium } = require('playwright');
const fs = require('fs');

async function generatePdf() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('Usage: node generate_pdf.js <output_path> <html>');
    process.exit(1);
  }

  const outputPath = args[0];
  const html = args[1];

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
    const context = await browser.newContext();
    const page = await context.newPage();

    console.log(`[Script] Setting HTML content...`);
    await page.setContent(html, { waitUntil: 'networkidle' });

    console.log(`[Script] Generating PDF and saving to: ${outputPath}`);
    await page.pdf({
      path: outputPath,
      format: 'A4',
      margin: {
        top: '20mm',
        bottom: '20mm',
        left: '20mm',
        right: '20mm'
      },
      printBackground: true
    });

    console.log(`[Script] PDF saved successfully`);

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

generatePdf();
