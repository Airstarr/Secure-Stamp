;; Product Recall Management Smart Contract
;; Handles automated recall triggers, notifications, and refund processing

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PRODUCT-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-RECALLED (err u102))
(define-constant ERR-NOT-RECALLED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-STAKEHOLDER (err u105))
(define-constant ERR-REFUND-ALREADY-PROCESSED (err u106))
(define-constant ERR-PRODUCT-NOT-SOLD (err u107))

;; Contract owner (manufacturer/recall authority)
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map products 
  { product-id: (string-ascii 50) }
  {
    batch-number: (string-ascii 50),
    serial-number: (string-ascii 50),
    manufacturer: principal,
    price: uint,
    is-recalled: bool,
    recall-reason: (string-ascii 200),
    recall-date: (optional uint)
  }
)

(define-map product-sales
  { product-id: (string-ascii 50), buyer: principal }
  {
    purchase-date: uint,
    purchase-price: uint,
    refund-processed: bool,
    seller: principal
  }
)

(define-map stakeholders
  { stakeholder: principal }
  {
    stakeholder-type: (string-ascii 20), ;; "distributor", "retailer", "consumer"
    notification-enabled: bool,
    contact-info: (string-ascii 100)
  }
)

(define-map recall-notifications
  { recall-counter: uint, stakeholder: principal }
  {
    notification-sent: bool,
    notification-date: uint,
    acknowledged: bool
  }
)

;; Contract balance for refunds
(define-data-var contract-balance uint u0)

;; Events
(define-data-var recall-counter uint u0)

;; Initialize product in the system
(define-public (register-product (product-id (string-ascii 50))
                                (batch-number (string-ascii 50))
                                (serial-number (string-ascii 50))
                                (manufacturer principal)
                                (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set products 
      { product-id: product-id }
      {
        batch-number: batch-number,
        serial-number: serial-number,
        manufacturer: manufacturer,
        price: price,
        is-recalled: false,
        recall-reason: "",
        recall-date: none
      }
    )
    (ok true)
  )
)

;; Register stakeholder for notifications
(define-public (register-stakeholder (stakeholder-type (string-ascii 20))
                                   (contact-info (string-ascii 100)))
  (begin
    (map-set stakeholders
      { stakeholder: tx-sender }
      {
        stakeholder-type: stakeholder-type,
        notification-enabled: true,
        contact-info: contact-info
      }
    )
    (ok true)
  )
)

;; Record a product sale
(define-public (record-sale (product-id (string-ascii 50))
                           (buyer principal)
                           (purchase-price uint))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND)))
    (asserts! (not (get is-recalled product)) ERR-ALREADY-RECALLED)
    (map-set product-sales
      { product-id: product-id, buyer: buyer }
      {
        purchase-date: stacks-block-height,
        purchase-price: purchase-price,
        refund-processed: false,
        seller: tx-sender
      }
    )
    (ok true)
  )
)

;; Trigger product recall
(define-public (trigger-recall (product-id (string-ascii 50))
                              (recall-reason (string-ascii 200)))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-recalled product)) ERR-ALREADY-RECALLED)
    
    ;; Update product status
    (map-set products
      { product-id: product-id }
      (merge product {
        is-recalled: true,
        recall-reason: recall-reason,
        recall-date: (some stacks-block-height)
      })
    )
    
    ;; Generate recall ID and increment counter
    (var-set recall-counter (+ (var-get recall-counter) u1))
    
    ;; Emit recall event (in real implementation, this would trigger notifications)
    (print {
      event: "product-recalled",
      product-id: product-id,
      recall-counter: (var-get recall-counter),
      reason: recall-reason,
      date: stacks-block-height
    })
    
    (ok (var-get recall-counter))
  )
)

;; Trigger batch recall (by batch number)
(define-public (trigger-batch-recall (batch-number (string-ascii 50))
                                    (recall-reason (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; In a real implementation, this would iterate through all products
    ;; with the matching batch number and recall them
    (var-set recall-counter (+ (var-get recall-counter) u1))
    
    (print {
      event: "batch-recalled",
      batch-number: batch-number,
      recall-counter: (var-get recall-counter),
      reason: recall-reason,
      date: stacks-block-height
    })
    
    (ok (var-get recall-counter))
  )
)

;; Process automatic refund for recalled product
(define-public (process-refund (product-id (string-ascii 50))
                              (buyer principal))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND))
        (sale (unwrap! (map-get? product-sales { product-id: product-id, buyer: buyer }) ERR-PRODUCT-NOT-SOLD)))
    
    (asserts! (get is-recalled product) ERR-NOT-RECALLED)
    (asserts! (not (get refund-processed sale)) ERR-REFUND-ALREADY-PROCESSED)
    (asserts! (>= (var-get contract-balance) (get purchase-price sale)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Mark refund as processed
    (map-set product-sales
      { product-id: product-id, buyer: buyer }
      (merge sale { refund-processed: true })
    )
    
    ;; Process refund (transfer STX to buyer)
    (try! (stx-transfer? (get purchase-price sale) (as-contract tx-sender) buyer))
    
    ;; Update contract balance
    (var-set contract-balance (- (var-get contract-balance) (get purchase-price sale)))
    
    (print {
      event: "refund-processed",
      product-id: product-id,
      buyer: buyer,
      amount: (get purchase-price sale),
      date: stacks-block-height
    })
    
    (ok true)
  )
)

;; Deposit funds for refunds
(define-public (deposit-refund-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok true)
  )
)

;; Check if product is recalled
(define-read-only (is-product-recalled (product-id (string-ascii 50)))
  (match (map-get? products { product-id: product-id })
    product (get is-recalled product)
    false
  )
)

;; Get product details
(define-read-only (get-product-info (product-id (string-ascii 50)))
  (map-get? products { product-id: product-id })
)

;; Get sale information
(define-read-only (get-sale-info (product-id (string-ascii 50)) (buyer principal))
  (map-get? product-sales { product-id: product-id, buyer: buyer })
)

;; Get stakeholder information
(define-read-only (get-stakeholder-info (stakeholder principal))
  (map-get? stakeholders { stakeholder: stakeholder })
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

;; Get current recall counter
(define-read-only (get-recall-counter)
  (var-get recall-counter)
)

;; Emergency halt all sales for a product
(define-public (emergency-halt-sales (product-id (string-ascii 50)))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set products
      { product-id: product-id }
      (merge product { is-recalled: true, recall-reason: "EMERGENCY HALT" })
    )
    
    (print {
      event: "emergency-halt",
      product-id: product-id,
      date: stacks-block-height
    })
    
    (ok true)
  )
)