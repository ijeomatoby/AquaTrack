;; AquaTrack - Water conservation monitoring and efficiency rewards platform
(define-data-var conservation-director principal tx-sender)
(define-data-var total-water-saved uint u0)
(define-data-var efficiency-bonus-rate uint u20) ;; bonus points per liter saved
(define-data-var last-efficiency-assessment uint u0)

(define-map participant-savings principal uint)
(define-map conservation-methods principal (string-utf8 64))
(define-map approved-conservation-techniques (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-director (err u1500))
(define-constant err-director-already-designated (err u1501))
(define-constant err-invalid-water-amount (err u1502))
(define-constant err-no-efficiency-bonus (err u1503))
(define-constant err-no-water-savings (err u1504))
(define-constant err-invalid-conservation-method (err u1505))
(define-constant err-technique-not-approved (err u1506))

;; Verify director authorization
(define-private (is-conservation-director (caller principal))
  (begin
    (asserts! (is-eq caller (var-get conservation-director)) err-unauthorized-director)
    (ok true)))

;; Initialize water conservation monitoring system
(define-public (establish-conservation-program (director principal))
  (begin
    (asserts! (is-none (map-get? participant-savings director)) err-director-already-designated)
    (var-set conservation-director director)
    (ok "AquaTrack water conservation program established")))

;; Approve conservation technique for tracking
(define-public (approve-conservation-technique (technique (string-utf8 64)))
  (begin
    (try! (is-conservation-director tx-sender))
    (asserts! (> (len technique) u0) err-invalid-conservation-method)
    (map-set approved-conservation-techniques technique true)
    (ok "Conservation technique approved for tracking")))

;; Record water conservation activity
(define-public (record-water-savings (liters-saved uint) (conservation-method (string-utf8 64)))
  (begin
    (asserts! (> liters-saved u0) err-invalid-water-amount)
    (asserts! (default-to false (map-get? approved-conservation-techniques conservation-method)) err-technique-not-approved)
    
    (let ((current-savings (default-to u0 (map-get? participant-savings tx-sender))))
      (map-set participant-savings tx-sender (+ current-savings liters-saved))
      (map-set conservation-methods tx-sender conservation-method)
      (var-set total-water-saved (+ (var-get total-water-saved) liters-saved))
      (ok (+ current-savings liters-saved)))))

;; Process water efficiency bonuses
(define-public (process-efficiency-bonuses)
  (begin
    (try! (is-conservation-director tx-sender))
    (let ((current-assessment (+ (var-get last-efficiency-assessment) u1))
          (total-savings (var-get total-water-saved)))
      (asserts! (> total-savings (var-get last-efficiency-assessment)) err-no-efficiency-bonus)
      
      (let ((bonus-pool (* (var-get efficiency-bonus-rate) total-savings)))
        (var-set last-efficiency-assessment current-assessment)
        (ok bonus-pool)))))

;; Claim water conservation rewards
(define-public (claim-conservation-rewards)
  (begin
    (let ((participant-water-savings (default-to u0 (map-get? participant-savings tx-sender))))
      (asserts! (> participant-water-savings u0) err-no-water-savings)
      
      (let ((total-savings (var-get total-water-saved))
            (base-rewards (* (var-get efficiency-bonus-rate) participant-water-savings))
            (savings-percentage (/ (* participant-water-savings u100000) total-savings)))
        
        (let ((final-rewards (/ (* savings-percentage base-rewards) u100000)))
          (map-delete participant-savings tx-sender)
          (map-delete conservation-methods tx-sender)
          (var-set total-water-saved (- (var-get total-water-saved) participant-water-savings))
          (ok (+ participant-water-savings final-rewards)))))))

;; Read-only functions
(define-read-only (get-participant-savings (participant principal))
  (default-to u0 (map-get? participant-savings participant)))

(define-read-only (get-conservation-method (participant principal))
  (map-get? conservation-methods participant))

(define-read-only (get-total-water-saved)
  (var-get total-water-saved))

(define-read-only (is-technique-approved (technique (string-utf8 64)))
  (default-to false (map-get? approved-conservation-techniques technique)))