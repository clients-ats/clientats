// Tracks time spent viewing a job detail page.
// Mount with phx-hook="DwellTracker" data-job-id={@job_interest.id}
// Reports dwell time in seconds when user navigates away.
const DwellTracker = {
  mounted() {
    this.startTime = Date.now()
    this.jobId = this.el.dataset.jobId
    this.reported = false

    // Report on page visibility change (tab switch, minimize)
    this.handleVisibility = () => {
      if (document.hidden && !this.reported) {
        this.reportDwell()
      }
    }
    document.addEventListener("visibilitychange", this.handleVisibility)
  },

  destroyed() {
    document.removeEventListener("visibilitychange", this.handleVisibility)
    if (!this.reported) {
      this.reportDwell()
    }
  },

  reportDwell() {
    const seconds = (Date.now() - this.startTime) / 1000
    if (seconds >= 1.0) {
      this.pushEvent("record_dwell", { job_id: this.jobId, seconds: Math.round(seconds) })
      this.reported = true
    }
  }
}

export default DwellTracker
