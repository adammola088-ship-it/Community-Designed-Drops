(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-MEMBER (err u101))
(define-constant ERR-NOT-MEMBER (err u102))
(define-constant ERR-COLLECTION-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-VOTED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))
(define-constant ERR-CONTRIBUTION-NOT-FOUND (err u107))
(define-constant ERR-VOTING-ENDED (err u108))
(define-constant ERR-VOTING-ACTIVE (err u109))
(define-constant ERR-ALREADY-DELEGATE (err u110))
(define-constant ERR-NOT-DELEGATE (err u111))
(define-constant MIN-VOTING-PERIOD u144)
(define-constant ROYALTY-BASIS-POINTS u1000)

(define-data-var dao-treasury uint u0)
(define-data-var next-collection-id uint u1)
(define-data-var next-contribution-id uint u1)

(define-map dao-members principal bool)
(define-map member-reputation principal uint)

(define-map collections uint {
    creator: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    total-sales: uint,
    royalty-rate: uint,
    created-at: uint,
    is-active: bool
})

(define-map contributions uint {
    collection-id: uint,
    contributor: principal,
    description: (string-ascii 256),
    votes: uint,
    vote-weight: uint,
    created-at: uint
})

(define-map collection-contributions uint (list 50 uint))

(define-map contribution-votes {contribution-id: uint, voter: principal} bool)
(define-map member-votes {collection-id: uint, voter: principal} bool)

(define-map voting-periods uint {
    collection-id: uint,
    start-block: uint,
    end-block: uint,
    total-votes: uint,
    is-ended: bool
})

(define-map royalty-shares {collection-id: uint, contributor: principal} uint)

(define-map collection-delegates {collection-id: uint, delegate: principal} bool)

(define-public (join-dao)
    (let ((caller tx-sender))
        (asserts! (not (default-to false (map-get? dao-members caller))) ERR-ALREADY-MEMBER)
        (map-set dao-members caller true)
        (map-set member-reputation caller u10)
        (ok true)
    )
)

(define-public (create-collection (name (string-ascii 64)) (description (string-ascii 256)) (royalty-rate uint))
    (let (
        (collection-id (var-get next-collection-id))
        (caller tx-sender)
    )
        (asserts! (default-to false (map-get? dao-members caller)) ERR-NOT-MEMBER)
        (asserts! (<= royalty-rate u1000) ERR-INVALID-AMOUNT)
        (map-set collections collection-id {
            creator: caller,
            name: name,
            description: description,
            total-sales: u0,
            royalty-rate: royalty-rate,
            created-at: stacks-block-height,
            is-active: true
        })
        (var-set next-collection-id (+ collection-id u1))
        (ok collection-id)
    )
)

(define-public (submit-contribution (collection-id uint) (description (string-ascii 256)))
    (let (
        (contribution-id (var-get next-contribution-id))
        (caller tx-sender)
        (collection (unwrap! (map-get? collections collection-id) ERR-COLLECTION-NOT-FOUND))
        (existing-contributions (default-to (list) (map-get? collection-contributions collection-id)))
    )
        (asserts! (default-to false (map-get? dao-members caller)) ERR-NOT-MEMBER)
        (asserts! (get is-active collection) ERR-COLLECTION-NOT-FOUND)
        (map-set contributions contribution-id {
            collection-id: collection-id,
            contributor: caller,
            description: description,
            votes: u0,
            vote-weight: u0,
            created-at: stacks-block-height
        })
        (map-set collection-contributions collection-id (unwrap! (as-max-len? (append existing-contributions contribution-id) u50) ERR-INVALID-AMOUNT))
        (var-set next-contribution-id (+ contribution-id u1))
        (ok contribution-id)
    )
)

