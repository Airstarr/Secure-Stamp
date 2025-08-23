;; Consumer and Retailer Loyalty Program Smart Contract
;; Handles loyalty rewards, gamification, and referral programs for verified product purchases

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-product (err u104))
(define-constant err-invalid-referral (err u105))

;; Data Variables
(define-data-var points-per-purchase uint u10)
(define-data-var referral-bonus uint u50)
(define-data-var min-redemption-points uint u100)

;; Data Maps
(define-map user-profiles
  { user: principal }
  {
    total-points: uint,
    total-purchases: uint,
    referrals-made: uint,
    badges: (list 10 (string-ascii 32))
  }
)

(define-map product-registry
  { product-id: (string-ascii 64) }
  {
    verified: bool,
    manufacturer: principal,
    price: uint,
    category: (string-ascii 32)
  }
)

(define-map purchase-history
  { user: principal, purchase-id: uint }
  {
    product-id: (string-ascii 64),
    timestamp: uint,
    points-earned: uint,
    verified: bool
  }
)

(define-map referral-relationships
  { referrer: principal, referee: principal }
  {
    active: bool,
    rewards-earned: uint,
    timestamp: uint
  }
)

(define-map badge-definitions
  { badge-name: (string-ascii 32) }
  {
    description: (string-ascii 128),
    requirement: uint,
    reward-points: uint
  }
)

(define-map user-achievements
  { user: principal, badge: (string-ascii 32) }
  {
    earned: bool,
    timestamp: uint
  }
)

;; Data Variables for counters
(define-data-var next-purchase-id uint u1)

;; Public Functions

;; Initialize user profile
(define-public (create-user-profile)
  (let ((user tx-sender))
    (asserts! (is-none (map-get? user-profiles { user: user })) err-already-exists)
    (ok (map-set user-profiles
      { user: user }
      {
        total-points: u0,
        total-purchases: u0,
        referrals-made: u0,
        badges: (list)
      }
    ))
  )
)

;; Register a verified product (owner only)
(define-public (register-product (product-id (string-ascii 64)) (manufacturer principal) (price uint) (category (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set product-registry
      { product-id: product-id }
      {
        verified: true,
        manufacturer: manufacturer,
        price: price,
        category: category
      }
    ))
  )
)

;; Record a purchase and award loyalty points
(define-public (record-purchase (product-id (string-ascii 64)) (referrer (optional principal)))
  (let (
    (user tx-sender)
    (purchase-id (var-get next-purchase-id))
    (product (unwrap! (map-get? product-registry { product-id: product-id }) err-invalid-product))
    (user-profile (default-to 
      { total-points: u0, total-purchases: u0, referrals-made: u0, badges: (list) }
      (map-get? user-profiles { user: user })
    ))
    (points-to-award (var-get points-per-purchase))
  )
    (asserts! (get verified product) err-invalid-product)
    
    ;; Update purchase counter
    (var-set next-purchase-id (+ purchase-id u1))
    
    ;; Record the purchase
    (map-set purchase-history
      { user: user, purchase-id: purchase-id }
      {
        product-id: product-id,
        timestamp: stacks-block-height,
        points-earned: points-to-award,
        verified: true
      }
    )
    
    ;; Update user profile with points and purchase count
    (map-set user-profiles
      { user: user }
      {
        total-points: (+ (get total-points user-profile) points-to-award),
        total-purchases: (+ (get total-purchases user-profile) u1),
        referrals-made: (get referrals-made user-profile),
        badges: (get badges user-profile)
      }
    )
    

    ;; Check for badge achievements
    (try! (check-and-award-badges user))
    
    (ok purchase-id)
  )
)

;; Process referral rewards
(define-private (process-referral (referrer principal) (referee principal))
  (let (
    (referrer-profile (default-to 
      { total-points: u0, total-purchases: u0, referrals-made: u0, badges: (list) }
      (map-get? user-profiles { user: referrer })
    ))
    (bonus-points (var-get referral-bonus))
  )
    ;; Record referral relationship
    (map-set referral-relationships
      { referrer: referrer, referee: referee }
      {
        active: true,
        rewards-earned: bonus-points,
        timestamp: stacks-block-height
      }
    )
    
    ;; Award bonus points to referrer
    (map-set user-profiles
      { user: referrer }
      {
        total-points: (+ (get total-points referrer-profile) bonus-points),
        total-purchases: (get total-purchases referrer-profile),
        referrals-made: (+ (get referrals-made referrer-profile) u1),
        badges: (get badges referrer-profile)
      }
    )
    
    (ok true)
  )
)

;; Check and award badges based on achievements
(define-private (check-and-award-badges (user principal))
  (let (
    (user-profile (unwrap! (map-get? user-profiles { user: user }) err-not-found))
    (purchases (get total-purchases user-profile))
    (referrals (get referrals-made user-profile))
  )
    ;; Check for "First Purchase" badge
    (if (and (is-eq purchases u1) 
             (is-none (map-get? user-achievements { user: user, badge: "first-purchase" })))
      (try! (award-badge user "first-purchase"))
      true
    )
    
    ;; Check for "Loyal Customer" badge (10+ purchases)
    (if (and (>= purchases u10)
             (is-none (map-get? user-achievements { user: user, badge: "loyal-customer" })))
      (try! (award-badge user "loyal-customer"))
      true
    )
    
    ;; Check for "Referral Master" badge (5+ referrals)
    (if (and (>= referrals u5)
             (is-none (map-get? user-achievements { user: user, badge: "referral-master" })))
      (try! (award-badge user "referral-master"))
      true
    )
    
    (ok true)
  )
)

