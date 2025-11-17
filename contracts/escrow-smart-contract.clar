(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ESCROW_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATE (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_EXPIRED (err u104))
(define-constant ERR_NOT_EXPIRED (err u105))
(define-constant ERR_ALREADY_RELEASED (err u106))
(define-constant ERR_ALREADY_REFUNDED (err u107))
(define-constant ERR_INVALID_FEE (err u108))
(define-constant ERR_INVALID_MILESTONE (err u109))
(define-constant ERR_MILESTONE_NOT_FOUND (err u110))
(define-constant ERR_MILESTONE_ALREADY_RELEASED (err u111))
(define-constant ERR_MILESTONE_NOT_CONFIRMED (err u112))

(define-data-var next-escrow-id uint u1)
(define-data-var platform-fee-rate uint u250)
(define-data-var collected-fees uint u0)

(define-map escrows
  { escrow-id: uint }
  {
    buyer: principal,
    seller: principal,
    arbitrator: principal,
    amount: uint,
    state: (string-ascii 20),
    created-at: uint,
    expires-at: uint,
    title: (string-ascii 50),
    description: (string-ascii 200)
  }
)

(define-map escrow-funds
  { escrow-id: uint }
  { amount: uint }
)

(define-map milestones
  { escrow-id: uint, milestone-id: uint }
  {
    amount: uint,
    description: (string-ascii 100),
    state: (string-ascii 20),
    confirmed-at: uint
  }
)

(define-map milestone-count
  { escrow-id: uint }
  { count: uint }
)

(define-private (get-current-escrow-id)
  (var-get next-escrow-id)
)

(define-private (get-milestone-count (escrow-id uint))
  (match (map-get? milestone-count { escrow-id: escrow-id })
    count-data (get count count-data)
    u0
  )
)

(define-private (increment-milestone-count (escrow-id uint))
  (let
    (
      (current-count (get-milestone-count escrow-id))
      (new-count (+ current-count u1))
    )
    (map-set milestone-count { escrow-id: escrow-id } { count: new-count })
  )
)

(define-private (increment-escrow-id)
  (var-set next-escrow-id (+ (var-get next-escrow-id) u1))
)

(define-read-only (get-escrow-details (escrow-id uint))
  (map-get? escrows { escrow-id: escrow-id })
)

(define-read-only (get-escrow-funds (escrow-id uint))
  (map-get? escrow-funds { escrow-id: escrow-id })
)

(define-read-only (is-escrow-expired (escrow-id uint))
  (match (get-escrow-details escrow-id)
    escrow-data (>= stacks-block-height (get expires-at escrow-data))
    false
  )
)

(define-read-only (get-escrow-state (escrow-id uint))
  (match (get-escrow-details escrow-id)
    escrow-data (get state escrow-data)
    "not-found"
  )
)

(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-collected-fees)
  (var-get collected-fees)
)

(define-public (create-escrow 
  (seller principal)
  (arbitrator principal)
  (amount uint)
  (duration uint)
  (title (string-ascii 50))
  (description (string-ascii 200))
)
  (let 
    (
      (escrow-id (get-current-escrow-id))
      (expires-at (+ stacks-block-height duration))
    )
    (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> duration u0) ERR_INVALID_STATE)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set escrows
      { escrow-id: escrow-id }
      {
        buyer: tx-sender,
        seller: seller,
        arbitrator: arbitrator,
        amount: amount,
        state: "pending",
        created-at: stacks-block-height,
        expires-at: expires-at,
        title: title,
        description: description
      }
    )
    
    (map-set escrow-funds
      { escrow-id: escrow-id }
      { amount: amount }
    )
    
    (increment-escrow-id)
    (ok escrow-id)
  )
)

(define-public (confirm-delivery (escrow-id uint))
  (let 
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get seller escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state escrow-data) "pending") ERR_INVALID_STATE)
    (asserts! (not (is-escrow-expired escrow-id)) ERR_EXPIRED)
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: "delivered" })
    )
    
    (ok true)
  )
)

(define-public (release-funds (escrow-id uint))
  (let 
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (escrow-fund-data (unwrap! (get-escrow-funds escrow-id) ERR_ESCROW_NOT_FOUND))
      (total-amount (get amount escrow-fund-data))
      (platform-fee (calculate-fee total-amount))
      (seller-amount (- total-amount platform-fee))
    )
    (asserts! (is-eq tx-sender (get buyer escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (or 
      (is-eq (get state escrow-data) "delivered")
      (is-eq (get state escrow-data) "pending")
    ) ERR_INVALID_STATE)
    (asserts! (not (is-escrow-expired escrow-id)) ERR_EXPIRED)
    
    (try! (as-contract (stx-transfer? 
      seller-amount
      tx-sender 
      (get seller escrow-data)
    )))
    
    (try! (as-contract (stx-transfer? 
      platform-fee
      tx-sender 
      CONTRACT_OWNER
    )))
    
    (var-set collected-fees (+ (var-get collected-fees) platform-fee))
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: "completed" })
    )
    
    (map-delete escrow-funds { escrow-id: escrow-id })
    
    (ok true)
  )
)