(define-public (vote-contribution (contribution-id uint))
    (let (
        (caller tx-sender)
        (contribution (unwrap! (map-get? contributions contribution-id) ERR-CONTRIBUTION-NOT-FOUND))
        (collection-id (get collection-id contribution))
        (voter-key {contribution-id: contribution-id, voter: caller})
        (reputation (default-to u0 (map-get? member-reputation caller)))
    )
        (asserts! (default-to false (map-get? dao-members caller)) ERR-NOT-MEMBER)
        (asserts! (not (default-to false (map-get? contribution-votes voter-key))) ERR-ALREADY-VOTED)
        (map-set contribution-votes voter-key true)
        (map-set contributions contribution-id 
            (merge contribution {
                votes: (+ (get votes contribution) u1),
                vote-weight: (+ (get vote-weight contribution) reputation)
            })
        )
        (map-set member-reputation caller (+ reputation u1))
        (ok true)
    )
)

(define-public (delegate-collection (collection-id uint) (delegate principal))
    (let (
        (caller tx-sender)
        (collection (unwrap! (map-get? collections collection-id) ERR-COLLECTION-NOT-FOUND))
        (delegate-key {collection-id: collection-id, delegate: delegate})
    )
        (asserts! (is-eq caller (get creator collection)) ERR-NOT-AUTHORIZED)
        (asserts! (default-to false (map-get? dao-members delegate)) ERR-NOT-MEMBER)
        (asserts! (not (default-to false (map-get? collection-delegates delegate-key))) ERR-ALREADY-DELEGATE)
        (map-set collection-delegates delegate-key true)
        (ok true)
    )
)

(define-public (revoke-delegate (collection-id uint) (delegate principal))
    (let (
        (caller tx-sender)
        (collection (unwrap! (map-get? collections collection-id) ERR-COLLECTION-NOT-FOUND))
        (delegate-key {collection-id: collection-id, delegate: delegate})
    )
        (asserts! (is-eq caller (get creator collection)) ERR-NOT-AUTHORIZED)
        (asserts! (default-to false (map-get? collection-delegates delegate-key)) ERR-NOT-DELEGATE)
        (map-delete collection-delegates delegate-key)
        (ok true)
    )
)

(define-private (is-authorized-manager (collection-id uint) (caller principal))
    (match (map-get? collections collection-id)
        collection
            (or 
                (is-eq caller (get creator collection))
                (default-to false (map-get? collection-delegates {collection-id: collection-id, delegate: caller}))
            )
        false
    )
)

(define-public (start-voting-period (collection-id uint))
    (let (
        (caller tx-sender)
        (collection (unwrap! (map-get? collections collection-id) ERR-COLLECTION-NOT-FOUND))
        (current-block stacks-block-height)
    )
        (asserts! (is-authorized-manager collection-id caller) ERR-NOT-AUTHORIZED)
        (map-set voting-periods collection-id {
            collection-id: collection-id,
            start-block: current-block,
            end-block: (+ current-block MIN-VOTING-PERIOD),
            total-votes: u0,
            is-ended: false
        })
        (ok true)
    )
)

(define-public (end-voting-period (collection-id uint))
    (let (
        (caller tx-sender)
        (collection (unwrap! (map-get? collections collection-id) ERR-COLLECTION-NOT-FOUND))
        (voting-period (unwrap! (map-get? voting-periods collection-id) ERR-COLLECTION-NOT-FOUND))
        (current-block stacks-block-height)
    )
        (asserts! (is-authorized-manager collection-id caller) ERR-NOT-AUTHORIZED)
        (asserts! (>= current-block (get end-block voting-period)) ERR-VOTING-ACTIVE)
        (asserts! (not (get is-ended voting-period)) ERR-VOTING-ENDED)
        (map-set voting-periods collection-id 
            (merge voting-period {is-ended: true})
        )
        (calculate-royalty-shares collection-id)
        (ok true)
    )
)

