
;; title: counterfeit-reporter
;; version:
;; summary:
;; description:

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant reward-amount u100000) ;; in micro-STX (0.1 STX)

;; Define error codes
(define-constant err-unauthorized (err u100))
(define-constant err-already-reported (err u101))
(define-constant err-not-reported (err u102))
(define-constant err-already-verified (err u103))
(define-constant err-not-verified (err u104))
(define-constant err-already-claimed (err u105))
(define-constant err-insufficient-balance (err u106))

;; Define data maps
(define-map reports 
  { product-id: (string-ascii 64) }
  { reporter: principal, verified: bool, claimed: bool }
)

(define-map user-rewards
  { user: principal }
  { balance: uint }
)

;; Define public functions

;; Function to report a counterfeit product
(define-public (report-counterfeit (product-id (string-ascii 64)))
  (let ((existing-report (get reporter (map-get? reports { product-id: product-id }))))
    (if (is-some existing-report)
      err-already-reported
      (begin
        (map-set reports 
          { product-id: product-id }
          { reporter: tx-sender, verified: false, claimed: false }
        )
        (ok true)
      )
    )
  )
)

;; Function to verify a report (only contract owner can verify)
(define-public (verify-report (product-id (string-ascii 64)))
  (let ((report (map-get? reports { product-id: product-id })))
    (if (is-eq tx-sender contract-owner)
      (if (is-some report)
        (if (get verified (unwrap-panic report))
          err-already-verified
          (begin
            (map-set reports 
              { product-id: product-id }
              (merge (unwrap-panic report) { verified: true })
            )
            (ok true)
          )
        )
        err-not-reported
      )
      err-unauthorized
    )
  )
)

;; Function to claim a reward
(define-public (claim-reward (product-id (string-ascii 64)))
  (let (
    (report (map-get? reports { product-id: product-id }))
    (user-reward (default-to { balance: u0 } (map-get? user-rewards { user: tx-sender })))
  )
    (if (is-some report)
      (let ((unwrapped-report (unwrap-panic report)))
        (if (is-eq (get reporter unwrapped-report) tx-sender)
          (if (get verified unwrapped-report)
            (if (not (get claimed unwrapped-report))
              (begin
                (map-set reports 
                  { product-id: product-id }
                  (merge unwrapped-report { claimed: true })
                )
                (map-set user-rewards
                  { user: tx-sender }
                  { balance: (+ (get balance user-reward) reward-amount) }
                )
                (ok true)
              )
              err-already-claimed
            )
            err-not-verified
          )
          err-unauthorized
        )
      )
      err-not-reported
    )
  )
)

;; Function to withdraw rewards
(define-public (withdraw-rewards (amount uint))
  (let (
    (user-reward (default-to { balance: u0 } (map-get? user-rewards { user: tx-sender })))
    (current-balance (get balance user-reward))
  )
    (if (<= amount current-balance)
      (begin
        (map-set user-rewards
          { user: tx-sender }
          { balance: (- current-balance amount) }
        )
        (as-contract (stx-transfer? amount tx-sender (as-contract tx-sender)))
      )
      err-insufficient-balance
    )
  )
)

;; Function to add funds to the contract (only contract owner can add funds)
(define-public (add-funds (amount uint))
  (if (is-eq tx-sender contract-owner)
    (stx-transfer? amount tx-sender (as-contract tx-sender))
    err-unauthorized
  )
)

;; Read-only functions

;; Get the report status for a product
(define-read-only (get-report-status (product-id (string-ascii 64)))
  (map-get? reports { product-id: product-id })
)

;; Get the reward balance for a user
(define-read-only (get-reward-balance (user principal))
  (default-to { balance: u0 } (map-get? user-rewards { user: user }))
)

;; Get the contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)