import Sortable from 'sortablejs';

export const ProviderReorder = {
  mounted() {
    const sortable = new Sortable(this.el, {
      animation: 150,
      handle: '.drag-handle',
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',

      onEnd: (evt) => {
        // Get the new order of provider names
        const providerOrder = Array.from(this.el.children).map(
          child => child.dataset.provider
        );

        // Push to LiveView
        this.pushEvent("reorder_providers", { provider_order: providerOrder });
      }
    });

    // Store instance for cleanup
    this._sortable = sortable;
  },

  destroyed() {
    // Clean up SortableJS instance
    if (this._sortable) {
      this._sortable.destroy();
    }
  }
};
