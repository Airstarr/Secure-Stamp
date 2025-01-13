
;; title: SupplyChainContract
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant ERR_PRODUCT_NOT_FOUND (err u101))
(define-constant ERR_INVALID_TRANSACTION_TYPE (err u201))
(define-constant contract-owner tx-sender)
(define-constant product-contract (as-contract tx-sender))

;; data vars
;; Define a variable to store the ProductContract principal
(define-data-var product-contract-principal principal .ProductContract)

;; data maps
;; Define the map to store transaction history
(define-map transaction-history
  { product-id: uint }
  { transactions: (list 200 {
      transaction-type: (string-ascii 20),
      timestamp: uint
    })
  }
)

;; public functions
;; Function to record a transaction
(define-public (record-transaction (product-id uint) (transaction-type (string-ascii 20)) (timestamp uint))
  (let (
    (current-history (default-to { transactions: (list) } (map-get? transaction-history { product-id: product-id })))
    (new-transaction { transaction-type: transaction-type, timestamp: timestamp })
  )
    (if (or (is-eq transaction-type "produced") (is-eq transaction-type "shipped"))
      (ok (map-set transaction-history
        { product-id: product-id }
        { transactions: (unwrap! (as-max-len? (concat (get transactions current-history) (list new-transaction)) u200)
                                 ERR_INVALID_TRANSACTION_TYPE) }
      ))
      ERR_INVALID_TRANSACTION_TYPE
    )
  )
)

;; Function to update the ProductContract principal (only contract owner can call this)
(define-public (set-product-contract-principal (new-principal principal))
  (begin
    (asserts! (is-eq  tx-sender contract-owner) (err u403))
    (ok (var-set product-contract-principal new-principal))
  )
)


;; read only functions
;; Function to validate movement
(define-read-only (validate-movement (product-id uint))
  (match (map-get? transaction-history { product-id: product-id })
    history (let (
      (transactions (get transactions history))
      (last-transaction (unwrap! (element-at transactions (- (len transactions) u1)) false))
    )
      (and (> (len transactions) u0) (is-eq (get transaction-type last-transaction) "shipped"))
    )
    false
  )
)

;; Function to get transaction history
(define-read-only (get-transaction-history (product-id uint))
  (match (map-get? transaction-history { product-id: product-id })
    history (ok (get transactions history))
    ERR_PRODUCT_NOT_FOUND
  )
)

;; private functions
;;

