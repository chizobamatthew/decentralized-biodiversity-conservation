;; Conservation Impact Tracker Contract
;; Tracks conservation project impacts, measures habitat protection success,
;; calculates biodiversity improvements, distributes funding, and rewards contributions

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-PARAMS (err u203))
(define-constant ERR-INVALID-STATUS (err u204))
(define-constant ERR-INSUFFICIENT-FUNDS (err u205))
(define-constant ERR-PROJECT-ENDED (err u206))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-PROJECT-DURATION u5184) ;; ~36 days in blocks
(define-constant MAX-FUNDING-AMOUNT u1000000) ;; Maximum funding per project
(define-constant PLATFORM-FEE-BPS u300) ;; 3% platform fee

;; Conservation projects
(define-map conservation-projects
  { project-id: uint }
  {
    title: (string-ascii 200),
    organization: principal,
    description: (string-ascii 500),
    location-region: (string-ascii 100),
    project-type: (string-ascii 50), ;; "habitat-restoration", "species-protection", "research", "education"
    target-species: (list 10 uint),
    start-date: uint,
    end-date: uint,
    funding-goal: uint,
    funding-raised: uint,
    status: (string-ascii 20), ;; "active", "completed", "cancelled", "funded"
    impact-metrics: (string-ascii 300),
    verification-required: bool,
    verified: bool
  }
)

;; Project funding contributions
(define-map project-contributions
  { project-id: uint, contributor: principal }
  {
    amount: uint,
    contribution-date: uint,
    reward-tokens-earned: uint,
    impact-share: uint, ;; Percentage of project impact attributed to this contribution
    refunded: bool
  }
)

;; Impact measurements
(define-map impact-measurements
  { project-id: uint, measurement-id: uint }
  {
    metric-type: (string-ascii 50), ;; "habitat-area", "species-count", "population-increase", "threat-reduction"
    baseline-value: uint,
    current-value: uint,
    measurement-date: uint,
    improvement-percentage: uint,
    verification-status: (string-ascii 15), ;; "pending", "verified", "disputed"
    measurer: principal,
    documentation-hash: (buff 32)
  }
)

;; Conservation organizations
(define-map organizations
  { organization: principal }
  {
    name: (string-ascii 100),
    registration-number: (string-ascii 50),
    focus-areas: (list 10 (string-ascii 50)),
    verified: bool,
    reputation-score: uint,
    total-projects: uint,
    successful-projects: uint,
    total-funding-received: uint,
    registration-date: uint
  }
)

;; Funding pools for different conservation areas
(define-map funding-pools
  { pool-id: uint }
  {
    name: (string-ascii 100),
    focus-area: (string-ascii 50),
    total-funds: uint,
    allocated-funds: uint,
    admin: principal,
    criteria: (string-ascii 300),
    active: bool,
    created-date: uint
  }
)

;; Impact rewards for contributors
(define-map impact-rewards
  { reward-id: uint }
  {
    recipient: principal,
    project-id: uint,
    reward-type: (string-ascii 30), ;; "funding", "observation", "verification", "research"
    amount: uint,
    impact-generated: uint,
    reward-date: uint,
    claimed: bool
  }
)

;; Conservation achievements and milestones
(define-map conservation-milestones
  { milestone-id: uint }
  {
    project-id: uint,
    milestone-type: (string-ascii 50),
    target-value: uint,
    achieved-value: uint,
    deadline: uint,
    achieved-date: (optional uint),
    bonus-reward: uint,
    completed: bool
  }
)

;; Carbon offset tracking
(define-map carbon-offsets
  { offset-id: uint }
  {
    project-id: uint,
    co2-tons-sequestered: uint,
    verification-standard: (string-ascii 50),
    price-per-ton: uint,
    total-value: uint,
    vintage-year: uint,
    verified: bool,
    sold: bool
  }
)

;; Data variables
(define-data-var next-project-id uint u1)
(define-data-var next-pool-id uint u1)
(define-data-var next-reward-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var next-measurement-id uint u1)
(define-data-var next-offset-id uint u1)
(define-data-var total-conservation-funding uint u0)
(define-data-var total-impact-generated uint u0)
(define-data-var platform-fee-collected uint u0)

