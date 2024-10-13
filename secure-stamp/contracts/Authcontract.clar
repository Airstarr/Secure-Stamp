
;; title: Authcontract
;; version: 1.0
;; summary:  Authentication contract for product verification
;; description: This contract allows for product authentication and verification history tracking.

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
(define-map products
  {product-id: uint}
  {is-authentic: bool, product-info: (string-ascii 256), serial-number: (string-ascii 64)}
)

(define-map serial-to-product-id
  {serial-number: (string-ascii 64)}
  {product-id: uint}
)

(define-map verification-history
  {product-id: uint}
  {history: (list 50 {consumer-id: uint, timestamp: uint})}
)

;; public functions
;;
(define-public (verify-product (product-id uint))
  (match (map-get? products {product-id: product-id})
    product (ok {
      is-authentic: (get is-authentic product),
      product-info: (get product-info product),
      serial-number: (get serial-number product)
    })
    (err u0)
  )
)

;; update-verification-history function
(define-public (update-verification-history (product-id uint) (consumer-id uint) (timestamp uint))
  (let (
    (current-history (default-to (list) (get history (map-get? verification-history {product-id: product-id}))))
    (new-entry {consumer-id: consumer-id, timestamp: timestamp})
    (updated-history (unwrap-panic (as-max-len? (concat (list new-entry) current-history) u50)))
  )
    (map-set verification-history
      {product-id: product-id}
      {history: updated-history}
    )
    (ok true)
  )
)

;; Helper function to add a product (for testing and initialization)
(define-public (add-product (product-id uint) (is-authentic bool) (product-info (string-ascii 256)) (serial-number (string-ascii 64)))
  (begin
    (map-set products
      {product-id: product-id}
      {is-authentic: is-authentic, product-info: product-info, serial-number: serial-number}
    )
    (map-set serial-to-product-id
      {serial-number: serial-number}
      {product-id: product-id}
    )
    (ok true)
  )
)

;; verify-by-serial function
(define-public (verify-by-serial (serial-number (string-ascii 64)))
  (match (map-get? serial-to-product-id {serial-number: serial-number})
    product-id-entry (verify-product (get product-id product-id-entry))
    (err u0)
  )
)
;; read only functions
;; get-verification-history function
(define-read-only (get-verification-history (product-id uint))
  (ok (default-to (list) (get history (map-get? verification-history {product-id: product-id}))))
)
;; private functions
;;


;; verify-product function









