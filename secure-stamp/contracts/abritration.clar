;; Decentralized Arbitration Smart Contract
;; Handles disputes for product authenticity, warranty claims, and supply chain issues

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-dispute-expired (err u105))
(define-constant err-insufficient-arbiters (err u106))
(define-constant err-invalid-amount (err u107))

;; Data Variables
(define-data-var next-dispute-id uint u1)
(define-data-var arbitration-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var min-arbiters uint u3)
(define-data-var dispute-duration uint u144) ;; ~24 hours in blocks

;; Dispute Types
(define-constant PRODUCT-AUTHENTICITY u1)
(define-constant WARRANTY-CLAIM u2)
(define-constant SUPPLY-CHAIN u3)

;; Dispute Status
(define-constant STATUS-PENDING u1)
(define-constant STATUS-ACTIVE u2)
(define-constant STATUS-RESOLVED u3)
(define-constant STATUS-EXPIRED u4)

;; Vote Types
(define-constant VOTE-FAVOR-CLAIMANT u1)
(define-constant VOTE-FAVOR-RESPONDENT u2)

;; Data Maps
(define-map arbiters principal 
  {
    reputation: uint,
    total-cases: uint,
    successful-cases: uint,
    stake: uint,
    active: bool
  })

(define-map disputes uint
  {
    claimant: principal,
    respondent: principal,
    dispute-type: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    evidence-hash: (string-ascii 64),
    amount-disputed: uint,
    status: uint,
    created-at: uint,
    expires-at: uint,
    assigned-arbiters: (list 10 principal),
    votes-claimant: uint,
    votes-respondent: uint,
    total-votes: uint,
    resolution: (optional uint)
  })

(define-map dispute-votes {dispute-id: uint, arbiter: principal} uint)

(define-map evidence uint
  {
    dispute-id: uint,
    submitter: principal,
    evidence-hash: (string-ascii 64),
    description: (string-ascii 200),
    timestamp: uint
  })

(define-data-var next-evidence-id uint u1)

;; Arbiter Management Functions

;; Register as an arbiter
(define-public (register-arbiter (stake-amount uint))
  (let ((arbiter tx-sender))
    (asserts! (>= stake-amount u500000) err-invalid-amount) ;; Minimum 0.5 STX stake
    (try! (stx-transfer? stake-amount arbiter (as-contract tx-sender)))
    (map-set arbiters arbiter
      {
        reputation: u100,
        total-cases: u0,
        successful-cases: u0,
        stake: stake-amount,
        active: true
      })
    (ok true)))

;; Update arbiter status
(define-public (update-arbiter-status (active bool))
  (let ((arbiter tx-sender))
    (match (map-get? arbiters arbiter)
      arbiter-data (begin
        (map-set arbiters arbiter (merge arbiter-data {active: active}))
        (ok true))
      err-not-found)))

;; Dispute Management Functions

;; Create a new dispute
(define-public (create-dispute 
  (respondent principal)
  (dispute-type uint)
  (title (string-ascii 100))
  (description (string-ascii 500))
  (evidence-hash (string-ascii 64))
  (amount-disputed uint))
  (let (
    (dispute-id (var-get next-dispute-id))
    (claimant tx-sender)
    (current-block stacks-block-height)
    (expires-at (+ current-block (var-get dispute-duration)))
  )
    ;; Transfer arbitration fee
    (try! (stx-transfer? (var-get arbitration-fee) claimant (as-contract tx-sender)))
    
    ;; Create dispute
    (map-set disputes dispute-id
      {
        claimant: claimant,
        respondent: respondent,
        dispute-type: dispute-type,
        title: title,
        description: description,
        evidence-hash: evidence-hash,
        amount-disputed: amount-disputed,
        status: STATUS-PENDING,
        created-at: current-block,
        expires-at: expires-at,
        assigned-arbiters: (list),
        votes-claimant: u0,
        votes-respondent: u0,
        total-votes: u0,
        resolution: none
      })
    
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)))

