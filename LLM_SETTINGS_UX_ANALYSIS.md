# LLM Settings Pages - UX Analysis & Improvement Recommendations

## Executive Summary

Analysis of the RagPile LLM configuration pages has identified **7 major UX issues** ranging from backend/frontend inconsistencies to confusing provider selection flows. The pages show forms for 5 LLM providers but only 2 are actually implemented, causing user confusion and potential errors.

**Screenshots analyzed:** 3 pages (Ollama config, Gemini config, Provider Status)

---

## Critical Issues Found

### 🔴 Issue #1: Provider Inconsistency (Bug)
**Severity:** HIGH - Breaking Feature

**The Problem:**
- UI shows tabs for **5 providers**: OpenAI, Anthropic, Mistral, Gemini, Ollama
- Only **2 providers are implemented**: Gemini and Ollama
- The other 3 (OpenAI, Anthropic, Mistral) have fully-rendered Heex components but are **not supported in the backend**

**Evidence:**
```
Frontend (llm_config_live.ex):
  ✓ Renders all 5 provider forms (case statement for all 5)
  ✓ Forms exist: openai_form.ex, anthropic_form.ex, mistral_form.ex, gemini_form.ex, ollama_form.ex

Backend Support:
  ✗ LLMConfig.test_connection() - only handles :gemini and :ollama
  ✗ LLMConfig.validate_api_key() - only handles :gemini and :ollama
  ✗ LLM.Setting schema - @providers ~w(ollama gemini)
  ✗ Database - migration only supports 2 providers
```

**User Impact:**
- User might spend time configuring OpenAI/Anthropic/Mistral, save it, but it won't work
- Confusing: why show forms that don't work?
- May try multiple times before realizing it's not supported

**Beads Task:** `clientats-o53`

---

### 🟠 Issue #2: Model Selection UX (Feature)
**Severity:** MEDIUM - Error-prone

**The Problem:**
- **Gemini form** (and likely others): Uses free-text input fields for model names
  - Default Model: text input expecting "gemini-2.0-flash"
  - Vision Model: text input expecting "gemini-2.0-flash"
  - Text Model: text input expecting "gemini-2.0-flash"
- **Ollama form** (reference implementation): Uses proper dropdowns with model discovery
  - After clicking "Discover Models", dropdowns populate with actual available models
  - Much better UX - no typing required, hard to make mistakes

**Screenshot Evidence:**
```
Gemini Form shows:
┌─ Default Model ────────────────────┐
│ [gemini-2.0-flash]  ← free text   │ ← Error prone!
│ Used for general text processing   │
└────────────────────────────────────┘

Ollama Form shows:
┌─ Default Model (Text) ─────────────┐
│ ┌──────────────────────────────┐   │
│ │ Select a text model...      ▼│   │ ← Dropdown, much better!
│ │ - mistral:7b                 │   │
│ │ - qwen2.5:7b                 │   │
│ └──────────────────────────────┘   │
└────────────────────────────────────┘
```

**User Impact:**
- Users may typo model names and encounter errors at runtime
- No validation that the model they typed actually exists
- Inconsistent UX: Ollama is great, but Gemini/others are risky

**Beads Task:** `clientats-yfa`

---

### 🟠 Issue #3: Gemini Default Model (Task)
**Severity:** LOW - Quick Fix

**The Problem:**
- Current default: `gemini-2.0-flash`
- Should be: `gemini-2.5-flash` (latest recommended model)

**Locations to Update:**
1. `/lib/clientats_web/live/llm_config_live/components/gemini_form.ex` - placeholder text
2. `/lib/clientats/llm_config.ex` - `get_env_defaults()` function
3. `/config/dev.exs` - env var defaults
4. Any other config files

**Beads Task:** `clientats-5iu`

---

### 🟠 Issue #4: Active Provider Selection Clarity (Feature)
**Severity:** MEDIUM - Confusing UX

**The Problem:**
- Users can enable multiple providers but it's **completely unclear which one is actually used**
- No indication of:
  - Which provider is "primary" or "active"
  - Fallback/precedence order
  - Where in the app each provider is actually used

**Example Scenario:**
```
User configures:
  - Gemini (enabled)
  - Ollama (enabled)

Questions user might have:
❓ Which one will be used for job scraping?
❓ What if Gemini fails - does it fall back to Ollama?
❓ Can I choose which one is preferred?
❓ Why would I ever disable one?
```

**Current UI:**
- Provider Status section shows all providers with connected/disconnected status
- No indicator of which one is "primary"
- No visible fallback strategy

**Beads Task:** `clientats-yoi`

---

### 🟡 Issue #5: Visual Inconsistencies (Feature)
**Severity:** MEDIUM - Polish

**The Problem:**
Screenshot comparison reveals inconsistent styling:

| Element | Ollama | Gemini | Issue |
|---------|--------|--------|-------|
| Info box color | Orange warning | Blue info | Inconsistent |
| Help text formatting | Blue box | Blue box | OK, but different content |
| Spacing | Good | Good | Variable |
| Button colors | Orange primary | Orange primary | OK |
| Field widths | Variable | Variable | Jagged appearance |

**Visual Issues:**
1. Getting Started boxes have different colors and prominence
2. Form field alignment is off - dropdowns vs text inputs create misalignment
3. Enabled/Disabled badge position inconsistent
4. Help text sizing varies

**Beads Task:** `clientats-8go`

---

### 🟡 Issue #6: Poor Form Field Documentation (Feature)
**Severity:** MEDIUM - Confusing

**The Problem:**
- Field labels like "Default Model", "Vision Model", "Text Model" lack context
- Users don't understand:
  - WHEN each model is used
  - WHY they need to configure all three separately
  - What happens if one isn't configured

