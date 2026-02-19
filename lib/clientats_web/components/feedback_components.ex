defmodule ClientatsWeb.FeedbackComponents do
  @moduledoc """
  LiveView components for job feedback interactions.

  Provides thumbs up/down buttons, bookmark toggle, company block dialog,
  and 'why did you rate this?' modal.
  """

  use Phoenix.Component

  attr :job_interest_id, :integer, required: true
  attr :thumbs, :atom, default: nil, doc: "Current thumbs state: nil, :up, or :down"
  attr :bookmarked, :boolean, default: false

  def feedback_buttons(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <button
        phx-click="thumbs_up"
        phx-value-job-id={@job_interest_id}
        class={[
          "p-2 rounded-lg transition-colors",
          @thumbs == :up && "bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300",
          @thumbs != :up && "text-gray-400 hover:text-green-600 hover:bg-green-50 dark:hover:bg-green-950"
        ]}
        title="Good match"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5">
          <path d="M1 8.998a1 1 0 0 1 1-1h3v9H2a1 1 0 0 1-1-1v-7Zm5-1h3.22a.5.5 0 0 0 .478-.357l1.302-4.34A1.5 1.5 0 0 1 12.435 2.5h.065a.75.75 0 0 1 .75.75v3.747h3.249a1.5 1.5 0 0 1 1.476 1.763l-.98 5.5A1.5 1.5 0 0 1 15.52 15.998H6v-8Z" />
        </svg>
      </button>

      <button
        phx-click="thumbs_down"
        phx-value-job-id={@job_interest_id}
        class={[
          "p-2 rounded-lg transition-colors",
          @thumbs == :down && "bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300",
          @thumbs != :down && "text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950"
        ]}
        title="Not a match"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5">
          <path d="M19 11.002a1 1 0 0 1-1 1h-3v-9h3a1 1 0 0 1 1 1v7Zm-5 1h-3.22a.5.5 0 0 0-.478.357l-1.302 4.34a1.5 1.5 0 0 1-1.435.801h-.065a.75.75 0 0 1-.75-.75V13.003H3.501a1.5 1.5 0 0 1-1.476-1.763l.98-5.5a1.5 1.5 0 0 1 1.476-1.238H14v8Z" />
        </svg>
      </button>

      <button
        phx-click="toggle_bookmark"
        phx-value-job-id={@job_interest_id}
        class={[
          "p-2 rounded-lg transition-colors",
          @bookmarked && "bg-yellow-100 text-yellow-700 dark:bg-yellow-900 dark:text-yellow-300",
          !@bookmarked && "text-gray-400 hover:text-yellow-600 hover:bg-yellow-50 dark:hover:bg-yellow-950"
        ]}
        title={if @bookmarked, do: "Remove bookmark", else: "Bookmark"}
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5">
          <path fill-rule="evenodd" d="M10 2c-1.716 0-3.408.106-5.07.31C3.806 2.45 3 3.414 3 4.517V17.25a.75.75 0 0 0 1.075.676L10 15.082l5.925 2.844A.75.75 0 0 0 17 17.25V4.517c0-1.103-.806-2.068-1.93-2.207A41.403 41.403 0 0 0 10 2Z" clip-rule="evenodd" />
        </svg>
      </button>

      <button
        phx-click="block_company"
        phx-value-job-id={@job_interest_id}
        class="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950 transition-colors"
        title="Block this company"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5">
          <path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM8.28 7.22a.75.75 0 0 0-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 1 0 1.06 1.06L10 11.06l1.72 1.72a.75.75 0 1 0 1.06-1.06L11.06 10l1.72-1.72a.75.75 0 0 0-1.06-1.06L10 8.94 8.28 7.22Z" clip-rule="evenodd" />
        </svg>
      </button>
    </div>
    """
  end

  attr :show, :boolean, default: false

  def why_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      phx-click="dismiss_why"
    >
      <div
        class="bg-white dark:bg-gray-800 rounded-xl shadow-xl p-6 max-w-md w-full mx-4"
        phx-click-away="dismiss_why"
      >
        <h3 class="text-lg font-semibold mb-3 text-gray-900 dark:text-gray-100">
          Quick feedback
        </h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
          What made you rate this job the way you did? This helps improve your matches.
        </p>
        <form phx-submit="submit_why" class="space-y-3">
          <div class="flex flex-wrap gap-2">
            <button type="submit" name="reason" value="salary" class="px-3 py-1.5 text-sm rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700">
              Salary
            </button>
            <button type="submit" name="reason" value="skills" class="px-3 py-1.5 text-sm rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700">
              Skills match
            </button>
            <button type="submit" name="reason" value="company" class="px-3 py-1.5 text-sm rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700">
              Company
            </button>
            <button type="submit" name="reason" value="location" class="px-3 py-1.5 text-sm rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700">
              Location/Remote
            </button>
            <button type="submit" name="reason" value="seniority" class="px-3 py-1.5 text-sm rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700">
              Seniority level
            </button>
          </div>
          <div>
            <input
              type="text"
              name="reason_custom"
              placeholder="Or type your own..."
              class="w-full px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 dark:bg-gray-700"
            />
          </div>
          <div class="flex justify-end gap-2">
            <button type="button" phx-click="dismiss_why" class="px-3 py-1.5 text-sm text-gray-600 dark:text-gray-400">
              Skip
            </button>
            <button type="submit" name="reason" value="" class="px-3 py-1.5 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              Submit
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  attr :show, :boolean, default: false
  attr :company_name, :string, default: ""

  def block_company_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
    >
      <div class="bg-white dark:bg-gray-800 rounded-xl shadow-xl p-6 max-w-sm w-full mx-4">
        <h3 class="text-lg font-semibold mb-2 text-gray-900 dark:text-gray-100">
          Block company
        </h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
          Jobs from <strong><%= @company_name %></strong> will no longer appear in your results.
        </p>
        <form phx-submit="confirm_block_company" class="space-y-3">
          <input
            type="text"
            name="reason"
            placeholder="Reason (optional)"
            class="w-full px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 dark:bg-gray-700"
          />
          <div class="flex justify-end gap-2">
            <button type="button" phx-click="cancel_block" class="px-3 py-1.5 text-sm text-gray-600 dark:text-gray-400">
              Cancel
            </button>
            <button type="submit" class="px-3 py-1.5 text-sm bg-red-600 text-white rounded-lg hover:bg-red-700">
              Block
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
