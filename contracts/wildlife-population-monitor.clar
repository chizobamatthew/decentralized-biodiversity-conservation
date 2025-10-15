;; Wildlife Population Monitor Contract
;; Monitors wildlife populations through citizen science data, tracks species distribution changes,
;; verifies observation accuracy, coordinates conservation efforts, and measures biodiversity trends

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PARAMS (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u105))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-REPUTATION-SCORE u50)
(define-constant MAX-SPECIES-NAME-LENGTH u100)
(define-constant MAX-LOCATION-LENGTH u200)
(define-constant OBSERVATION-VALIDITY-BLOCKS u8640) ;; ~60 days

;; Species registry
(define-map species-registry
  { species-id: uint }
  {
    scientific-name: (string-ascii 100),
    common-name: (string-ascii 100),
    conservation-status: (string-ascii 30), ;; "LC", "NT", "VU", "EN", "CR", "EW", "EX"
    habitat-type: (string-ascii 50),
    geographic-range: (string-ascii 200),
    population-trend: (string-ascii 20), ;; "increasing", "stable", "decreasing", "unknown"
    threat-level: uint, ;; 1-5 scale
    registered-by: principal,
    registration-date: uint,
    verified: bool
  }
)

;; Observation data
(define-map wildlife-observations
  { observation-id: uint }
  {
    observer: principal,
    species-id: uint,
    observation-date: uint,
    location-hash: (buff 32), ;; Hash of GPS coordinates for privacy
    location-region: (string-ascii 100),
    individual-count: uint,
    behavior-notes: (string-ascii 300),
    habitat-condition: uint, ;; 1-5 scale (5 = excellent)
    photo-hash: (optional (buff 32)),
    verification-status: (string-ascii 15), ;; "pending", "verified", "disputed", "invalid"
    verification-count: uint,
    quality-score: uint ;; 0-100 based on verification
  }
)

;; Observer profiles
(define-map observer-profiles
  { observer: principal }
  {
    username: (string-ascii 50),
    expertise-areas: (list 10 (string-ascii 50)),
    total-observations: uint,
    verified-observations: uint,
    reputation-score: uint,
    certification-level: (string-ascii 20), ;; "novice", "intermediate", "expert", "professional"
    join-date: uint,
    last-active: uint,
    contribution-score: uint
  }
)

;; Observation verification
(define-map observation-verifications
  { observation-id: uint, verifier: principal }
  {
    verification-date: uint,
    verification-type: (string-ascii 20), ;; "confirm", "dispute", "expert-review"
    confidence-level: uint, ;; 1-5 scale
    notes: (string-ascii 200),
    verifier-reputation: uint
  }
)

;; Population trend data
(define-map population-trends
  { species-id: uint, time-period: uint }
  {
    observation-count: uint,
    individual-count-total: uint,
    unique-locations: uint,
    average-habitat-condition: uint,
    trend-direction: (string-ascii 15), ;; "increasing", "stable", "decreasing"
    confidence-interval: uint,
    data-quality: uint ;; 0-100
  }
)

;; Conservation areas
(define-map conservation-areas
  { area-id: uint }
  {
    name: (string-ascii 100),
    manager: principal,
    location-hash: (buff 32),
    size-hectares: uint,
    protection-level: (string-ascii 30), ;; "full-protection", "partial-protection", "sustainable-use"
    established-date: uint,
    target-species: (list 20 uint),
    biodiversity-index: uint, ;; 0-100
    monitoring-frequency: uint,
    active: bool
  }
)

;; Research projects
(define-map research-projects
  { project-id: uint }
  {
    title: (string-ascii 200),
    principal-investigator: principal,
    focus-species: (list 10 uint),
    study-areas: (list 5 uint), ;; Conservation area IDs
    start-date: uint,
    end-date: uint,
    objectives: (string-ascii 500),
    methodology: (string-ascii 300),
    status: (string-ascii 20), ;; "active", "completed", "paused", "cancelled"
    participant-count: uint,
    funding-amount: uint
  }
)

;; Data variables
(define-data-var next-species-id uint u1)
(define-data-var next-observation-id uint u1)
(define-data-var next-area-id uint u1)
(define-data-var next-project-id uint u1)
(define-data-var total-observations uint u0)
(define-data-var total-observers uint u0)
(define-data-var total-species-monitored uint u0)
(define-data-var platform-reputation-threshold uint u50)

