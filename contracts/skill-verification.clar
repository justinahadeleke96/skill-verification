;; title: skill-verification
;; version: 1.0.0
;; summary: Decentralized Skill Verification with Staking and Slashing
;; description: Professionals stake tokens to vouch for others' skills. False vouching results in slashing.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-stake (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-vouch-not-found (err u103))
(define-constant err-already-challenged (err u104))
(define-constant err-challenge-not-found (err u105))
(define-constant err-not-challenger (err u106))
(define-constant err-already-resolved (err u107))
(define-constant err-cannot-vouch-self (err u108))
(define-constant err-insufficient-balance (err u109))
(define-constant err-vouch-already-exists (err u110))

(define-constant min-vouch-stake u1000000) ;; Minimum 1 STX in microstacks
(define-constant challenge-stake u500000) ;; 0.5 STX to challenge
(define-constant slash-percentage u50) ;; 50% of stake slashed on false vouch

;; data vars
(define-data-var vouch-nonce uint u0)
(define-data-var challenge-nonce uint u0)
(define-data-var total-vouches uint u0)
(define-data-var total-challenges uint u0)

;; data maps
;; Stores user's available stake balance
(define-map user-stakes principal uint)

;; Stores vouches: {voucher, skill-name, vouchee} -> vouch-details
(define-map vouches
    {voucher: principal, skill-name: (string-ascii 50), vouchee: principal}
    {
        stake-amount: uint,
        vouch-id: uint,
        is-active: bool,
        is-challenged: bool
    }
)

;; Stores challenges by challenge-id
(define-map challenges
    uint
    {
        vouch-id: uint,
        voucher: principal,
        skill-name: (string-ascii 50),
        vouchee: principal,
        challenger: principal,
        challenge-stake: uint,
        is-resolved: bool,
        is-valid-challenge: (optional bool)
    }
)

;; Track reputation scores
(define-map reputation-scores principal uint)

;; Track all vouches received by a user for a skill
(define-map skill-vouch-count {vouchee: principal, skill-name: (string-ascii 50)} uint)

;; public functions

;; Deposit tokens to staking balance
(define-public (deposit-stake (amount uint))
    (let
        (
            (current-stake (default-to u0 (map-get? user-stakes tx-sender)))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-stakes tx-sender (+ current-stake amount))
        (ok true)
    )
)

;; Vouch for someone's skill by staking tokens
(define-public (vouch-for-skill (vouchee principal) (skill-name (string-ascii 50)) (stake-amount uint))
    (let
        (
            (voucher tx-sender)
            (current-stake (default-to u0 (map-get? user-stakes voucher)))
            (vouch-id (var-get vouch-nonce))
            (vouch-key {voucher: voucher, skill-name: skill-name, vouchee: vouchee})
            (current-count (default-to u0 (map-get? skill-vouch-count {vouchee: vouchee, skill-name: skill-name})))
        )
        (asserts! (not (is-eq voucher vouchee)) err-cannot-vouch-self)
        (asserts! (>= stake-amount min-vouch-stake) err-insufficient-stake)
        (asserts! (>= current-stake stake-amount) err-insufficient-balance)
        (asserts! (is-none (map-get? vouches vouch-key)) err-vouch-already-exists)

        ;; Deduct from available stake
        (map-set user-stakes voucher (- current-stake stake-amount))

        ;; Create vouch record
        (map-set vouches vouch-key {
            stake-amount: stake-amount,
            vouch-id: vouch-id,
            is-active: true,
            is-challenged: false
        })

        ;; Update counts
        (map-set skill-vouch-count {vouchee: vouchee, skill-name: skill-name} (+ current-count u1))
        (var-set vouch-nonce (+ vouch-id u1))
        (var-set total-vouches (+ (var-get total-vouches) u1))

        ;; Increase voucher's reputation
        (map-set reputation-scores voucher (+ (default-to u0 (map-get? reputation-scores voucher)) u1))

        (ok vouch-id)
    )
)

