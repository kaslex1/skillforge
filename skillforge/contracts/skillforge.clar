;; SkillForge - Enhanced Decentralized Talent Marketplace
;; Contract for managing skilled work, rewards, and advanced features

(define-constant admin tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INVALID-TASK (err u2))
(define-constant ERR-LOW-BALANCE (err u3))
(define-constant ERR-TASK-CLOSED (err u4))
(define-constant ERR-INVALID-PHASE (err u5))
(define-constant ERR-TIMELOCK-ACTIVE (err u6))
(define-constant ERR-INVALID-REWARD (err u7))
(define-constant ERR-PHASE-LIMIT (err u8))
(define-constant ERR-INVALID-PROVIDER (err u9))
(define-constant ERR-INVALID-SCOPE (err u10))
(define-constant ERR-INVALID-DOMAIN (err u11))
(define-constant ERR-INVALID-TIMELINE (err u12))
(define-constant ERR-INVALID-TITLE (err u13))
(define-constant ERR-INVALID-TASK-ID (err u14))
(define-constant ERR-INVALID-PHASE-ID (err u15))
(define-constant ERR-INVALID-PROOF (err u16))
(define-constant LOCK-PERIOD u1440)
(define-constant PLATFORM-RATE u25)
(define-constant MIN-COLLATERAL u1000000)
(define-constant MAX-PHASES u10)
(define-constant MAX-TIMELINE u14400)

;; Data Structures
(define-map Tasks
    { task-id: uint }
    {
        requester: principal,
        provider: principal,
        total-reward: uint,
        remaining-reward: uint,
        scope: (string-ascii 256),
        domain: (string-ascii 64),
        phase: (string-ascii 20),
        initiated-at: uint,
        delivered-at: uint,
        timeline: uint,
        mediator: (optional principal),
        phases-total: uint,
        phases-completed: uint
    }
)

(define-map Phases
    { task-id: uint, phase-id: uint }
    {
        scope: (string-ascii 256),
        reward: uint,
        status: (string-ascii 20),
        timeline: uint
    }
)

(define-map ExpertiseScores
    { expert: principal }
    {
        review-count: uint,
        score-total: uint,
        tasks-completed: uint,
        mediations-won: uint,
        mediations-lost: uint
    }
)

(define-map ProviderCollateral
    { expert: principal }
    {
        amount: uint,
        locked-until: uint
    }
)

(define-map Domains
    { domain-id: uint }
    {
        title: (string-ascii 64),
        scope: (string-ascii 256),
        min-collateral: uint
    }
)

(define-map MediationProof
    { task-id: uint, party: principal }
    {
        proof-hash: (buff 32),
        timestamp: uint
    }
)

(define-data-var task-sequence uint u0)
(define-data-var domain-sequence uint u0)

;; Helper functions for validation
(define-private (is-valid-provider (provider principal))
    (is-some (map-get? ProviderCollateral { expert: provider })))

(define-private (is-valid-scope (scope (string-ascii 256)))
    (and 
        (not (is-eq scope ""))
        (<= (len scope) u256)))

(define-private (is-valid-domain (domain (string-ascii 64)))
    (and 
        (not (is-eq domain ""))
        (<= (len domain) u64)))

(define-private (is-valid-timeline (timeline uint))
    (and 
        (> timeline u0)
        (<= timeline MAX-TIMELINE)))

(define-private (is-valid-title (title (string-ascii 64)))
    (and 
        (not (is-eq title ""))
        (<= (len title) u64)))

(define-private (is-valid-task-id (task-id uint))
    (and
        (> task-id u0)
        (<= task-id (var-get task-sequence))))

(define-private (is-valid-phase-id (task-id uint) (phase-id uint))
    (match (map-get? Tasks { task-id: task-id })
        task (< phase-id (get phases-total task))
        false))

(define-private (is-valid-reward (reward uint))
    (> reward u0))