;; Assign arbiters to a dispute (called by contract owner or automated)
(define-public (assign-arbiters (dispute-id uint) (arbiter-list (list 10 principal)))
  (let ((dispute (unwrap! (map-get? disputes dispute-id) err-not-found)))
    (asserts! (is-eq (get status dispute) STATUS-PENDING) err-invalid-status)
    (asserts! (>= (len arbiter-list) (var-get min-arbiters)) err-insufficient-arbiters)
    
    ;; Verify all arbiters are active
    (asserts! (fold check-arbiter-active arbiter-list true) err-unauthorized)
    
    ;; Update dispute with assigned arbiters
    (map-set disputes dispute-id
      (merge dispute 
        {
          assigned-arbiters: arbiter-list,
          status: STATUS-ACTIVE
        }))
    (ok true)))

;; Helper function to check if arbiter is active
(define-private (check-arbiter-active (arbiter principal) (acc bool))
  (and acc
    (match (map-get? arbiters arbiter)
      arbiter-data (get active arbiter-data)
      false)))

;; Submit additional evidence
(define-public (submit-evidence 
  (dispute-id uint)
  (evidence-hash (string-ascii 64))
  (description (string-ascii 200)))
  (let (
    (evidence-id (var-get next-evidence-id))
    (dispute (unwrap! (map-get? disputes dispute-id) err-not-found))
    (submitter tx-sender)
  )
    (asserts! (or (is-eq submitter (get claimant dispute))
                  (is-eq submitter (get respondent dispute))) err-unauthorized)
    (asserts! (is-eq (get status dispute) STATUS-ACTIVE) err-invalid-status)
    
    (map-set evidence evidence-id
      {
        dispute-id: dispute-id,
        submitter: submitter,
        evidence-hash: evidence-hash,
        description: description,
        timestamp: stacks-block-height
      })
    
    (var-set next-evidence-id (+ evidence-id u1))
    (ok evidence-id)))

;; Arbiter voting function
(define-public (cast-vote (dispute-id uint) (vote uint))
  (let (
    (arbiter tx-sender)
    (dispute (unwrap! (map-get? disputes dispute-id) err-not-found))
  )
    (asserts! (is-eq (get status dispute) STATUS-ACTIVE) err-invalid-status)
    (asserts! (<= stacks-block-height (get expires-at dispute)) err-dispute-expired)
    (asserts! (is-some (index-of (get assigned-arbiters dispute) arbiter)) err-unauthorized)
    (asserts! (is-none (map-get? dispute-votes {dispute-id: dispute-id, arbiter: arbiter})) err-already-voted)
    (asserts! (or (is-eq vote VOTE-FAVOR-CLAIMANT) (is-eq vote VOTE-FAVOR-RESPONDENT)) err-invalid-status)
    
    ;; Record the vote
    (map-set dispute-votes {dispute-id: dispute-id, arbiter: arbiter} vote)
    
    ;; Update vote counts
    (let (
      (new-votes-claimant (if (is-eq vote VOTE-FAVOR-CLAIMANT) 
                            (+ (get votes-claimant dispute) u1)
                            (get votes-claimant dispute)))
      (new-votes-respondent (if (is-eq vote VOTE-FAVOR-RESPONDENT)
                              (+ (get votes-respondent dispute) u1)
                              (get votes-respondent dispute)))
      (new-total-votes (+ (get total-votes dispute) u1))
    )
      (map-set disputes dispute-id
        (merge dispute
          {
            votes-claimant: new-votes-claimant,
            votes-respondent: new-votes-respondent,
            total-votes: new-total-votes
          }))
      
      ;; Check if we have enough votes to resolve
      (if (>= new-total-votes (var-get min-arbiters))
        (resolve-dispute dispute-id)
        (ok u0)))))