;; Award a badge to a user
(define-private (award-badge (user principal) (badge-name (string-ascii 32)))
  (let (
    (user-profile (unwrap! (map-get? user-profiles { user: user }) err-not-found))
    (badge-def (map-get? badge-definitions { badge-name: badge-name }))
    (current-badges (get badges user-profile))
  )
    ;; Record the achievement
    (map-set user-achievements
      { user: user, badge: badge-name }
      {
        earned: true,
        timestamp: stacks-block-height
      }
    )
    
    ;; Add badge to user's badge list (if not already present)
    (map-set user-profiles
      { user: user }
      {
        total-points: (get total-points user-profile),
        total-purchases: (get total-purchases user-profile),
        referrals-made: (get referrals-made user-profile),
        badges: (unwrap-panic (as-max-len? (append current-badges badge-name) u10))
      }
    )
    
    ;; Award bonus points if badge has reward
    (match badge-def
      some-badge (map-set user-profiles
        { user: user }
        {
          total-points: (+ (get total-points user-profile) (get reward-points some-badge)),
          total-purchases: (get total-purchases user-profile),
          referrals-made: (get referrals-made user-profile),
          badges: (get badges user-profile)
        }
      )
      true ;; Return true when no badge definition exists
    )
    
    (ok true)
  )
)

;; Redeem loyalty points for rewards
(define-public (redeem-points (points-to-redeem uint))
  (let (
    (user tx-sender)
    (user-profile (unwrap! (map-get? user-profiles { user: user }) err-not-found))
    (current-points (get total-points user-profile))
  )
    (asserts! (>= points-to-redeem (var-get min-redemption-points)) err-insufficient-balance)
    (asserts! (>= current-points points-to-redeem) err-insufficient-balance)
    
    ;; Deduct points from user's balance
    (map-set user-profiles
      { user: user }
      {
        total-points: (- current-points points-to-redeem),
        total-purchases: (get total-purchases user-profile),
        referrals-made: (get referrals-made user-profile),
        badges: (get badges user-profile)
      }
    )
    
    (ok points-to-redeem)
  )
)

;; Report counterfeit product (rewards user with bonus points)
(define-public (report-counterfeit (product-id (string-ascii 64)) (evidence (string-ascii 256)))
  (let (
    (user tx-sender)
    (user-profile (unwrap! (map-get? user-profiles { user: user }) err-not-found))
    (bonus-points u25) ;; Bonus for reporting counterfeits
  )
    ;; Award bonus points for reporting
    (map-set user-profiles
      { user: user }
      {
        total-points: (+ (get total-points user-profile) bonus-points),
        total-purchases: (get total-purchases user-profile),
        referrals-made: (get referrals-made user-profile),
        badges: (get badges user-profile)
      }
    )
    
    ;; Check for "Fraud Fighter" badge
    (try! (check-fraud-fighter-badge user))
    
    (ok bonus-points)
  )
)

;; Check for fraud fighter badge (private helper)
(define-private (check-fraud-fighter-badge (user principal))
  (if (is-none (map-get? user-achievements { user: user, badge: "fraud-fighter" }))
    (award-badge user "fraud-fighter")
    (ok true)
  )
)

;; Initialize badge definitions (owner only)
(define-public (initialize-badges)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set badge-definitions
      { badge-name: "first-purchase" }
      { description: "Made your first verified purchase", requirement: u1, reward-points: u20 }
    )
    
    (map-set badge-definitions
      { badge-name: "loyal-customer" }
      { description: "Made 10 or more verified purchases", requirement: u10, reward-points: u100 }
    )
    
    (map-set badge-definitions
      { badge-name: "referral-master" }
      { description: "Successfully referred 5 or more customers", requirement: u5, reward-points: u150 }
    )
    
    (map-set badge-definitions
      { badge-name: "fraud-fighter" }
      { description: "Reported counterfeit products", requirement: u1, reward-points: u50 }
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get user profile
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

;; Get product information
(define-read-only (get-product-info (product-id (string-ascii 64)))
  (map-get? product-registry { product-id: product-id })
)

;; Get user's purchase history
(define-read-only (get-purchase (user principal) (purchase-id uint))
  (map-get? purchase-history { user: user, purchase-id: purchase-id })
)

;; Get referral relationship
(define-read-only (get-referral-info (referrer principal) (referee principal))
  (map-get? referral-relationships { referrer: referrer, referee: referee })
)

;; Get badge definition
(define-read-only (get-badge-info (badge-name (string-ascii 32)))
  (map-get? badge-definitions { badge-name: badge-name })
)

;; Check if user has earned a specific badge
(define-read-only (has-badge (user principal) (badge-name (string-ascii 32)))
  (is-some (map-get? user-achievements { user: user, badge: badge-name }))
)

;; Admin functions (owner only)

;; Update points per purchase
(define-public (set-points-per-purchase (new-points uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set points-per-purchase new-points))
  )
)

;; Update referral bonus
(define-public (set-referral-bonus (new-bonus uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set referral-bonus new-bonus))
  )
)

;; Update minimum redemption points
(define-public (set-min-redemption-points (new-min uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set min-redemption-points new-min))
  )
)
