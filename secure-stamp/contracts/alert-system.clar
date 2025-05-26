;; title: alert-system
;; version: 1.0
;; summary: Alert System for Unauthorized Modifications or Tampering

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_STAKEHOLDERS u10)
(define-constant MAX_ALERTS u100)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PRODUCT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STAKEHOLDER (err u102))
(define-constant ERR-MAX-STAKEHOLDERS-REACHED (err u103))
(define-constant ERR-MAX-ALERTS-REACHED (err u104))
(define-constant ERR-INVALID-ALERT-TYPE (err u105))

;; Alert types
(define-constant ALERT-TYPES 
  {
    data-mismatch: "DATA_MISMATCH",
    unauthorized-modification: "UNAUTHORIZED_MODIFICATION",
    suspicious-activity: "SUSPICIOUS_ACTIVITY"
  }
)

;; Data variables
(define-data-var stakeholder-count uint u0)

;; Data structures
(define-map products 
  { product-id: (string-ascii 64) }
  {
    dpi: (string-ascii 128),
    serial-number: (string-ascii 64),
    batch-details: (string-ascii 256),
    last-verified: uint
  }
)

(define-map stakeholders
  principal
  { role: (string-ascii 20) }
)

(define-map alerts
  { product-id: (string-ascii 64) }
  (list 100 {
    timestamp: uint,
    alert-type: (string-ascii 32),
    details: (string-ascii 256),
    reported-by: principal
  })
)

;; Private functions
(define-private (is-authorized)
  (is-some (map-get? stakeholders tx-sender))
)

(define-private (product-exists (product-id (string-ascii 64)))
  (is-some (map-get? products { product-id: product-id }))
)

(define-private (add-alert 
  (product-id (string-ascii 64)) 
  (alert-type (string-ascii 32)) 
  (details (string-ascii 256)))
  (let
    ((current-alerts (default-to (list) (map-get? alerts { product-id: product-id }))))
    (begin
      (asserts! (< (len current-alerts) MAX_ALERTS) ERR-MAX-ALERTS-REACHED)
      (ok (as-max-len? 
        (append current-alerts {
          timestamp: block-height,
          alert-type: alert-type,
          details: details,
          reported-by: tx-sender
        })
        u100)
      )
    )
  )
)

;; Public functions
(define-public (register-stakeholder 
  (stakeholder principal) 
  (role (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (< (var-get stakeholder-count) MAX_STAKEHOLDERS) ERR-MAX-STAKEHOLDERS-REACHED)
    (var-set stakeholder-count (+ (var-get stakeholder-count) u1))
    (map-set stakeholders stakeholder { role: role })
    (ok true)
  )
)

(define-public (register-product 
  (product-id (string-ascii 64))
  (dpi (string-ascii 128))
  (serial-number (string-ascii 64))
  (batch-details (string-ascii 256)))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (not (product-exists product-id)) ERR-PRODUCT-NOT-FOUND)
    (map-set products { product-id: product-id }
      {
        dpi: dpi,
        serial-number: serial-number,
        batch-details: batch-details,
        last-verified: block-height
      }
    )
    (ok true)
  )
)

(define-public (verify-product-data
  (product-id (string-ascii 64))
  (dpi (string-ascii 128))
  (serial-number (string-ascii 64))
  (batch-details (string-ascii 256)))
  (let
    ((stored-product (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND)))
    (begin
      (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
      (ok (if (and
        (is-eq (get dpi stored-product) dpi)
        (is-eq (get serial-number stored-product) serial-number)
        (is-eq (get batch-details stored-product) batch-details))
        (ok (map-set products { product-id: product-id }
          (merge stored-product { last-verified: block-height })))
        (begin
          (try! (add-alert product-id
            (get data-mismatch ALERT-TYPES)
            "Mismatch detected in product data"))
          (err ERR-INVALID-STAKEHOLDER)
        )
      ))
    )
  )
)

(define-public (report-suspicious-activity
  (product-id (string-ascii 64))
  (details (string-ascii 256)))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (add-alert product-id (get suspicious-activity ALERT-TYPES) details)
  )
)

;; Read-only functions
(define-read-only (get-product-alerts (product-id (string-ascii 64)))
  (begin
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (ok (default-to (list) (map-get? alerts { product-id: product-id })))
  )
)

(define-read-only (get-product-data (product-id (string-ascii 64)))
  (begin
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (ok (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND))
  )
)

(define-read-only (is-stakeholder (address principal))
  (is-some (map-get? stakeholders address))
)