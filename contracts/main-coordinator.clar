;; Main Coordinator Module
;; Central coordination system that orchestrates all modules

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u600))
(define-constant ERR-INVALID-WORKFLOW (err u601))
(define-constant ERR-WORKFLOW-NOT-FOUND (err u602))

;; Data Variables
(define-data-var workflow-counter uint u0)
(define-data-var system-admin principal tx-sender)

;; Data Maps
(define-map stress-test-workflows
  { workflow-id: uint }
  {
    coordinator: principal,
    scenario-id: uint,
    test-id: uint,
    analysis-id: uint,
    plan-id: uint,
    workflow-status: (string-ascii 20),
    created-at: uint,
    completed-at: (optional uint),
    current-stage: (string-ascii 30)
  }
)

(define-map workflow-stages
  { workflow-id: uint, stage: (string-ascii 30) }
  {
    status: (string-ascii 20),
    started-at: uint,
    completed-at: (optional uint),
    notes: (string-ascii 500)
  }
)

;; Public Functions

;; Initialize complete stress test workflow
(define-public (initialize-workflow (coordinator principal))
  (let
    (
      (workflow-id (+ (var-get workflow-counter) u1))
      (coordinator-active (is-coordinator-active-internal coordinator))
    )
    (asserts! coordinator-active ERR-NOT-AUTHORIZED)

    (map-set stress-test-workflows
      { workflow-id: workflow-id }
      {
        coordinator: coordinator,
        scenario-id: u0,
        test-id: u0,
        analysis-id: u0,
        plan-id: u0,
        workflow-status: "initialized",
        created-at: block-height,
        completed-at: none,
        current-stage: "scenario-development"
      }
    )

    ;; Initialize first stage
    (map-set workflow-stages
      { workflow-id: workflow-id, stage: "scenario-development" }
      {
        status: "active",
        started-at: block-height,
        completed-at: none,
        notes: "Workflow initialized, ready for scenario development"
      }
    )

    (var-set workflow-counter workflow-id)
    (ok workflow-id)
  )
)

;; Progress workflow to next stage
(define-public (progress-workflow
  (workflow-id uint)
  (current-stage (string-ascii 30))
  (next-stage (string-ascii 30))
  (stage-data uint))
  (begin
    (asserts! (is-some (map-get? stress-test-workflows { workflow-id: workflow-id })) ERR-WORKFLOW-NOT-FOUND)

    (match (map-get? stress-test-workflows { workflow-id: workflow-id })
      workflow-data
      (begin
        ;; Complete current stage
        (match (map-get? workflow-stages { workflow-id: workflow-id, stage: current-stage })
          stage-data-current
          (map-set workflow-stages
            { workflow-id: workflow-id, stage: current-stage }
            (merge stage-data-current {
              status: "completed",
              completed-at: (some block-height)
            })
          )
          false
        )

        ;; Update workflow with stage data
        (map-set stress-test-workflows
          { workflow-id: workflow-id }
          (merge workflow-data {
            current-stage: next-stage,
            scenario-id: (if (is-eq current-stage "scenario-development") stage-data (get scenario-id workflow-data)),
            test-id: (if (is-eq current-stage "testing-execution") stage-data (get test-id workflow-data)),
            analysis-id: (if (is-eq current-stage "result-analysis") stage-data (get analysis-id workflow-data)),
            plan-id: (if (is-eq current-stage "action-planning") stage-data (get plan-id workflow-data))
          })
        )

        ;; Start next stage
        (map-set workflow-stages
          { workflow-id: workflow-id, stage: next-stage }
          {
            status: "active",
            started-at: block-height,
            completed-at: none,
            notes: "Stage started automatically"
          }
        )

        (ok true)
      )
      ERR-WORKFLOW-NOT-FOUND
    )
  )
)

;; Complete entire workflow
(define-public (complete-workflow (workflow-id uint))
  (begin
    (asserts! (is-some (map-get? stress-test-workflows { workflow-id: workflow-id })) ERR-WORKFLOW-NOT-FOUND)

    (match (map-get? stress-test-workflows { workflow-id: workflow-id })
      workflow-data
      (begin
        (map-set stress-test-workflows
          { workflow-id: workflow-id }
          (merge workflow-data {
            workflow-status: "completed",
            completed-at: (some block-height)
          })
        )

        ;; Complete final stage
        (match (map-get? workflow-stages { workflow-id: workflow-id, stage: (get current-stage workflow-data) })
          stage-data
          (map-set workflow-stages
            { workflow-id: workflow-id, stage: (get current-stage workflow-data) }
            (merge stage-data {
              status: "completed",
              completed-at: (some block-height),
              notes: "Workflow completed successfully"
            })
          )
          false
        )

        (ok true)
      )
      ERR-WORKFLOW-NOT-FOUND
    )
  )
)

;; Get workflow summary (internal data only)
(define-public (get-workflow-summary (workflow-id uint))
  (match (map-get? stress-test-workflows { workflow-id: workflow-id })
    workflow-data
    (ok {
      workflow: workflow-data,
      summary: "Workflow data retrieved successfully"
    })
    ERR-WORKFLOW-NOT-FOUND
  )
)

;; Read-only Functions

;; Get workflow information
(define-read-only (get-workflow (workflow-id uint))
  (map-get? stress-test-workflows { workflow-id: workflow-id })
)

;; Get workflow stage information
(define-read-only (get-workflow-stage (workflow-id uint) (stage (string-ascii 30)))
  (map-get? workflow-stages { workflow-id: workflow-id, stage: stage })
)

;; Get current workflow counter
(define-read-only (get-workflow-counter)
  (var-get workflow-counter)
)

;; Check workflow status
(define-read-only (get-workflow-status (workflow-id uint))
  (match (map-get? stress-test-workflows { workflow-id: workflow-id })
    workflow-data
    (some (get workflow-status workflow-data))
    none
  )
)

;; Get current stage of workflow
(define-read-only (get-current-stage (workflow-id uint))
  (match (map-get? stress-test-workflows { workflow-id: workflow-id })
    workflow-data
    (some (get current-stage workflow-data))
    none
  )
)

;; Calculate workflow progress percentage
(define-read-only (calculate-workflow-progress (workflow-id uint))
  (match (map-get? stress-test-workflows { workflow-id: workflow-id })
    workflow-data
    (let
      (
        (current-stage (get current-stage workflow-data))
      )
      (if (is-eq current-stage "scenario-development") u20
        (if (is-eq current-stage "testing-execution") u40
          (if (is-eq current-stage "result-analysis") u60
            (if (is-eq current-stage "action-planning") u80
              (if (is-eq (get workflow-status workflow-data) "completed") u100 u0)
            )
          )
        )
      )
    )
    u0
  )
)

;; Internal coordinator check
(define-read-only (is-coordinator-active-internal (coordinator principal))
  ;; For demo purposes, allow any coordinator
  true
)