;; Challenge a vouch as false
(define-public (challenge-vouch (voucher principal) (skill-name (string-ascii 50)) (vouchee principal))
    (let
        (
            (challenger tx-sender)
            (challenger-stake (default-to u0 (map-get? user-stakes challenger)))
            (vouch-key {voucher: voucher, skill-name: skill-name, vouchee: vouchee})
            (vouch-data (unwrap! (map-get? vouches vouch-key) err-vouch-not-found))
            (challenge-id (var-get challenge-nonce))
        )
        (asserts! (get is-active vouch-data) err-vouch-not-found)
        (asserts! (not (get is-challenged vouch-data)) err-already-challenged)
        (asserts! (>= challenger-stake challenge-stake) err-insufficient-balance)

        ;; Deduct challenge stake
        (map-set user-stakes challenger (- challenger-stake challenge-stake))

        ;; Mark vouch as challenged
        (map-set vouches vouch-key (merge vouch-data {is-challenged: true}))

        ;; Create challenge record
        (map-set challenges challenge-id {
            vouch-id: (get vouch-id vouch-data),
            voucher: voucher,
            skill-name: skill-name,
            vouchee: vouchee,
            challenger: challenger,
            challenge-stake: challenge-stake,
            is-resolved: false,
            is-valid-challenge: none
        })

        (var-set challenge-nonce (+ challenge-id u1))
        (var-set total-challenges (+ (var-get total-challenges) u1))

        (ok challenge-id)
    )
)

;; Resolve a challenge (contract owner acts as arbiter in this simple version)
(define-public (resolve-challenge (challenge-id uint) (challenge-is-valid bool))
    (let
        (
            (challenge-data (unwrap! (map-get? challenges challenge-id) err-challenge-not-found))
            (voucher (get voucher challenge-data))
            (vouchee (get vouchee challenge-data))
            (skill-name (get skill-name challenge-data))
            (challenger (get challenger challenge-data))
            (vouch-key {voucher: voucher, skill-name: skill-name, vouchee: vouchee})
            (vouch-data (unwrap! (map-get? vouches vouch-key) err-vouch-not-found))
            (voucher-stake (default-to u0 (map-get? user-stakes voucher)))
            (challenger-stake (default-to u0 (map-get? user-stakes challenger)))
            (stake-amount (get stake-amount vouch-data))
            (slash-amount (/ (* stake-amount slash-percentage) u100))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get is-resolved challenge-data)) err-already-resolved)

        (if challenge-is-valid
            (begin
                ;; Challenge is valid - slash voucher, reward challenger
                (map-set user-stakes challenger (+ challenger-stake (get challenge-stake challenge-data) slash-amount))
                (map-set user-stakes voucher (+ voucher-stake (- stake-amount slash-amount)))
                (map-set vouches vouch-key (merge vouch-data {is-active: false}))

                ;; Decrease voucher's reputation
                (map-set reputation-scores voucher
                    (if (> (default-to u0 (map-get? reputation-scores voucher)) u0)
                        (- (default-to u0 (map-get? reputation-scores voucher)) u1)
                        u0
                    )
                )
            )
            (begin
                ;; Challenge is invalid - return stakes, penalize challenger
                (map-set user-stakes voucher (+ voucher-stake stake-amount))
                ;; Challenger loses their challenge stake (goes to voucher)
                (map-set user-stakes voucher (+ (default-to u0 (map-get? user-stakes voucher)) (get challenge-stake challenge-data)))
            )
        )

        ;; Mark challenge as resolved
        (map-set challenges challenge-id (merge challenge-data {
            is-resolved: true,
            is-valid-challenge: (some challenge-is-valid)
        }))

        (ok true)
    )
)

;; Withdraw available stake
(define-public (withdraw-stake (amount uint))
    (let
        (
            (current-stake (default-to u0 (map-get? user-stakes tx-sender)))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (>= current-stake amount) err-insufficient-balance)

        (map-set user-stakes tx-sender (- current-stake amount))
        (as-contract (stx-transfer? amount tx-sender (get-sender)))
    )
)

;; Helper to get sender in context
(define-private (get-sender)
    tx-sender
)

;; read only functions

;; Get user's available stake balance
(define-read-only (get-user-stake (user principal))
    (ok (default-to u0 (map-get? user-stakes user)))
)

;; Get vouch details
(define-read-only (get-vouch (voucher principal) (skill-name (string-ascii 50)) (vouchee principal))
    (ok (map-get? vouches {voucher: voucher, skill-name: skill-name, vouchee: vouchee}))
)

;; Get challenge details
(define-read-only (get-challenge (challenge-id uint))
    (ok (map-get? challenges challenge-id))
)

;; Get reputation score
(define-read-only (get-reputation (user principal))
    (ok (default-to u0 (map-get? reputation-scores user)))
)

;; Get total vouches for a user's skill
(define-read-only (get-skill-vouch-count (vouchee principal) (skill-name (string-ascii 50)))
    (ok (default-to u0 (map-get? skill-vouch-count {vouchee: vouchee, skill-name: skill-name})))
)

;; Get contract stats
(define-read-only (get-stats)
    (ok {
        total-vouches: (var-get total-vouches),
        total-challenges: (var-get total-challenges),
        vouch-nonce: (var-get vouch-nonce),
        challenge-nonce: (var-get challenge-nonce)
    })
)