;; Resolve dispute based on votes
(define-private (resolve-dispute (dispute-id uint))
  (let ((dispute (unwrap! (map-get? disputes dispute-id) err-not-found)))
    (let (
      (votes-claimant (get votes-claimant dispute))
      (votes-respondent (get votes-respondent dispute))
      (resolution (if (> votes-claimant votes-respondent) 
                    VOTE-FAVOR-CLAIMANT 
                    VOTE-FAVOR-RESPONDENT))
    )
      ;; Update dispute status
      (map-set disputes dispute-id
        (merge dispute
          {
            status: STATUS-RESOLVED,
            resolution: (some resolution)
          }))
      
      ;; Update arbiter reputations
      (try! (update-arbiter-reputations dispute-id resolution))
      
      ;; Execute resolution (transfer funds, etc.)
      (try! (execute-resolution dispute-id resolution))
      
      (ok resolution))))

;; Update arbiter reputations based on majority vote
(define-private (update-arbiter-reputations (dispute-id uint) (winning-vote uint))
  (let ((dispute (unwrap! (map-get? disputes dispute-id) err-not-found)))
    (begin
      (map update-single-arbiter-reputation (get assigned-arbiters dispute))
      (ok true))))

(define-private (update-single-arbiter-reputation (arbiter principal))
  (let (
    (current-dispute-id (- (var-get next-dispute-id) u1)) ;; Get the current dispute ID
    (dispute (unwrap-panic (map-get? disputes current-dispute-id)))
    (winning-vote (unwrap-panic (get resolution dispute)))
  )
    (match (map-get? arbiters arbiter)
      arbiter-data (let (
        (vote (map-get? dispute-votes {dispute-id: current-dispute-id, arbiter: arbiter}))
        (was-correct (match vote
          arbiter-vote (is-eq arbiter-vote winning-vote)
          false))
        (new-total-cases (+ (get total-cases arbiter-data) u1))
        (new-successful-cases (if was-correct 
                                (+ (get successful-cases arbiter-data) u1)
                                (get successful-cases arbiter-data)))
        (current-reputation (get reputation arbiter-data))
        (new-reputation (if was-correct
                          (if (> (+ current-reputation u10) u1000) u1000 (+ current-reputation u10))
                          (if (< current-reputation u5) u1 (- current-reputation u5))))
      )
        (map-set arbiters arbiter
          (merge arbiter-data
            {
              reputation: new-reputation,
              total-cases: new-total-cases,
              successful-cases: new-successful-cases
            })))
      true)))

;; Execute the resolution (placeholder for actual execution logic)
(define-private (execute-resolution (dispute-id uint) (resolution uint))
  (let ((dispute (unwrap! (map-get? disputes dispute-id) err-not-found)))
    ;; In a real implementation, this would handle:
    ;; - Transferring disputed amounts
    ;; - Updating product authenticity records
    ;; - Processing warranty claims
    ;; - Updating supply chain records
    (ok true)))

;; Administrative Functions

;; Update arbitration fee (owner only)
(define-public (set-arbitration-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set arbitration-fee new-fee)
    (ok true)))

;; Update minimum arbiters (owner only)
(define-public (set-min-arbiters (new-min uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= new-min u1) (<= new-min u10)) err-invalid-amount)
    (var-set min-arbiters new-min)
    (ok true)))

;; Read-only Functions

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id))

;; Get arbiter details
(define-read-only (get-arbiter (arbiter principal))
  (map-get? arbiters arbiter))

;; Get evidence details
(define-read-only (get-evidence (evidence-id uint))
  (map-get? evidence evidence-id))

;; Get arbiter vote for a dispute
(define-read-only (get-vote (dispute-id uint) (arbiter principal))
  (map-get? dispute-votes {dispute-id: dispute-id, arbiter: arbiter}))

;; Get contract settings
(define-read-only (get-settings)
  {
    arbitration-fee: (var-get arbitration-fee),
    min-arbiters: (var-get min-arbiters),
    dispute-duration: (var-get dispute-duration),
    next-dispute-id: (var-get next-dispute-id)
  })

;; Check if dispute has expired
(define-read-only (is-dispute-expired (dispute-id uint))
  (match (map-get? disputes dispute-id)
    dispute (> stacks-block-height (get expires-at dispute))
    false))

;; Get active arbiters (helper function)
(define-read-only (get-arbiter-reputation (arbiter principal))
  (match (map-get? arbiters arbiter)
    arbiter-data (some (get reputation arbiter-data))
    none))