(define-public (dispute-escrow (escrow-id uint))
  (let 
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get buyer escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (or 
      (is-eq (get state escrow-data) "pending")
      (is-eq (get state escrow-data) "delivered")
    ) ERR_INVALID_STATE)
    (asserts! (not (is-escrow-expired escrow-id)) ERR_EXPIRED)
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: "disputed" })
    )
    
    (ok true)
  )
)

(define-public (resolve-dispute (escrow-id uint) (release-to-seller bool))
  (let 
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (escrow-fund-data (unwrap! (get-escrow-funds escrow-id) ERR_ESCROW_NOT_FOUND))
      (recipient (if release-to-seller (get seller escrow-data) (get buyer escrow-data)))
    )
    (asserts! (is-eq tx-sender (get arbitrator escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state escrow-data) "disputed") ERR_INVALID_STATE)
    
    (try! (as-contract (stx-transfer? 
      (get amount escrow-fund-data)
      tx-sender 
      recipient
    )))
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: (if release-to-seller "completed" "refunded") })
    )
    
    (map-delete escrow-funds { escrow-id: escrow-id })
    
    (ok true)
  )
)

(define-public (refund-expired (escrow-id uint))
  (let 
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (escrow-fund-data (unwrap! (get-escrow-funds escrow-id) ERR_ESCROW_NOT_FOUND))
    )
    (asserts! (is-escrow-expired escrow-id) ERR_NOT_EXPIRED)
    (asserts! (is-eq (get state escrow-data) "pending") ERR_INVALID_STATE)
    
    (try! (as-contract (stx-transfer? 
      (get amount escrow-fund-data)
      tx-sender 
      (get buyer escrow-data)
    )))
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: "expired-refunded" })
    )
    
    (map-delete escrow-funds { escrow-id: escrow-id })
    
    (ok true)
  )
)

(define-public (cancel-escrow (escrow-id uint))
  (let 
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (escrow-fund-data (unwrap! (get-escrow-funds escrow-id) ERR_ESCROW_NOT_FOUND))
    )
    (asserts! (or
      (is-eq tx-sender (get buyer escrow-data))
      (is-eq tx-sender (get seller escrow-data))
    ) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state escrow-data) "pending") ERR_INVALID_STATE)
    
    (try! (as-contract (stx-transfer? 
      (get amount escrow-fund-data)
      tx-sender 
      (get buyer escrow-data)
    )))
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { state: "cancelled" })
    )
    
    (map-delete escrow-funds { escrow-id: escrow-id })
    
    (ok true)
  )
)

(define-read-only (get-total-escrows)
  (- (var-get next-escrow-id) u1)
)

(define-read-only (get-escrows-by-buyer (buyer principal))
  (let 
    (
      (total-escrows (get-total-escrows))
    )
    (filter-escrows-by-buyer buyer total-escrows)
  )
)

(define-read-only (get-escrows-by-seller (seller principal))
  (let 
    (
      (total-escrows (get-total-escrows))
    )
    (filter-escrows-by-seller seller total-escrows)
  )
)

(define-private (filter-escrows-by-buyer (buyer principal) (max-id uint))
  (fold check-escrow-buyer (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) (list))
)

(define-private (filter-escrows-by-seller (seller principal) (max-id uint))
  (fold check-escrow-seller (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) (list))
)

(define-private (check-escrow-buyer (escrow-id uint) (acc (list 10 uint)))
  (match (get-escrow-details escrow-id)
    escrow-data (if (is-eq (get buyer escrow-data) tx-sender)
      (unwrap-panic (as-max-len? (append acc escrow-id) u10))
      acc
    )
    acc
  )
)

(define-private (check-escrow-seller (escrow-id uint) (acc (list 10 uint)))
  (match (get-escrow-details escrow-id)
    escrow-data (if (is-eq (get seller escrow-data) tx-sender)
      (unwrap-panic (as-max-len? (append acc escrow-id) u10))
      acc
    )
    acc
  )
)

(define-public (update-platform-fee (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee-rate u1000) ERR_INVALID_FEE)
    (var-set platform-fee-rate new-fee-rate)
    (ok true)
  )
)

(define-public (withdraw-collected-fees)
  (let 
    (
      (fee-amount (var-get collected-fees))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> fee-amount u0) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? fee-amount tx-sender CONTRACT_OWNER)))
    (var-set collected-fees u0)
    
    (ok fee-amount)
  )
)

(define-read-only (preview-fee (amount uint))
  (let
    (
      (fee (calculate-fee amount))
      (net-amount (- amount fee))
    )
    {
      total-amount: amount,
      platform-fee: fee,
      seller-receives: net-amount,
      fee-rate: (var-get platform-fee-rate)
    }
  )
)

