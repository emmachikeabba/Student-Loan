# Student Loan Smart Contract

A Clarity smart contract for managing student loans on the Stacks blockchain.

## Overview

This smart contract provides a decentralized platform for student loan management, enabling borrowers to apply for loans, administrators to approve and disburse funds, and a structured system for repayment tracking. It leverages the security and transparency of blockchain technology to create a fair and efficient lending system.

## Features

- **Loan Application**: Students can apply for loans with customizable terms
- **Administrative Approval**: Contract admin reviews and approves loan applications
- **Fund Disbursement**: Automated disbursement of approved loans
- **Repayment System**: Structured mechanism for loan repayments
- **Interest Calculation**: Accurate interest accrual based on loan terms
- **Loan Status Tracking**: Complete visibility into the loan lifecycle

## Contract Structure

### Constants
- Error codes for various contract states and validation checks

### Data Storage
- `loans`: Map storing all loan details indexed by loan ID
- `next-loan-id`: Counter for generating unique loan IDs
- `contract-admin`: Principal that has administrative privileges

### Status Values
- `PENDING`: Initial state after application
- `APPROVED`: Admin has approved the loan
- `DISBURSED`: Funds have been sent to borrower
- `PAID`: Loan has been fully repaid

## Public Functions

### For Borrowers

#### `apply-for-loan`
```clarity
(define-public (apply-for-loan (amount uint) (term-months uint) (interest-rate uint))
```
Creates a new loan application with the specified amount, term length, and interest rate.

#### `make-payment`
```clarity
(define-public (make-payment (loan-id uint) (payment-amount uint))
```
Allows a borrower to make a payment toward their loan.

### For Administrators

#### `approve-loan`
```clarity
(define-public (approve-loan (loan-id uint))
```
Approves a pending loan application.

#### `disburse-loan`
```clarity
(define-public (disburse-loan (loan-id uint))
```
Transfers the loan amount to the borrower after approval.

#### `set-contract-admin`
```clarity
(define-public (set-contract-admin (new-admin principal))
```
Transfers administrative privileges to a new principal.

### Read-Only Functions

#### `get-loan`
```clarity
(define-read-only (get-loan (loan-id uint))
```
Retrieves details for a specific loan.

#### `calculate-remaining-balance`
```clarity
(define-read-only (calculate-remaining-balance (loan-id uint))
```
Calculates the current outstanding balance including accrued interest.

#### `get-borrower-loans`
```clarity
(define-read-only (get-borrower-loans (borrower principal))
```
Returns all loan IDs associated with a specific borrower.

#### `is-admin`
```clarity
(define-read-only (is-admin))
```
Checks if the transaction sender is the contract administrator.

## Usage Examples

### Applying for a Loan
```clarity
;; Student applies for a $10,000 loan with 5% interest for 48 months
(contract-call? .student-loan apply-for-loan u10000000000 u48 u500)
```

### Approving a Loan (Admin Only)
```clarity
;; Admin approves loan with ID 1
(contract-call? .student-loan approve-loan u1)
```

### Making a Payment
```clarity
;; Borrower makes a $500 payment on loan ID 1
(contract-call? .student-loan make-payment u1 u500000000)
```

### Checking Loan Balance
```clarity
;; Check remaining balance for loan ID 1
(contract-call? .student-loan calculate-remaining-balance u1)
```

## Implementation Notes

- Interest rates are represented in basis points (e.g., 500 = 5.00%)
- Amounts are in micro-STX (1 STX = 1,000,000 micro-STX)
- Block heights are used for tracking dates
- Simple interest calculation is implemented

## Security Considerations

- Only the contract administrator can approve and disburse loans
- Only the borrower can make payments on their loans
- Contract uses proper authorization checks throughout
- Data validation prevents invalid loan parameters

## Deployment

To deploy this contract to the Stacks blockchain:

1. Use Clarinet for local testing:
   ```
   clarinet console
   ```

2. Deploy to testnet using Clarinet:
   ```
   clarinet deploy --testnet
   ```

3. For mainnet deployment, use the Stacks Web Wallet or other deployment tools