(define-public (record-sale (collection-id uint) (sale-amount uint))
    (let (
        (caller tx-sender)
        (collection (unwrap! (map-get? collections collection-id) ERR-COLLECTION-NOT-FOUND))
    )
        (asserts! (is-authorized-manager collection-id caller) ERR-NOT-AUTHORIZED)
        (map-set collections collection-id 
            (merge collection {
                total-sales: (+ (get total-sales collection) sale-amount)
            })
        )
        (distribute-royalties collection-id sale-amount)
        (ok true)
    )
)

(define-private (calculate-royalty-shares (collection-id uint))
    (let (
        (contributions-list (default-to (list) (map-get? collection-contributions collection-id)))
        (total-weight (fold calculate-total-weight contributions-list u0))
    )
        (fold set-contributor-share contributions-list {collection-id: collection-id, total-weight: total-weight})
        true
    )
)

(define-private (calculate-total-weight (contribution-id uint) (acc uint))
    (match (map-get? contributions contribution-id)
        contribution (+ acc (get vote-weight contribution))
        acc
    )
)

(define-private (set-contributor-share (contribution-id uint) (data {collection-id: uint, total-weight: uint}))
    (match (map-get? contributions contribution-id)
        contribution 
            (let (
                (collection-id (get collection-id data))
                (total-weight (get total-weight data))
                (contributor (get contributor contribution))
                (weight (get vote-weight contribution))
                (share (if (> total-weight u0) 
                    (/ (* weight ROYALTY-BASIS-POINTS) total-weight)
                    u0))
            )
                (map-set royalty-shares {collection-id: collection-id, contributor: contributor} share)
                data
            )
        data
    )
)

(define-private (distribute-royalties (collection-id uint) (sale-amount uint))
    (match (map-get? collections collection-id)
        collection
        (let (
            (royalty-amount (/ (* sale-amount (get royalty-rate collection)) u10000))
            (contributions-list (default-to (list) (map-get? collection-contributions collection-id)))
        )
            (var-set dao-treasury (+ (var-get dao-treasury) royalty-amount))
            (fold distribute-to-contributor contributions-list {collection-id: collection-id, amount: royalty-amount})
            true
        )
        false
    )
)

(define-private (distribute-to-contributor (contribution-id uint) (data {collection-id: uint, amount: uint}))
    (match (map-get? contributions contribution-id)
        contribution
            (let (
                (collection-id (get collection-id data))
                (total-amount (get amount data))
                (contributor (get contributor contribution))
                (share (default-to u0 (map-get? royalty-shares {collection-id: collection-id, contributor: contributor})))
                (payout (/ (* total-amount share) ROYALTY-BASIS-POINTS))
            )
                (begin
                    (if (> payout u0)
                        (unwrap-panic (stx-transfer? payout tx-sender contributor))
                        true
                    )
                    data
                )
            )
        data
    )
)

(define-read-only (get-collection (collection-id uint))
    (map-get? collections collection-id)
)

(define-read-only (get-contribution (contribution-id uint))
    (map-get? contributions contribution-id)
)

(define-read-only (get-member-reputation (member principal))
    (default-to u0 (map-get? member-reputation member))
)

(define-read-only (is-dao-member (member principal))
    (default-to false (map-get? dao-members member))
)

(define-read-only (get-collection-contributions (collection-id uint))
    (map-get? collection-contributions collection-id)
)

(define-read-only (get-royalty-share (collection-id uint) (contributor principal))
    (map-get? royalty-shares {collection-id: collection-id, contributor: contributor})
)

(define-read-only (get-voting-period (collection-id uint))
    (map-get? voting-periods collection-id)
)

(define-read-only (get-dao-treasury)
    (var-get dao-treasury)
)

(define-read-only (has-voted (contribution-id uint) (voter principal))
    (default-to false (map-get? contribution-votes {contribution-id: contribution-id, voter: voter}))
)

(define-read-only (is-collection-delegate (collection-id uint) (delegate principal))
    (default-to false (map-get? collection-delegates {collection-id: collection-id, delegate: delegate}))
)