;; Species registration
(define-public (register-species
    (scientific-name (string-ascii 100))
    (common-name (string-ascii 100))
    (conservation-status (string-ascii 30))
    (habitat-type (string-ascii 50))
    (geographic-range (string-ascii 200))
    (threat-level uint)
  )
  (let
    (
      (species-id (var-get next-species-id))
    )
    (asserts! (> (len scientific-name) u0) ERR-INVALID-PARAMS)
    (asserts! (> (len common-name) u0) ERR-INVALID-PARAMS)
    (asserts! (and (>= threat-level u1) (<= threat-level u5)) ERR-INVALID-PARAMS)
    
    (map-set species-registry
      { species-id: species-id }
      {
        scientific-name: scientific-name,
        common-name: common-name,
        conservation-status: conservation-status,
        habitat-type: habitat-type,
        geographic-range: geographic-range,
        population-trend: "unknown",
        threat-level: threat-level,
        registered-by: tx-sender,
        registration-date: stacks-block-height,
        verified: false
      }
    )
    
    (var-set next-species-id (+ species-id u1))
    (var-set total-species-monitored (+ (var-get total-species-monitored) u1))
    (ok species-id)
  )
)

;; Observer registration
(define-public (register-observer
    (username (string-ascii 50))
    (expertise-areas (list 10 (string-ascii 50)))
    (certification-level (string-ascii 20))
  )
  (begin
    (asserts! (> (len username) u0) ERR-INVALID-PARAMS)
    (asserts! (is-none (map-get? observer-profiles { observer: tx-sender })) ERR-ALREADY-EXISTS)
    
    (map-set observer-profiles
      { observer: tx-sender }
      {
        username: username,
        expertise-areas: expertise-areas,
        total-observations: u0,
        verified-observations: u0,
        reputation-score: u100,
        certification-level: certification-level,
        join-date: stacks-block-height,
        last-active: stacks-block-height,
        contribution-score: u0
      }
    )
    
    (var-set total-observers (+ (var-get total-observers) u1))
    (ok true)
  )
)

;; Submit wildlife observation
(define-public (submit-observation
    (species-id uint)
    (location-hash (buff 32))
    (location-region (string-ascii 100))
    (individual-count uint)
    (behavior-notes (string-ascii 300))
    (habitat-condition uint)
    (photo-hash (optional (buff 32)))
  )
  (let
    (
      (observation-id (var-get next-observation-id))
      (observer-data (unwrap! (map-get? observer-profiles { observer: tx-sender }) ERR-NOT-FOUND))
    )
    (asserts! (is-some (map-get? species-registry { species-id: species-id })) ERR-NOT-FOUND)
    (asserts! (> individual-count u0) ERR-INVALID-PARAMS)
    (asserts! (and (>= habitat-condition u1) (<= habitat-condition u5)) ERR-INVALID-PARAMS)
    (asserts! (>= (get reputation-score observer-data) MIN-REPUTATION-SCORE) ERR-INSUFFICIENT-REPUTATION)
    
    (map-set wildlife-observations
      { observation-id: observation-id }
      {
        observer: tx-sender,
        species-id: species-id,
        observation-date: stacks-block-height,
        location-hash: location-hash,
        location-region: location-region,
        individual-count: individual-count,
        behavior-notes: behavior-notes,
        habitat-condition: habitat-condition,
        photo-hash: photo-hash,
        verification-status: "pending",
        verification-count: u0,
        quality-score: u50
      }
    )
    
    ;; Update observer profile
    (map-set observer-profiles
      { observer: tx-sender }
      (merge observer-data {
        total-observations: (+ (get total-observations observer-data) u1),
        last-active: stacks-block-height,
        contribution-score: (+ (get contribution-score observer-data) u10)
      })
    )
    
    (var-set next-observation-id (+ observation-id u1))
    (var-set total-observations (+ (var-get total-observations) u1))
    (ok observation-id)
  )
)

;; Verify observation
(define-public (verify-observation
    (observation-id uint)
    (verification-type (string-ascii 20))
    (confidence-level uint)
    (notes (string-ascii 200))
  )
  (let
    (
      (observation-data (unwrap! (map-get? wildlife-observations { observation-id: observation-id }) ERR-NOT-FOUND))
      (verifier-data (unwrap! (map-get? observer-profiles { observer: tx-sender }) ERR-NOT-FOUND))
    )
    (asserts! (not (is-eq (get observer observation-data) tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get reputation-score verifier-data) MIN-REPUTATION-SCORE) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (and (>= confidence-level u1) (<= confidence-level u5)) ERR-INVALID-PARAMS)
    (asserts! (is-none (map-get? observation-verifications { observation-id: observation-id, verifier: tx-sender })) ERR-ALREADY-EXISTS)
    
    (map-set observation-verifications
      { observation-id: observation-id, verifier: tx-sender }
      {
        verification-date: stacks-block-height,
        verification-type: verification-type,
        confidence-level: confidence-level,
        notes: notes,
        verifier-reputation: (get reputation-score verifier-data)
      }
    )
    
    ;; Update observation verification count and quality score
    (let
      (
        (new-verification-count (+ (get verification-count observation-data) u1))
        (quality-bonus (if (is-eq verification-type "confirm") u10 u0))
        (new-quality-score (if (<= (+ (get quality-score observation-data) quality-bonus) u100)
                             (+ (get quality-score observation-data) quality-bonus)
                             u100))
        (new-status (if (>= new-verification-count u3) "verified" "pending"))
      )
      (map-set wildlife-observations
        { observation-id: observation-id }
        (merge observation-data {
          verification-count: new-verification-count,
          quality-score: new-quality-score,
          verification-status: new-status
        })
      )
      
      ;; Update observer reputation if confirmed
      (if (is-eq verification-type "confirm")
        (begin
          (let
            (
              (original-observer (get observer observation-data))
              (original-observer-data (unwrap! (map-get? observer-profiles { observer: original-observer }) ERR-NOT-FOUND))
            )
            (map-set observer-profiles
              { observer: original-observer }
              (merge original-observer-data {
                verified-observations: (+ (get verified-observations original-observer-data) u1),
                reputation-score: (if (<= (+ (get reputation-score original-observer-data) u5) u100)
                                    (+ (get reputation-score original-observer-data) u5)
                                    u100)
              })
            )
          )
          true
        )
        true
      )
    )
    
    (ok true)
  )
)

