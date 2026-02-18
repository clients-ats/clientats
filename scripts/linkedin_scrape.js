#!/usr/bin/env node

/**
 * LinkedIn Job Search Scraper - Sidecar Script
 *
 * Connects to user's Chrome via CDP (Chrome DevTools Protocol) to scrape
 * LinkedIn job search results. Requires Chrome launched with:
 *   google-chrome --remote-debugging-port=9222
 *
 * Usage:
 *   node linkedin_scrape.js search <search_url> [--max-jobs=25]
 *   node linkedin_scrape.js detail <job_id>
 *   node linkedin_scrape.js public <job_id>     # fetch JSON-LD from public page
 *
 * Output: JSON to stdout (structured job data)
 * Logs: stderr (for Elixir to separate from data)
 */

const { chromium } = require('playwright');

const CDP_ENDPOINT = process.env.CDP_ENDPOINT || 'http://localhost:9222';

// Human-like delays (ms)
const DELAY_MIN = 2000;
const DELAY_MAX = 5000;

function log(msg) {
  process.stderr.write(`[linkedin_scrape] ${msg}\n`);
}

function randomDelay(min = DELAY_MIN, max = DELAY_MAX) {
  return Math.floor(Math.random() * (max - min) + min);
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function connectBrowser() {
  log(`Connecting to Chrome via CDP at ${CDP_ENDPOINT}...`);
  try {
    const browser = await chromium.connectOverCDP(CDP_ENDPOINT);
    log('Connected successfully');
    return browser;
  } catch (err) {
    log(`CDP connection failed: ${err.message}`);
    log('Make sure Chrome is running with: google-chrome --remote-debugging-port=9222');
    process.exit(1);
  }
}

/**
 * Extract job listings from a LinkedIn search results page.
 * Uses multiple strategies: data attributes, ARIA roles, and DOM structure.
 */
async function scrapeSearchResults(searchUrl, maxJobs = 25) {
  const browser = await connectBrowser();

  try {
    // Use existing context (logged-in session)
    const contexts = browser.contexts();
    const context = contexts[0] || await browser.newContext();
    const page = await context.newPage();

    log(`Navigating to: ${searchUrl}`);
    await page.goto(searchUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await sleep(randomDelay(3000, 6000));

    // Wait for job listings to appear
    log('Waiting for job listings...');
    try {
      await page.waitForSelector(
        '[data-job-id], .job-card-container, .jobs-search-results__list-item',
        { timeout: 15000 }
      );
    } catch {
      log('No job cards found via selectors, trying alternative extraction...');
    }

    // Strategy 1: Extract via data-job-id + proven selectors
    // Company from logo alt text, title from strong in link, location from leaf spans
    let jobs = await page.evaluate(() => {
      const results = [];
      const seen = new Set();

      // Find list items with data-job-id or ember-view class
      const listItems = document.querySelectorAll('li[data-job-id], li.ember-view');

      listItems.forEach(li => {
        const link = li.querySelector('a[href*="/jobs/view/"]');
        if (!link) return;

        const match = link.href.match(/\/jobs\/view\/(\d+)/);
        if (!match) return;
        const jobId = match[1];
        if (seen.has(jobId)) return;
        seen.add(jobId);

        const dataJobId = li.getAttribute('data-job-id') || jobId;

        // Title: from <strong> inside the job link (most reliable)
        const title = link.querySelector('strong')?.textContent?.trim() ||
                      link.textContent?.trim()?.replace(/\s+/g, ' ');

        // Company: from logo image alt text (proven strategy)
        const logoImg = li.querySelector('img[alt*="logo"]');
        let company = logoImg?.alt?.replace(' logo', '')?.trim() || null;

        // Company fallback: CSS class selectors
        if (!company) {
          const companyEl = li.querySelector(
            '.job-card-container__primary-description, ' +
            '.artdeco-entity-lockup__subtitle, h4'
          );
          company = companyEl?.textContent?.trim()?.replace(/\s+/g, ' ') || null;
        }

        // Location: find leaf span/div containing "Remote" or comma-separated place
        let location = null;
        const spans = li.querySelectorAll('span, div');
        for (const span of spans) {
          const text = span.textContent?.trim();
          if (text && (text.includes('Remote') || text.match(/,\s*[A-Z]{2}/)) &&
              span.children.length === 0 && text.length < 60) {
            location = text;
            break;
          }
        }
        // Location fallback: CSS selectors
        if (!location) {
          const locEl = li.querySelector(
            '.job-card-container__metadata-item, [class*="metadata"]'
          );
          location = locEl?.textContent?.trim()?.replace(/\s+/g, ' ') || null;
        }

        const timeEl = li.querySelector('time');

        results.push({
          linkedin_job_id: dataJobId,
          title: title || null,
          company,
          location,
          posted_at: timeEl?.getAttribute('datetime') || timeEl?.textContent?.trim() || null,
          url: `https://www.linkedin.com/jobs/view/${dataJobId}/`,
        });
      });

      return results;
    });

    // Strategy 2: If no data-job-id cards found, try extracting from links
    if (jobs.length === 0) {
      log('Strategy 1 (data-job-id) yielded 0 results, trying link extraction...');
      jobs = await page.evaluate(() => {
        const results = [];
        const seen = new Set();

        // Find all links to job postings
        const links = document.querySelectorAll('a[href*="/jobs/view/"]');
        links.forEach(link => {
          const match = link.href.match(/\/jobs\/view\/(\d+)/);
          if (!match) return;
          const jobId = match[1];
          if (seen.has(jobId)) return;
          seen.add(jobId);

          // Walk up to find the card container
          let card = link.closest('li') || link.closest('[class*="card"]') || link.parentElement;

          const title = link.textContent?.trim()?.replace(/\s+/g, ' ') || null;

          results.push({
            linkedin_job_id: jobId,
            title,
            company: null,
            location: null,
            posted_at: null,
            url: `https://www.linkedin.com/jobs/view/${jobId}/`,
          });
        });

        return results;
      });
    }

    // Strategy 3: Parse from page content / accessibility tree
    if (jobs.length === 0) {
      log('Strategy 2 (links) yielded 0 results, trying page title parsing...');
      const title = await page.title();
      jobs = [{ linkedin_job_id: null, title, company: null, location: null, url: searchUrl }];
    }

    // Limit results
    jobs = jobs.slice(0, maxJobs);
    log(`Extracted ${jobs.length} job listings`);

    // Scroll to load more if needed
    if (jobs.length < maxJobs) {
      log('Scrolling to load more results...');
      const scrollAttempts = Math.min(3, Math.ceil((maxJobs - jobs.length) / 25));
      for (let i = 0; i < scrollAttempts; i++) {
        await page.evaluate(() => {
          const container = document.querySelector('.jobs-search-results-list, .scaffold-layout__list');
          if (container) {
            container.scrollTop = container.scrollHeight;
          } else {
            window.scrollTo(0, document.body.scrollHeight);
          }
        });
        await sleep(randomDelay());

        const moreJobs = await page.evaluate((existingIds) => {
          const results = [];
          const cards = document.querySelectorAll('[data-job-id]');
          cards.forEach(card => {
            const jobId = card.getAttribute('data-job-id');
            if (!jobId || existingIds.includes(jobId)) return;

            const titleEl = card.querySelector(
              '.job-card-list__title, a[href*="/jobs/view/"] strong, h3'
            );
            const companyEl = card.querySelector(
              '.job-card-container__primary-description, h4'
            );
            const locationEl = card.querySelector(
              '.job-card-container__metadata-item, [class*="metadata"]'
            );
            const timeEl = card.querySelector('time');

            results.push({
              linkedin_job_id: jobId,
              title: titleEl?.textContent?.trim()?.replace(/\s+/g, ' ') || null,
              company: companyEl?.textContent?.trim()?.replace(/\s+/g, ' ') || null,
              location: locationEl?.textContent?.trim()?.replace(/\s+/g, ' ') || null,
              posted_at: timeEl?.getAttribute('datetime') || null,
              url: `https://www.linkedin.com/jobs/view/${jobId}/`,
            });
          });
          return results;
        }, jobs.map(j => j.linkedin_job_id));

        jobs = jobs.concat(moreJobs);
        log(`After scroll ${i + 1}: ${jobs.length} total jobs`);
      }
      jobs = jobs.slice(0, maxJobs);
    }

    await page.close();
    return { success: true, jobs, count: jobs.length };

  } catch (err) {
    log(`Search scrape error: ${err.message}`);
    return { success: false, error: err.message, jobs: [] };
  } finally {
    browser.disconnect();
  }
}

/**
 * Extract full job details from the detail panel (logged-in view).
 * Clicks a job card and extracts from the right panel.
 */
async function scrapeJobDetail(jobId) {
  const browser = await connectBrowser();

  try {
    const contexts = browser.contexts();
    const context = contexts[0] || await browser.newContext();
    const page = await context.newPage();

    const url = `https://www.linkedin.com/jobs/view/${jobId}/`;
    log(`Navigating to job detail: ${url}`);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await sleep(randomDelay(3000, 5000));

    const detail = await page.evaluate(() => {
      // Extract from the job detail view
      const title = document.querySelector(
        '.job-details-jobs-unified-top-card__job-title, ' +
        '.jobs-unified-top-card__job-title, h1'
      )?.textContent?.trim();

      const company = document.querySelector(
        '.job-details-jobs-unified-top-card__company-name, ' +
        '.jobs-unified-top-card__company-name, ' +
        'a[href*="/company/"]'
      )?.textContent?.trim();

      const location = document.querySelector(
        '.job-details-jobs-unified-top-card__bullet, ' +
        '.jobs-unified-top-card__bullet, ' +
        '[class*="workplace-type"]'
      )?.textContent?.trim();

      // Description - often in a rich text container
      const descEl = document.querySelector(
        '#job-details, .jobs-description__content, ' +
        '.jobs-box__html-content, [class*="description"]'
      );
      const description_html = descEl?.innerHTML || null;
      const description_text = descEl?.textContent?.trim() || null;

      // Salary info
      const salaryEl = document.querySelector(
        '.job-details-jobs-unified-top-card__job-insight, ' +
        '[class*="salary"], [class*="compensation"]'
      );
      const salary_text = salaryEl?.textContent?.trim() || null;

      // Work type
      const workTypeEl = document.querySelector(
        '.job-details-jobs-unified-top-card__workplace-type, ' +
        '[class*="workplace-type"]'
      );
      const work_type = workTypeEl?.textContent?.trim() || null;

      // Employment type
      const empTypeEl = document.querySelector('[class*="employment-type"]');
      const employment_type = empTypeEl?.textContent?.trim() || null;

      // Posted time
      const timeEl = document.querySelector(
        '.jobs-unified-top-card__posted-date, time, [class*="posted"]'
      );
      const posted_at = timeEl?.getAttribute('datetime') || timeEl?.textContent?.trim() || null;

      // Application count
      const appCountEl = document.querySelector('[class*="applicant-count"]');
      const applicant_count = appCountEl?.textContent?.trim() || null;

      return {
        title, company, location,
        description_html, description_text,
        salary_text, work_type, employment_type,
        posted_at, applicant_count
      };
    });

    // Fallback: parse from page title
    if (!detail.title) {
      const pageTitle = await page.title();
      const match = pageTitle.match(/^(.+?)\s*\|\s*(.+?)\s*\|/);
      if (match) {
        detail.title = match[1].trim();
        detail.company = detail.company || match[2].trim();
      }
    }

    await page.close();
    return { success: true, linkedin_job_id: jobId, ...detail };

  } catch (err) {
    log(`Detail scrape error: ${err.message}`);
    return { success: false, linkedin_job_id: jobId, error: err.message };
  } finally {
    browser.disconnect();
  }
}

/**
 * Fetch JSON-LD structured data from a public (guest) job page.
 * Uses a fresh incognito context to avoid SPA redirect.
 */
async function scrapePublicJsonLd(jobId) {
  const browser = await connectBrowser();

  try {
    // Create an incognito context (no cookies = public/guest view)
    const context = await browser.newContext();
    const page = await context.newPage();

    const url = `https://www.linkedin.com/jobs/view/${jobId}/`;
    log(`Fetching public page for JSON-LD: ${url}`);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await sleep(randomDelay(2000, 4000));

    const result = await page.evaluate(() => {
      // Extract JSON-LD
      const scripts = document.querySelectorAll('script[type="application/ld+json"]');
      const jsonLd = [];
      scripts.forEach(s => {
        try { jsonLd.push(JSON.parse(s.textContent)); } catch (e) { /* skip */ }
      });

      // Find JobPosting schema
      let jobPosting = null;
      for (const ld of jsonLd) {
        if (ld['@type'] === 'JobPosting') {
          jobPosting = ld;
          break;
        }
        // Check for @graph array
        if (ld['@graph']) {
          const found = ld['@graph'].find(item => item['@type'] === 'JobPosting');
          if (found) { jobPosting = found; break; }
        }
      }

      // Also extract from meta tags as fallback
      const meta = {};
      document.querySelectorAll('meta[property^="og:"]').forEach(m => {
        const key = m.getAttribute('property').replace('og:', '');
        meta[key] = m.getAttribute('content');
      });

      // Extract from the public page DOM (server-rendered, cleaner)
      const topCard = document.querySelector('.top-card-layout, .topcard');
      const title = topCard?.querySelector('h1, h2, .topcard__title')?.textContent?.trim();
      const company = topCard?.querySelector('a[class*="company"], .topcard__org-name-link')?.textContent?.trim();
      const location = topCard?.querySelector('.topcard__flavor--bullet, [class*="location"]')?.textContent?.trim();

      // Description from public page
      const descEl = document.querySelector('.description__text, .show-more-less-html__markup');
      const description_html = descEl?.innerHTML || null;
      const description_text = descEl?.textContent?.trim() || null;

      // Criteria (employment type, seniority, etc.)
      const criteria = [];
      document.querySelectorAll('.description__job-criteria-item').forEach(item => {
        const label = item.querySelector('.description__job-criteria-subheader')?.textContent?.trim();
        const value = item.querySelector('.description__job-criteria-text')?.textContent?.trim();
        if (label && value) criteria.push({ label, value });
      });

      return { jsonLd: jobPosting, meta, title, company, location, description_html, description_text, criteria };
    });

    await context.close();

    // Structure the response
    const response = {
      success: true,
      linkedin_job_id: jobId,
      json_ld: result.jsonLd,
      meta: result.meta,
      page_data: {
        title: result.title,
        company: result.company,
        location: result.location,
        description_html: result.description_html,
        description_text: result.description_text,
        criteria: result.criteria,
      }
    };

    // Merge JSON-LD fields if available
    if (result.jsonLd) {
      response.structured = {
        title: result.jsonLd.title,
        description: result.jsonLd.description,
        date_posted: result.jsonLd.datePosted,
        valid_through: result.jsonLd.validThrough,
        employment_type: result.jsonLd.employmentType,
        company: result.jsonLd.hiringOrganization?.name,
        company_url: result.jsonLd.hiringOrganization?.sameAs,
        location: result.jsonLd.jobLocation?.address?.addressLocality,
        region: result.jsonLd.jobLocation?.address?.addressRegion,
        country: result.jsonLd.jobLocation?.address?.addressCountry,
        salary_min: result.jsonLd.baseSalary?.value?.minValue,
        salary_max: result.jsonLd.baseSalary?.value?.maxValue,
        salary_currency: result.jsonLd.baseSalary?.currency,
        salary_unit: result.jsonLd.baseSalary?.value?.unitText,
      };
    }

    return response;

  } catch (err) {
    log(`Public page scrape error: ${err.message}`);
    return { success: false, linkedin_job_id: jobId, error: err.message };
  } finally {
    browser.disconnect();
  }
}

// --- CLI Entry Point ---

async function main() {
  const [command, ...args] = process.argv.slice(2);

  if (!command) {
    log('Usage: node linkedin_scrape.js <search|detail|public> <url_or_id> [options]');
    process.exit(1);
  }

  let result;

  switch (command) {
    case 'search': {
      const url = args[0];
      if (!url) {
        log('Error: search URL required');
        process.exit(1);
      }
      const maxFlag = args.find(a => a.startsWith('--max-jobs='));
      const maxJobs = maxFlag ? parseInt(maxFlag.split('=')[1], 10) : 25;
      result = await scrapeSearchResults(url, maxJobs);
      break;
    }

    case 'detail': {
      const jobId = args[0];
      if (!jobId) {
        log('Error: job ID required');
        process.exit(1);
      }
      result = await scrapeJobDetail(jobId);
      break;
    }

    case 'public': {
      const jobId = args[0];
      if (!jobId) {
        log('Error: job ID required');
        process.exit(1);
      }
      result = await scrapePublicJsonLd(jobId);
      break;
    }

    default:
      log(`Unknown command: ${command}`);
      log('Usage: node linkedin_scrape.js <search|detail|public> <url_or_id>');
      process.exit(1);
  }

  // Output result as JSON to stdout
  process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  process.exit(result.success ? 0 : 1);
}

main().catch(err => {
  log(`Fatal error: ${err.message}`);
  process.exit(1);
});