(define-private (is-valid-proof-hash (proof-hash (buff 32)))
    (not (is-eq proof-hash 0x0000000000000000000000000000000000000000000000000000000000000000)))

;; Collateral management
(define-public (lock-collateral (amount uint))
    (begin
        (asserts! (>= amount MIN-COLLATERAL) ERR-INVALID-REWARD)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set ProviderCollateral
            { expert: tx-sender }
            {
                amount: amount,
                locked-until: (+ block-height LOCK-PERIOD)
            }
        )
        (ok true)))

(define-public (release-collateral)
    (let ((collateral (unwrap! (map-get? ProviderCollateral { expert: tx-sender }) ERR-UNAUTHORIZED)))
        (asserts! (>= block-height (get locked-until collateral)) ERR-TIMELOCK-ACTIVE)
        (try! (as-contract (stx-transfer? (get amount collateral) tx-sender tx-sender)))
        (map-delete ProviderCollateral { expert: tx-sender })
        (ok true)))

;; Task creation
(define-public (forge-task 
    (provider principal) 
    (total-reward uint) 
    (scope (string-ascii 256))
    (domain (string-ascii 64))
    (timeline uint))
    
    (begin
        (asserts! (is-valid-provider provider) ERR-INVALID-PROVIDER)
        (asserts! (is-valid-scope scope) ERR-INVALID-SCOPE)
        (asserts! (is-valid-domain domain) ERR-INVALID-DOMAIN)
        (asserts! (is-valid-timeline timeline) ERR-INVALID-TIMELINE)
        (asserts! (is-valid-reward total-reward) ERR-INVALID-REWARD)
        
        (let ((task-id (+ (var-get task-sequence) u1))
              (platform-fee (/ (* total-reward PLATFORM-RATE) u1000)))
            
            (asserts! (>= (stx-get-balance tx-sender) (+ total-reward platform-fee)) 
                     ERR-LOW-BALANCE)
            
            (try! (stx-transfer? (+ total-reward platform-fee) 
                                tx-sender 
                                (as-contract tx-sender)))
            
            (map-set Tasks
                { task-id: task-id }
                {
                    requester: tx-sender,
                    provider: provider,
                    total-reward: total-reward,
                    remaining-reward: total-reward,
                    scope: scope,
                    domain: domain,
                    phase: "active",
                    initiated-at: block-height,
                    delivered-at: u0,
                    timeline: (+ block-height timeline),
                    mediator: none,
                    phases-total: u0,
                    phases-completed: u0
                }
            )
            
            (var-set task-sequence task-id)
            (ok task-id))))

;; Add phase
(define-public (add-phase 
    (task-id uint)
    (scope (string-ascii 256))
    (reward uint))
    
    (begin
        (asserts! (is-valid-task-id task-id) ERR-INVALID-TASK-ID)
        (asserts! (is-valid-scope scope) ERR-INVALID-SCOPE)
        (asserts! (is-valid-reward reward) ERR-INVALID-REWARD)
        
        (let ((task (unwrap! (map-get? Tasks { task-id: task-id }) ERR-INVALID-TASK)))
            (asserts! (is-eq tx-sender (get requester task)) ERR-UNAUTHORIZED)
            (asserts! (is-eq (get phase task) "active") ERR-TASK-CLOSED)
            (asserts! (< (get phases-total task) MAX-PHASES) ERR-PHASE-LIMIT)
            
            (map-set Phases
                { task-id: task-id, phase-id: (get phases-total task) }
                {
                    scope: scope,
                    reward: reward,
                    status: "active",
                    timeline: (+ block-height LOCK-PERIOD)
                }
            )
            
            (map-set Tasks
                { task-id: task-id }
                (merge task {
                    phases-total: (+ (get phases-total task) u1)
                }))
                
            (ok true))))

