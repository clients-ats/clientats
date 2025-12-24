export const CoverLetterAutoSave = {
  mounted() {
    const jobApplicationId = this.el.dataset.jobApplicationId;
    const storageKey = `cover_letter_draft_${jobApplicationId}`;

    // Create and insert the draft indicator
    this.createDraftIndicator();

    // Try to restore draft on mount
    this.restoreDraft(storageKey);

    // Set up auto-save on input with debouncing
    let saveTimer = null;
    this.el.addEventListener('input', (e) => {
      clearTimeout(saveTimer);
      saveTimer = setTimeout(() => {
        this.saveDraft(storageKey, e.target.value);
      }, 2000); // Auto-save after 2 seconds of inactivity
    });

    // Store timer reference for cleanup
    this._saveTimer = saveTimer;
    this._storageKey = storageKey;

    // Listen for successful save events from the server
    this.handleEvent("draft_saved_to_server", () => {
      this.clearDraft(storageKey);
    });
  },

  updated() {
    // Hook can be updated by LiveView, maintain auto-save behavior
  },

  destroyed() {
    // Clean up timer on component destruction
    if (this._saveTimer) {
      clearTimeout(this._saveTimer);
    }
  },

  createDraftIndicator() {
    // Find the character count element
    const statsElement = this.el.closest('form').querySelector('.mt-2.text-sm.text-gray-600');

    if (statsElement && !document.getElementById('draft-indicator')) {
      const indicator = document.createElement('span');
      indicator.id = 'draft-indicator';
      indicator.className = 'ml-3 text-green-600 opacity-0 transition-opacity duration-300';
      indicator.innerHTML = '<svg class="w-4 h-4 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>Draft saved';
      statsElement.appendChild(indicator);
    }
  },

  restoreDraft(storageKey) {
    try {
      const draftData = localStorage.getItem(storageKey);

      if (draftData) {
        const { content, timestamp } = JSON.parse(draftData);
        const currentValue = this.el.value || '';

        // Only restore if current value is empty or whitespace
        // This prevents overwriting content that was already saved to the server
        if (currentValue.trim() === '' && content && content.trim() !== '') {
          this.el.value = content;

          // Trigger a change event so LiveView knows about the restored content
          const event = new Event('input', { bubbles: true });
          this.el.dispatchEvent(event);

          // Show a notification that draft was restored
          this.showDraftRestored(timestamp);
        }
      }
    } catch (error) {
      console.error('Error restoring draft:', error);
    }
  },

  saveDraft(storageKey, content) {
    try {
      const draftData = {
        content: content,
        timestamp: new Date().toISOString()
      };

      localStorage.setItem(storageKey, JSON.stringify(draftData));

      // Show the "Draft saved" indicator
      this.showDraftSavedIndicator();
    } catch (error) {
      console.error('Error saving draft:', error);
    }
  },

  clearDraft(storageKey) {
    try {
      localStorage.removeItem(storageKey);

      // Hide the draft indicator
      const indicator = document.getElementById('draft-indicator');
      if (indicator) {
        indicator.style.opacity = '0';
      }
    } catch (error) {
      console.error('Error clearing draft:', error);
    }
  },

  showDraftSavedIndicator() {
    const indicator = document.getElementById('draft-indicator');
    if (indicator) {
      // Show the indicator
      indicator.style.opacity = '1';

      // Fade it out after 2 seconds
      setTimeout(() => {
        indicator.style.opacity = '0.5';
      }, 2000);
    }
  },

  showDraftRestored(timestamp) {
    const statsElement = this.el.closest('form').querySelector('.mt-2.text-sm.text-gray-600');

    if (statsElement) {
      const date = new Date(timestamp);
      const timeAgo = this.getTimeAgo(date);

      const notification = document.createElement('div');
      notification.className = 'mt-2 text-sm text-blue-600';
      notification.innerHTML = `<svg class="w-4 h-4 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path></svg>Draft restored from ${timeAgo}`;

      statsElement.parentNode.insertBefore(notification, statsElement);

      // Remove notification after 5 seconds
      setTimeout(() => {
        notification.remove();
      }, 5000);
    }
  },

  getTimeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000);

    if (seconds < 60) return 'just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)} minutes ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} hours ago`;
    return `${Math.floor(seconds / 86400)} days ago`;
  }
};
