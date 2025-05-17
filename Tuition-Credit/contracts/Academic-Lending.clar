;; Student Loan Smart Contract
;; This contract manages student loans, including application, approval, disbursement, and repayment

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-LOAN-AMOUNT (err u101))
(define-constant ERR-INVALID-LOAN-PERIOD (err u102))
(define-constant ERR-LOAN-NOT-FOUND (err u103))
(define-constant ERR-LOAN-ALREADY-APPROVED (err u104))
(define-constant ERR-LOAN-NOT-APPROVED (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-LOAN-ALREADY-DISBURSED (err u107))
(define-constant ERR-LOAN-ALREADY-PAID (err u108))

;; Define principal for the contract administrator
(define-data-var contract-admin principal tx-sender)

;; Data structure for a student loan
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    amount: uint,
    interest-rate: uint,  ;; Represented as basis points (e.g., 500 = 5%)
    term-months: uint,
    status: (string-ascii 20),  ;; "PENDING", "APPROVED", "DISBURSED", "PAID"
    disbursement-date: uint,    ;; Block height when loan was disbursed
    repayment-start-date: uint, ;; Block height when repayment should start
    amount-paid: uint,
    last-payment-date: uint     ;; Block height of the last payment
  }
)

;; Counter for loan IDs
(define-data-var next-loan-id uint u1)

;; Read-only function to get the current loan ID
(define-read-only (get-current-loan-id)
  (var-get next-loan-id)
)

;; Read-only function to get loan details
(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

;; Read-only function to check if sender is admin
(define-read-only (is-admin)
  (is-eq tx-sender (var-get contract-admin))
)

;; Function to change contract administrator
(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-admin new-admin))
  )
)

;; Function for a student to apply for a loan
(define-public (apply-for-loan (amount uint) (term-months uint) (interest-rate uint))
  (let
    (
      (loan-id (var-get next-loan-id))
    )
    ;; Validate loan parameters
    (asserts! (> amount u0) ERR-INVALID-LOAN-AMOUNT)
    (asserts! (and (> term-months u0) (<= term-months u240)) ERR-INVALID-LOAN-PERIOD) ;; Max 20 years
    
    ;; Create the loan
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: tx-sender,
        amount: amount,
        interest-rate: interest-rate,
        term-months: term-months,
        status: "PENDING",
        disbursement-date: u0,
        repayment-start-date: u0,
        amount-paid: u0,
        last-payment-date: u0
      }
    )
    
    ;; Increment loan ID for next loan
    (var-set next-loan-id (+ loan-id u1))
    
    ;; Return the loan ID
    (ok loan-id)
  )
)

;; Function for admin to approve a loan
(define-public (approve-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
    )
    ;; Ensure only admin can approve loans
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    ;; Ensure loan is in PENDING status
    (asserts! (is-eq (get status loan) "PENDING") ERR-LOAN-ALREADY-APPROVED)
    
    ;; Update loan status to APPROVED
    (map-set loans
      { loan-id: loan-id }
      (merge loan { status: "APPROVED" })
    )
    
    (ok true)
  )
)

;; Function to disburse approved loan funds
(define-public (disburse-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (current-block (get-block-info? time block-height))
    )
    ;; Ensure only admin can disburse loans
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    ;; Ensure loan is in APPROVED status
    (asserts! (is-eq (get status loan) "APPROVED") ERR-LOAN-NOT-APPROVED)
    
    ;; Ensure contract has enough STX to disburse
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) (get amount loan)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Calculate repayment start date (6 months after disbursement)
    (let
      (
        (repayment-start (+ (default-to u0 current-block) (* u144 u180))) ;; ~180 days later (assuming ~144 blocks per day)
      )
      ;; Transfer funds to borrower
      (try! (as-contract (stx-transfer? (get amount loan) tx-sender (get borrower loan))))
      
      ;; Update loan status and dates
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          status: "DISBURSED",
          disbursement-date: (default-to u0 current-block),
          repayment-start-date: repayment-start
        })
      )
      
      (ok true)
    )
  )
)

;; Function for borrower to make a loan payment
(define-public (make-payment (loan-id uint) (payment-amount uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (current-block (get-block-info? time block-height))
    )
    ;; Ensure sender is the borrower
    (asserts! (is-eq tx-sender (get borrower loan)) ERR-NOT-AUTHORIZED)
    
    ;; Ensure loan is in DISBURSED status
    (asserts! (is-eq (get status loan) "DISBURSED") ERR-LOAN-NOT-APPROVED)
    
    ;; Calculate total amount paid after this payment
    (let
      (
        (new-amount-paid (+ (get amount-paid loan) payment-amount))
        (loan-amount (get amount loan))
        (new-status (if (>= new-amount-paid loan-amount) "PAID" "DISBURSED"))
      )
      ;; Transfer payment from borrower to contract
      (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
      
      ;; Update loan with payment information
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          amount-paid: new-amount-paid,
          last-payment-date: (default-to u0 current-block),
          status: new-status
        })
      )
      
      (ok true)
    )
  )
)

;; Function to calculate remaining balance
(define-read-only (calculate-remaining-balance (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (current-block (get-block-info? time block-height))
      (amount (get amount loan))
      (amount-paid (get amount-paid loan))
      (interest-rate (get interest-rate loan))
      (disbursement-date (get disbursement-date loan))
    )
    ;; If loan isn't disbursed yet, return original amount
    (if (is-eq disbursement-date u0)
      (ok amount)
      ;; Otherwise calculate with interest
      (let
        (
          (blocks-elapsed (- (default-to u0 current-block) disbursement-date))
          (days-elapsed (/ blocks-elapsed u144)) ;; ~144 blocks per day
          (base-amount (- amount amount-paid))
          (interest-accrued (/ (* base-amount interest-rate days-elapsed) (* u10000 u365))) ;; Simple interest calculation
        )
        (ok (+ base-amount interest-accrued))
      )
    )
  )
)

;; Function to check if a loan belongs to a borrower
(define-read-only (is-loan-owner (loan-id uint) (owner principal))
  (let
    (
      (loan (map-get? loans { loan-id: loan-id }))
    )
    (if (is-some loan)
      (is-eq (get borrower (unwrap-panic loan)) owner)
      false
    )
  )
)

;; Function to get all loans for a borrower - simplified version with nested let bindings
(define-read-only (get-borrower-loans (borrower principal))
  (let
    (
      (loan-1 (if (is-loan-owner u1 borrower) (some u1) none))
      (loan-2 (if (is-loan-owner u2 borrower) (some u2) none))
      (loan-3 (if (is-loan-owner u3 borrower) (some u3) none))
      (loan-4 (if (is-loan-owner u4 borrower) (some u4) none))
      (loan-5 (if (is-loan-owner u5 borrower) (some u5) none))
      (empty-list (list))
    )
    ;; Use nested let bindings to build up the result
    (let
      (
        (result-1 (if (is-some loan-1) (append empty-list (unwrap-panic loan-1)) empty-list))
      )
      (let
        (
          (result-2 (if (is-some loan-2) (append result-1 (unwrap-panic loan-2)) result-1))
        )
        (let
          (
            (result-3 (if (is-some loan-3) (append result-2 (unwrap-panic loan-3)) result-2))
          )
          (let
            (
              (result-4 (if (is-some loan-4) (append result-3 (unwrap-panic loan-4)) result-3))
            )
            (let
              (
                (result-5 (if (is-some loan-5) (append result-4 (unwrap-panic loan-5)) result-4))
              )
              result-5
            )
          )
        )
      )
    )
  )
)