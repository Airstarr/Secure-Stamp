;; Verification History Smart Contract

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_HISTORY_ENTRIES u100)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PRODUCT-NOT-FOUND (err u101))
(define-constant ERR-HISTORY-LIMIT-REACHED (err u102))
(define-constant ERR-INVALID-ENTRY (err u103))

;; Data structures
(define-map products 
  { product-id: (string-ascii 64) }
  { exists: bool }
)

(define-map product-history
  { product-id: (string-ascii 64) }
  (list 100 {
    timestamp: uint,
    action: (string-ascii 64),
    location: (string-ascii 128),
    handler: principal,
    details: (string-ascii 256)
  })
)

(define-map authorized-parties principal bool)

;; Private functions
(define-private (is-authorized)
  (default-to false (map-get? authorized-parties tx-sender))
)

(define-private (product-exists (product-id (string-ascii 64)))
  (default-to false (get exists (map-get? products { product-id: product-id })))
)

;; Public functions
(define-public (add-authorized-party (party principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-parties party true))
  )
)

(define-public (remove-authorized-party (party principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-parties party))
  )
)

(define-public (register-product (product-id (string-ascii 64)))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (not (product-exists product-id)) ERR-INVALID-ENTRY)
    (map-set products { product-id: product-id } { exists: true })
    (ok true)
  )
)

(define-public (add-history-entry
  (product-id (string-ascii 64))
  (action (string-ascii 64))
  (location (string-ascii 128))
  (details (string-ascii 256)))
  (let
    ((current-history (default-to (list) (map-get? product-history { product-id: product-id }))))
    (begin
      (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
      (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
      (asserts! (< (len current-history) MAX_HISTORY_ENTRIES) ERR-HISTORY-LIMIT-REACHED)
      (ok (map-set product-history
        { product-id: product-id }
        (unwrap! (as-max-len? (append current-history
          {
            timestamp: block-height,
            action: action,
            location: location,
            handler: tx-sender,
            details: details
          }
        ) u100) (err u222))
      ))
    )
  )
)

;; Read-only functions
(define-read-only (get-product-history (product-id (string-ascii 64)))
  (begin
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (ok (default-to (list) (map-get? product-history { product-id: product-id })))
  )
)

(define-read-only (get-product-history-entry (product-id (string-ascii 64)) (index uint))
  (let
    ((history (default-to (list) (map-get? product-history { product-id: product-id }))))
    (begin
      (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
      (ok (element-at history index))
    )
  )
)

(define-read-only (get-product-history-length (product-id (string-ascii 64)))
  (begin
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (ok (len (default-to (list) (map-get? product-history { product-id: product-id }))))
  )
)