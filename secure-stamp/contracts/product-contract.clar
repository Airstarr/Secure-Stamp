
;; title: product-contract
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR_PRODUCT_EXISTS (err u100))
(define-constant ERR_PRODUCT_NOT_FOUND (err u101))
(define-constant ERR_INVALID_FIELD (err u102))
(define-constant ERR_CANNOT_UPDATE (err u103))

;; data vars
;;

;; data maps
;; Define the map to store product information
(define-map products
  { product-id: uint }
  {
    serial-number: (string-ascii 50),
    batch-number: (string-ascii 50),
    expiration-date: (string-ascii 10)
  }
)

;; public functions
;; Function to register a new product
(define-public (register-product (product-id uint) (serial-number (string-ascii 50)) (batch-number (string-ascii 50)) (expiration-date (string-ascii 10)))
  (if (is-some (map-get? products { product-id: product-id }))
    ERR_PRODUCT_EXISTS
    (ok (map-set products
      { product-id: product-id }
      {
        serial-number: serial-number,
        batch-number: batch-number,
        expiration-date: expiration-date
      }
    ))
  )
)

;; Function to update specific fields of a product's DPI
(define-public (update-product (product-id uint) (field (string-ascii 20)) (value (string-ascii 50)))
  (match (map-get? products { product-id: product-id })
    product 
      (if (is-eq field "serial-number")
        (ok (map-set products { product-id: product-id }
          (merge product { serial-number: value })))
        (if (is-eq field "batch-number")
          (ok (map-set products { product-id: product-id }
            (merge product { batch-number: value })))
          (if (is-eq field "expiration-date")
            (match (as-max-len? value u10)
              success (ok (map-set products { product-id: product-id }
                (merge product { expiration-date: success })))
              ERR_CANNOT_UPDATE)
            ERR_INVALID_FIELD)))
    ERR_PRODUCT_NOT_FOUND)
)

;; read only functions
;; Function to retrieve product details
(define-read-only (get-product (product-id uint))
  (match (map-get? products { product-id: product-id })
    product (ok {
      serial-number: (get serial-number product),
      batch-number: (get batch-number product),
      expiration-date: (get expiration-date product)
    })
    ERR_PRODUCT_NOT_FOUND
  )
)

;; Function to check if a product exists
(define-read-only (product-exists? (product-id uint))
  (is-some (map-get? products { product-id: product-id }))
)

;; private functions
;;