;; Complete phase
(define-public (complete-phase (task-id uint) (phase-id uint))
    (begin
        (asserts! (is-valid-task-id task-id) ERR-INVALID-TASK-ID)
        (asserts! (is-valid-phase-id task-id phase-id) ERR-INVALID-PHASE-ID)
        
        (let ((task (unwrap! (map-get? Tasks { task-id: task-id }) ERR-INVALID-TASK))
              (phase (unwrap! (map-get? Phases { task-id: task-id, phase-id: phase-id }) 
                                ERR-INVALID-PHASE)))
            
            (asserts! (is-eq (get status phase) "active") ERR-TASK-CLOSED)
            (asserts! (is-eq tx-sender (get requester task)) ERR-UNAUTHORIZED)
            
            (try! (as-contract (stx-transfer? (get reward phase) 
                                            tx-sender 
                                            (get provider task))))
            
            (map-set Phases
                { task-id: task-id, phase-id: phase-id }
                (merge phase { status: "completed" }))
            
            (if (is-eq (+ (get phases-completed task) u1) 
                      (get phases-total task))
                (map-set Tasks
                    { task-id: task-id }
                    (merge task {
                        phase: "completed",
                        delivered-at: block-height,
                        phases-completed: (+ (get phases-completed task) u1),
                        remaining-reward: (- (get remaining-reward task) (get reward phase))
                    }))
                (map-set Tasks
                    { task-id: task-id }
                    (merge task {
                        phases-completed: (+ (get phases-completed task) u1),
                        remaining-reward: (- (get remaining-reward task) (get reward phase))
                    })))
            
            (ok true))))

;; Mediation proof submission
(define-public (submit-mediation-proof (task-id uint) (proof-hash (buff 32)))
    (begin
        (asserts! (is-valid-task-id task-id) ERR-INVALID-TASK-ID)
        (asserts! (is-valid-proof-hash proof-hash) ERR-INVALID-PROOF)
        
        (let ((task (unwrap! (map-get? Tasks { task-id: task-id }) ERR-INVALID-TASK)))
            (asserts! (or (is-eq tx-sender (get requester task))
                         (is-eq tx-sender (get provider task)))
                     ERR-UNAUTHORIZED)
            (map-set MediationProof
                { task-id: task-id, party: tx-sender }
                {
                    proof-hash: proof-hash,
                    timestamp: block-height
                }
            )
            (ok true))))

;; Domain management
(define-public (create-domain 
    (title (string-ascii 64))
    (scope (string-ascii 256))
    (min-collateral uint))
    
    (begin
        (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
        (asserts! (is-valid-title title) ERR-INVALID-TITLE)
        (asserts! (is-valid-scope scope) ERR-INVALID-SCOPE)
        (asserts! (>= min-collateral MIN-COLLATERAL) ERR-INVALID-REWARD)
        
        (let ((domain-id (+ (var-get domain-sequence) u1)))
            (map-set Domains
                { domain-id: domain-id }
                {
                    title: title,
                    scope: scope,
                    min-collateral: min-collateral
                }
            )
            (var-set domain-sequence domain-id)
            (ok domain-id))))

;; Read-only functions
(define-read-only (view-task (task-id uint))
    (map-get? Tasks { task-id: task-id }))

(define-read-only (view-phase (task-id uint) (phase-id uint))
    (map-get? Phases { task-id: task-id, phase-id: phase-id }))

(define-read-only (view-expertise (expert principal))
    (map-get? ExpertiseScores { expert: expert }))

(define-read-only (view-provider-stats (provider principal))
    (let ((expertise (unwrap! (map-get? ExpertiseScores { expert: provider }) (err u8)))
          (collateral (map-get? ProviderCollateral { expert: provider })))
        (ok {
            expertise: expertise,
            collateral: collateral
        })))

(define-read-only (view-domain (domain-id uint))
    (map-get? Domains { domain-id: domain-id }))

(define-read-only (view-mediation-proof (task-id uint) (party principal))
    (map-get? MediationProof { task-id: task-id, party: party }))