(define-public (create-milestone-escrow
  (seller principal)
  (arbitrator principal)
  (total-amount uint)
  (duration uint)
  (title (string-ascii 50))
  (description (string-ascii 200))
)
  (let
    (
      (escrow-id (get-current-escrow-id))
      (expires-at (+ stacks-block-height duration))
    )
    (asserts! (> total-amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> duration u0) ERR_INVALID_STATE)

    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

    (map-set escrows
      { escrow-id: escrow-id }
      {
        buyer: tx-sender,
        seller: seller,
        arbitrator: arbitrator,
        amount: total-amount,
        state: "milestone-pending",
        created-at: stacks-block-height,
        expires-at: expires-at,
        title: title,
        description: description
      }
    )

    (map-set escrow-funds
      { escrow-id: escrow-id }
      { amount: total-amount }
    )

    (map-set milestone-count
      { escrow-id: escrow-id }
      { count: u0 }
    )

    (increment-escrow-id)
    (ok escrow-id)
  )
)

(define-public (add-milestone
  (escrow-id uint)
  (amount uint)
  (description (string-ascii 100))
)
  (let
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (escrow-fund-data (unwrap! (get-escrow-funds escrow-id) ERR_ESCROW_NOT_FOUND))
      (current-count (get-milestone-count escrow-id))
      (milestone-id current-count)
      (total-milestone-amount (fold sum-milestone-amounts (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) u0))
    )
    (asserts! (is-eq tx-sender (get buyer escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state escrow-data) "milestone-pending") ERR_INVALID_STATE)
    (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (<= (+ total-milestone-amount amount) (get amount escrow-fund-data)) ERR_INSUFFICIENT_FUNDS)

    (map-set milestones
      { escrow-id: escrow-id, milestone-id: milestone-id }
      {
        amount: amount,
        description: description,
        state: "pending",
        confirmed-at: u0
      }
    )

    (increment-milestone-count escrow-id)
    (ok milestone-id)
  )
)

(define-private (sum-milestone-amounts (idx uint) (acc uint))
  acc
)

(define-public (confirm-milestone
  (escrow-id uint)
  (milestone-id uint)
)
  (let
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (milestone-data (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get seller escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state escrow-data) "milestone-pending") ERR_INVALID_STATE)
    (asserts! (is-eq (get state milestone-data) "pending") ERR_MILESTONE_ALREADY_RELEASED)
    (asserts! (not (is-escrow-expired escrow-id)) ERR_EXPIRED)

    (map-set milestones
      { escrow-id: escrow-id, milestone-id: milestone-id }
      (merge milestone-data { state: "confirmed", confirmed-at: stacks-block-height })
    )

    (ok true)
  )
)

(define-public (release-milestone-funds
  (escrow-id uint)
  (milestone-id uint)
)
  (let
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (milestone-data (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (milestone-amount (get amount milestone-data))
      (platform-fee (calculate-fee milestone-amount))
      (seller-amount (- milestone-amount platform-fee))
    )
    (asserts! (is-eq tx-sender (get buyer escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get state escrow-data) "milestone-pending") ERR_INVALID_STATE)
    (asserts! (is-eq (get state milestone-data) "confirmed") ERR_MILESTONE_NOT_CONFIRMED)
    (asserts! (not (is-escrow-expired escrow-id)) ERR_EXPIRED)

    (try! (as-contract (stx-transfer?
      seller-amount
      tx-sender
      (get seller escrow-data)
    )))

    (try! (as-contract (stx-transfer?
      platform-fee
      tx-sender
      CONTRACT_OWNER
    )))

    (var-set collected-fees (+ (var-get collected-fees) platform-fee))

    (map-set milestones
      { escrow-id: escrow-id, milestone-id: milestone-id }
      (merge milestone-data { state: "released" })
    )

    (ok true)
  )
)

(define-read-only (get-milestone (escrow-id uint) (milestone-id uint))
  (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count-for-escrow (escrow-id uint))
  (get-milestone-count escrow-id)
)

(define-public (top-up-escrow (escrow-id uint) (additional-amount uint))
  (let
    (
      (escrow-data (unwrap! (get-escrow-details escrow-id) ERR_ESCROW_NOT_FOUND))
      (funds (unwrap! (get-escrow-funds escrow-id) ERR_ESCROW_NOT_FOUND))
      (new-amount (+ (get amount funds) additional-amount))
    )
    (asserts! (is-eq tx-sender (get buyer escrow-data)) ERR_NOT_AUTHORIZED)
    (asserts! (> additional-amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (or (is-eq (get state escrow-data) "pending") (is-eq (get state escrow-data) "milestone-pending")) ERR_INVALID_STATE)
    (asserts! (not (is-escrow-expired escrow-id)) ERR_EXPIRED)
    (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
    (map-set escrow-funds { escrow-id: escrow-id } { amount: new-amount })
    (map-set escrows { escrow-id: escrow-id } (merge escrow-data { amount: new-amount }))
    (ok new-amount)
  )
)
