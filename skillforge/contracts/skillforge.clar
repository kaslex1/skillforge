;; SkillForge - Decentralized Talent Marketplace
;; Smart contract for managing skilled work, rewards, and mediation

(define-constant admin tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INVALID-TASK (err u2))
(define-constant ERR-LOW-BALANCE (err u3))
(define-constant ERR-TASK-CLOSED (err u4))

;; Data structures
(define-map Tasks
    { task-id: uint }
    {
        requester: principal,
        provider: principal,
        reward: uint,
        scope: (string-ascii 256),
        phase: (string-ascii 20),
        initiated-at: uint,
        delivered-at: uint,
        mediator: (optional principal)
    }
)

(define-map ExpertiseScores
    { expert: principal }
    {
        review-count: uint,
        score-total: uint,
        deliveries: uint
    }
)

(define-data-var task-sequence uint u0)

;; Initialize new task
(define-public (forge-task (provider principal) (reward uint) (scope (string-ascii 256)))
    (let
        ((task-id (+ (var-get task-sequence) u1)))
        (if (>= (stx-get-balance tx-sender) reward)
            (begin
                (try! (stx-transfer? reward tx-sender (as-contract tx-sender)))
                (map-set Tasks
                    { task-id: task-id }
                    {
                        requester: tx-sender,
                        provider: provider,
                        reward: reward,
                        scope: scope,
                        phase: "active",
                        initiated-at: block-height,
                        delivered-at: u0,
                        mediator: none
                    }
                )
                (var-set task-sequence task-id)
                (ok task-id))
            ERR-LOW-BALANCE)))

;; Mark task complete and distribute reward
(define-public (finalize-task (task-id uint))
    (let ((task (unwrap! (map-get? Tasks { task-id: task-id }) ERR-INVALID-TASK)))
        (asserts! (is-eq (get phase task) "active") ERR-TASK-CLOSED)
        (asserts! (or (is-eq tx-sender (get requester task)) 
                     (is-eq tx-sender (get provider task)))
                 ERR-UNAUTHORIZED)
        (try! (as-contract (stx-transfer? (get reward task) tx-sender (get provider task))))
        (map-set Tasks
            { task-id: task-id }
            (merge task { 
                phase: "delivered",
                delivered-at: block-height
            })
        )
        (ok true)))

;; Score an expert
(define-public (score-expert (expert principal) (score uint))
    (let ((current-score (default-to 
            { review-count: u0, score-total: u0, deliveries: u0 }
            (map-get? ExpertiseScores { expert: expert }))))
        (asserts! (and (>= score u1) (<= score u5)) (err u5))
        (map-set ExpertiseScores
            { expert: expert }
            {
                review-count: (+ (get review-count current-score) u1),
                score-total: (+ (get score-total current-score) score),
                deliveries: (+ (get deliveries current-score) u1)
            }
        )
        (ok true)))

;; Start mediation
(define-public (request-mediation (task-id uint) (mediator principal))
    (let ((task (unwrap! (map-get? Tasks { task-id: task-id }) ERR-INVALID-TASK)))
        (asserts! (is-eq (get phase task) "active") ERR-TASK-CLOSED)
        (asserts! (or (is-eq tx-sender (get requester task)) 
                     (is-eq tx-sender (get provider task)))
                 ERR-UNAUTHORIZED)
        (map-set Tasks
            { task-id: task-id }
            (merge task { 
                phase: "mediation",
                mediator: (some mediator)
            })
        )
        (ok true)))

;; Conclude mediation
(define-public (conclude-mediation (task-id uint) (recipient principal))
    (let ((task (unwrap! (map-get? Tasks { task-id: task-id }) ERR-INVALID-TASK)))
        (asserts! (is-eq (get phase task) "mediation") ERR-INVALID-TASK)
        (asserts! (is-eq tx-sender (unwrap! (get mediator task) ERR-UNAUTHORIZED))
                 ERR-UNAUTHORIZED)
        (try! (as-contract (stx-transfer? (get reward task) tx-sender recipient)))
        (map-set Tasks
            { task-id: task-id }
            (merge task { 
                phase: "mediated",
                delivered-at: block-height
            })
        )
        (ok true)))

;; Read-only functions
(define-read-only (view-task (task-id uint))
    (map-get? Tasks { task-id: task-id }))

(define-read-only (view-expertise (expert principal))
    (let ((expertise (unwrap! (map-get? ExpertiseScores { expert: expert }) (err u6))))
        (ok {
            avg-score: (/ (get score-total expertise) (get review-count expertise)),
            total-reviews: (get review-count expertise),
            completed-tasks: (get deliveries expertise)
        })))