;; Organization registration
(define-public (register-organization
    (name (string-ascii 100))
    (registration-number (string-ascii 50))
    (focus-areas (list 10 (string-ascii 50)))
  )
  (begin
    (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
    (asserts! (is-none (map-get? organizations { organization: tx-sender })) ERR-ALREADY-EXISTS)
    
    (map-set organizations
      { organization: tx-sender }
      {
        name: name,
        registration-number: registration-number,
        focus-areas: focus-areas,
        verified: false,
        reputation-score: u100,
        total-projects: u0,
        successful-projects: u0,
        total-funding-received: u0,
        registration-date: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Create conservation project
(define-public (create-conservation-project
    (title (string-ascii 200))
    (description (string-ascii 500))
    (location-region (string-ascii 100))
    (project-type (string-ascii 50))
    (target-species (list 10 uint))
    (end-date uint)
    (funding-goal uint)
    (impact-metrics (string-ascii 300))
  )
  (let
    (
      (project-id (var-get next-project-id))
      (org-data (unwrap! (map-get? organizations { organization: tx-sender }) ERR-NOT-FOUND))
    )
    (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
    (asserts! (> end-date stacks-block-height) ERR-INVALID-PARAMS)
    (asserts! (> funding-goal u0) ERR-INVALID-PARAMS)
    (asserts! (<= funding-goal MAX-FUNDING-AMOUNT) ERR-INVALID-PARAMS)
    (asserts! (get verified org-data) ERR-NOT-AUTHORIZED)
    
    (map-set conservation-projects
      { project-id: project-id }
      {
        title: title,
        organization: tx-sender,
        description: description,
        location-region: location-region,
        project-type: project-type,
        target-species: target-species,
        start-date: stacks-block-height,
        end-date: end-date,
        funding-goal: funding-goal,
        funding-raised: u0,
        status: "active",
        impact-metrics: impact-metrics,
        verification-required: true,
        verified: false
      }
    )
    
    ;; Update organization stats
    (map-set organizations
      { organization: tx-sender }
      (merge org-data { total-projects: (+ (get total-projects org-data) u1) })
    )
    
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

;; Contribute funding to project
(define-public (contribute-to-project (project-id uint) (amount uint))
  (let
    (
      (project-data (unwrap! (map-get? conservation-projects { project-id: project-id }) ERR-NOT-FOUND))
      (existing-contribution (default-to
        { amount: u0, contribution-date: u0, reward-tokens-earned: u0, impact-share: u0, refunded: false }
        (map-get? project-contributions { project-id: project-id, contributor: tx-sender })
      ))
    )
    (asserts! (is-eq (get status project-data) "active") ERR-INVALID-STATUS)
    (asserts! (< stacks-block-height (get end-date project-data)) ERR-PROJECT-ENDED)
    (asserts! (> amount u0) ERR-INVALID-PARAMS)
    
    ;; Calculate platform fee
    (let
      (
        (platform-fee (/ (* amount PLATFORM-FEE-BPS) u10000))
        (net-contribution (- amount platform-fee))
        (new-total-raised (+ (get funding-raised project-data) net-contribution))
        (new-contribution-amount (+ (get amount existing-contribution) net-contribution))
      )
      
      ;; Update project funding
      (map-set conservation-projects
        { project-id: project-id }
        (merge project-data { funding-raised: new-total-raised })
      )
      
      ;; Update contribution record
      (map-set project-contributions
        { project-id: project-id, contributor: tx-sender }
        (merge existing-contribution {
          amount: new-contribution-amount,
          contribution-date: stacks-block-height,
          reward-tokens-earned: (+ (get reward-tokens-earned existing-contribution) (* net-contribution u10))
        })
      )
      
      ;; Update platform statistics
      (var-set total-conservation-funding (+ (var-get total-conservation-funding) net-contribution))
      (var-set platform-fee-collected (+ (var-get platform-fee-collected) platform-fee))
      
      ;; Check if project is fully funded
      (if (>= new-total-raised (get funding-goal project-data))
        (map-set conservation-projects
          { project-id: project-id }
          (merge project-data { status: "funded", funding-raised: new-total-raised })
        )
        true
      )
      
      (ok net-contribution)
    )
  )
)

;; Record impact measurement
(define-public (record-impact-measurement
    (project-id uint)
    (metric-type (string-ascii 50))
    (baseline-value uint)
    (current-value uint)
    (documentation-hash (buff 32))
  )
  (let
    (
      (measurement-id (var-get next-measurement-id))
      (project-data (unwrap! (map-get? conservation-projects { project-id: project-id }) ERR-NOT-FOUND))
      (improvement (if (> current-value baseline-value)
                     (/ (* (- current-value baseline-value) u100) baseline-value)
                     u0))
    )
    (asserts! (is-eq (get organization project-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq (get status project-data) "active") (is-eq (get status project-data) "funded")) ERR-INVALID-STATUS)
    
    (map-set impact-measurements
      { project-id: project-id, measurement-id: measurement-id }
      {
        metric-type: metric-type,
        baseline-value: baseline-value,
        current-value: current-value,
        measurement-date: stacks-block-height,
        improvement-percentage: improvement,
        verification-status: "pending",
        measurer: tx-sender,
        documentation-hash: documentation-hash
      }
    )
    
    (var-set next-measurement-id (+ measurement-id u1))
    (var-set total-impact-generated (+ (var-get total-impact-generated) improvement))
    (ok measurement-id)
  )
)

;; Distribute impact rewards
(define-public (distribute-impact-rewards (project-id uint))
  (let
    (
      (project-data (unwrap! (map-get? conservation-projects { project-id: project-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status project-data) "completed") ERR-INVALID-STATUS)
    (asserts! (get verified project-data) ERR-INVALID-STATUS)
    
    ;; Calculate total impact and distribute rewards proportionally
    (let
      (
        (total-impact (calculate-project-total-impact project-id))
        (reward-pool (/ (get funding-raised project-data) u10)) ;; 10% of funding as reward pool
      )
      ;; Simplified reward distribution - in production would iterate through contributors
      (ok reward-pool)
    )
  )
)

;; Create funding pool
(define-public (create-funding-pool
    (name (string-ascii 100))
    (focus-area (string-ascii 50))
    (initial-funds uint)
    (criteria (string-ascii 300))
  )
  (let
    (
      (pool-id (var-get next-pool-id))
    )
    (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
    (asserts! (> initial-funds u0) ERR-INVALID-PARAMS)
    
    (map-set funding-pools
      { pool-id: pool-id }
      {
        name: name,
        focus-area: focus-area,
        total-funds: initial-funds,
        allocated-funds: u0,
        admin: tx-sender,
        criteria: criteria,
        active: true,
        created-date: stacks-block-height
      }
    )
    
    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)
  )
)

;; Helper functions
(define-private (calculate-project-total-impact (project-id uint))
  ;; Simplified impact calculation - in production would aggregate all measurements
  u1000
)

;; Read-only functions
(define-read-only (get-conservation-project (project-id uint))
  (map-get? conservation-projects { project-id: project-id })
)

(define-read-only (get-organization (organization principal))
  (map-get? organizations { organization: organization })
)

(define-read-only (get-project-contribution (project-id uint) (contributor principal))
  (map-get? project-contributions { project-id: project-id, contributor: contributor })
)

(define-read-only (get-impact-measurement (project-id uint) (measurement-id uint))
  (map-get? impact-measurements { project-id: project-id, measurement-id: measurement-id })
)

(define-read-only (get-funding-pool (pool-id uint))
  (map-get? funding-pools { pool-id: pool-id })
)

(define-read-only (get-conservation-stats)
  {
    total-conservation-funding: (var-get total-conservation-funding),
    total-impact-generated: (var-get total-impact-generated),
    platform-fee-collected: (var-get platform-fee-collected),
    next-project-id: (var-get next-project-id),
    next-pool-id: (var-get next-pool-id)
  }
)

;; Admin functions
(define-public (verify-organization (organization principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (let
      (
        (org-data (unwrap! (map-get? organizations { organization: organization }) ERR-NOT-FOUND))
      )
      (map-set organizations
        { organization: organization }
        (merge org-data { verified: true })
      )
      (ok true)
    )
  )
)

(define-public (verify-project-impact (project-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (let
      (
        (project-data (unwrap! (map-get? conservation-projects { project-id: project-id }) ERR-NOT-FOUND))
      )
      (map-set conservation-projects
        { project-id: project-id }
        (merge project-data { verified: true })
      )
      (ok true)
    )
  )
)

;; title: conservation-impact-tracker
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