**Current Help Text:**
```
Default Model
├─ Placeholder: "e.g., gemini-2.0-flash"  ← Vague!
└─ Help: "Used for general text processing" ← Unclear!

Vision Model
├─ Placeholder: "e.g., gemini-2.0-flash"
└─ Help: "Model with vision capabilities for image processing" ← OK

Text Model
├─ Placeholder: "e.g., gemini-2.0-flash"
└─ Help: "Model for text-only tasks" ← Confusing - when is this used?
```

**Missing Information:**
- What's the relationship between these three?
- What happens if Vision Model isn't configured but user needs vision?
- Do all three need to be filled in?

**Beads Task:** `clientats-sbj`

---

### 🟡 Issue #7: Limited Provider Status Information (Feature)
**Severity:** MEDIUM - Actionability

**The Problem:**
Provider Status section is too minimal:

```
Current display:
┌─────────────────────────────────┐
│ ● Ollama (green dot)            │ [Disabled]
│   Not configured                │
└─────────────────────────────────┘

Missing information:
  ✗ When was it last tested?
  ✗ What errors occurred?
  ✗ What model is currently configured?
  ✗ Quick actions (edit, test without scrolling)
  ✗ Visual prominence of status
```

**User Experience:**
- Must scroll up to edit a provider
- No quick test button in status view
- Green dot is small and easy to miss
- Unclear what "Connected" vs "Configured" vs "Enabled" means

**Beads Task:** `clientats-4oq`

---

### 🟡 Issue #8: No Setup Guidance (Feature)
**Severity:** MEDIUM - Onboarding

**The Problem:**
- Page shows all 5 providers upfront - overwhelming for new users
- No guided setup flow
- Unclear what minimum setup is required
- No indication of local vs cloud providers
- No recommended starting point

**Ideal First-Time User Flow:**
```
1. User lands on page
2. Sees 2-3 recommended options (not all 5)
3. Selects "Get started with Gemini" or "Get started with Ollama"
4. Wizard walks through API key setup
5. Tests connection
6. Shows success message
7. Shows where to configure additional providers if needed
```

**Current Flow:**
```
1. User lands on page with Ollama tab selected
2. Sees all 5 tabs
3. Confused about which to pick
4. Tries Ollama first (if no Ollama installed, fails)
5. Tries Gemini (needs API key, doesn't know where to get it)
6. Gets frustrated
```

**Beads Task:** `clientats-sql`

---

## Summary of Beads Tasks Created

| ID | Type | Title | Priority |
|-------|------|-------|----------|
| `clientats-o53` | 🐛 Bug | Fix LLM provider inconsistency: OpenAI, Anthropic, Mistral forms shown but not implemented | P2 |
| `clientats-yfa` | ✨ Feature | Replace free-text model inputs with dropdowns for Gemini (and other API providers) | P2 |
| `clientats-5iu` | 📝 Task | Update Gemini default model to gemini-2.5-flash instead of gemini-2.0-flash | P2 |
| `clientats-yoi` | ✨ Feature | Add clarity on which LLM provider is active/primary for the application | P2 |
| `clientats-8go` | ✨ Feature | LLM settings page has visual inconsistencies and styling issues | P2 |
| `clientats-sbj` | ✨ Feature | Improve LLM provider form field descriptions and help text | P2 |
| `clientats-4oq` | ✨ Feature | Enhance Provider Status section with more actionable information | P2 |
| `clientats-sql` | ✨ Feature | Simplify LLM provider setup flow with better onboarding/guidance | P2 |

---

## Architecture Notes

### Current Implementation
**Database Schema:**
```
llm_settings table:
  - provider: string (ollama, gemini only) ← LIMITED!
  - api_key: binary (encrypted)
  - base_url: string (for Ollama)
  - default_model: string
  - vision_model: string
  - text_model: string
  - enabled: boolean
  - provider_status: string
  - user_id: foreign key
```

**Backend Support:**
- `LLMConfig` context: only implements Gemini and Ollama
- `test_connection()`: only :gemini and :ollama branches
- `validate_api_key()`: only :gemini and :ollama branches

**Frontend Components:**
- Renders forms for 5 providers (full UX defined)
- Tabs for: Ollama, Gemini, OpenAI, Anthropic, Mistral
- But only 2 actually work!

### Recommended Fix Path

**Option A: Complete the Implementation** (More work)
- Add OpenAI, Anthropic, Mistral support to backend
- Update schema to support all 5 providers
- Implement test_connection() for each
- Implement validate_api_key() for each

**Option B: Remove Incomplete Providers** (Simpler)
- Delete OpenAI, Anthropic, Mistral forms
- Remove tabs for incomplete providers
- Update schema to explicitly support only Ollama + Gemini
- Document why only 2 are supported
- Suggest users open issues if they want more

**Recommendation:** Option B for now (faster), with Option A as future enhancement

---

## Visual Style Reference

### What Works Well (Ollama):
- Blue info box with structured list
- "Discover Models" button provides dynamic dropdown population
- Clear step-by-step instructions
- Connection test integrated

### What Needs Improvement (Gemini):
- Free-text model inputs (should be dropdowns with known models)
- Could improve API key documentation
- Missing Gemini-specific model recommendations

---

## Next Steps

1. ✅ Beads tasks created with detailed requirements
2. 📋 Review priority and sequencing of improvements
3. 🔧 Decide: Complete implementation (Option A) vs Remove incomplete (Option B)
4. 🎨 Design consistent form styling
5. ✍️ Write detailed model lists for each provider dropdown
6. 🧪 Test provider selection flow with new users

---

*Analysis generated by Claude Code UX Review*
*Screenshots and code inspection completed: Dec 17, 2025*