;; Update population trends
(define-public (update-population-trend
    (species-id uint)
    (time-period uint)
    (trend-direction (string-ascii 15))
    (confidence-interval uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? species-registry { species-id: species-id })) ERR-NOT-FOUND)
    (asserts! (<= confidence-interval u100) ERR-INVALID-PARAMS)
    
    ;; Calculate trend data from observations
    (let
      (
        (trend-data (calculate-population-trend species-id time-period))
      )
      (map-set population-trends
        { species-id: species-id, time-period: time-period }
        {
          observation-count: (get observation-count trend-data),
          individual-count-total: (get individual-count-total trend-data),
          unique-locations: (get unique-locations trend-data),
          average-habitat-condition: (get average-habitat-condition trend-data),
          trend-direction: trend-direction,
          confidence-interval: confidence-interval,
          data-quality: (get data-quality trend-data)
        }
      )
      
      ;; Update species population trend
      (let
        (
          (species-data (unwrap-panic (map-get? species-registry { species-id: species-id })))
        )
        (map-set species-registry
          { species-id: species-id }
          (merge species-data { population-trend: trend-direction })
        )
      )
      
      (ok true)
    )
  )
)

;; Create conservation area
(define-public (create-conservation-area
    (name (string-ascii 100))
    (location-hash (buff 32))
    (size-hectares uint)
    (protection-level (string-ascii 30))
    (target-species (list 20 uint))
    (monitoring-frequency uint)
  )
  (let
    (
      (area-id (var-get next-area-id))
    )
    (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
    (asserts! (> size-hectares u0) ERR-INVALID-PARAMS)
    (asserts! (> monitoring-frequency u0) ERR-INVALID-PARAMS)
    
    (map-set conservation-areas
      { area-id: area-id }
      {
        name: name,
        manager: tx-sender,
        location-hash: location-hash,
        size-hectares: size-hectares,
        protection-level: protection-level,
        established-date: stacks-block-height,
        target-species: target-species,
        biodiversity-index: u50,
        monitoring-frequency: monitoring-frequency,
        active: true
      }
    )
    
    (var-set next-area-id (+ area-id u1))
    (ok area-id)
  )
)

;; Helper functions
(define-private (calculate-population-trend (species-id uint) (time-period uint))
  ;; Simplified trend calculation - in production would analyze historical data
  {
    observation-count: u10,
    individual-count-total: u100,
    unique-locations: u5,
    average-habitat-condition: u3,
    data-quality: u75
  }
)

;; Read-only functions
(define-read-only (get-species-info (species-id uint))
  (map-get? species-registry { species-id: species-id })
)

(define-read-only (get-observation (observation-id uint))
  (map-get? wildlife-observations { observation-id: observation-id })
)

(define-read-only (get-observer-profile (observer principal))
  (map-get? observer-profiles { observer: observer })
)

(define-read-only (get-population-trend (species-id uint) (time-period uint))
  (map-get? population-trends { species-id: species-id, time-period: time-period })
)

(define-read-only (get-conservation-area (area-id uint))
  (map-get? conservation-areas { area-id: area-id })
)

(define-read-only (get-observation-verification (observation-id uint) (verifier principal))
  (map-get? observation-verifications { observation-id: observation-id, verifier: verifier })
)

(define-read-only (get-platform-stats)
  {
    total-observations: (var-get total-observations),
    total-observers: (var-get total-observers),
    total-species-monitored: (var-get total-species-monitored),
    next-species-id: (var-get next-species-id),
    next-observation-id: (var-get next-observation-id)
  }
)

;; Admin functions
(define-public (verify-species (species-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (let
      (
        (species-data (unwrap! (map-get? species-registry { species-id: species-id }) ERR-NOT-FOUND))
      )
      (map-set species-registry
        { species-id: species-id }
        (merge species-data { verified: true })
      )
      (ok true)
    )
  )
)

(define-public (update-reputation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-threshold u100) ERR-INVALID-PARAMS)
    (var-set platform-reputation-threshold new-threshold)
    (ok new-threshold)
  )
)

;; title: wildlife-population-monitor
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

