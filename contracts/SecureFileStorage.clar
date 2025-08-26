;; SecureFileStorage Contract 
;; Encrypted file storage with decentralized key management and access controls

;; Define the contract owner
(define-constant contract-owner tx-sender)

;; Error constants
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized-access (err u101))
(define-constant err-file-not-found (err u102))
(define-constant err-file-already-exists (err u103))
(define-constant err-invalid-input (err u104))

;; File storage structure
(define-map file-storage
  {file-id: (string-ascii 64)}
  {
    owner: principal,
    encrypted-hash: (string-ascii 128),
    access-key: (string-ascii 256),
    timestamp: uint,
    file-size: uint,
    is-active: bool
  }
)

;; Access control mapping - tracks who can access which files
(define-map file-access
  {file-id: (string-ascii 64), grantee: principal}
  {
    granted-at: uint,
    access-level: (string-ascii 10) ;; "read", "write", "full"
  }
)

;; Persisted variable to track total files count
(define-data-var total-files uint u0)

;; Function: Store a new file
(define-public (store-file
  (file-id (string-ascii 64))
  (encrypted-hash (string-ascii 128))
  (access-key (string-ascii 256))
  (file-size uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len file-id) u0) err-invalid-input)
    (asserts! (> (len encrypted-hash) u0) err-invalid-input)
    (asserts! (> (len access-key) u0) err-invalid-input)
    (asserts! (> file-size u0) err-invalid-input)
    
    ;; Check if file already exists
    (asserts! (is-none (map-get? file-storage {file-id: file-id})) err-file-already-exists)
    
    ;; Store the file
    (ok (map-set file-storage
      {file-id: file-id}
      {
        owner: tx-sender,
        encrypted-hash: encrypted-hash,
        access-key: access-key,
        timestamp: stacks-block-height,
        file-size: file-size,
        is-active: true
      }
    ))
  )
)

;; Function: Grant access to a file with specific permissions
(define-public (grant-file-access
  (file-id (string-ascii 64))
  (new-grantee principal)
  (access-level (string-ascii 10)))
  (begin
    ;; Validate inputs
    (asserts! (> (len file-id) u0) err-invalid-input)
    (asserts! (or (is-eq access-level "read") 
                  (is-eq access-level "write") 
                  (is-eq access-level "full")) err-invalid-input)
    
    ;; Check if file exists and caller is owner
    (match (map-get? file-storage {file-id: file-id})
      file-data
      (begin
        (asserts! (is-eq tx-sender (get owner file-data)) err-unauthorized-access)
        (asserts! (get is-active file-data) err-file-not-found)
        
        ;; Grant access
          (let ((key {file-id: file-id, grantee: new-grantee}))
            (map-set file-access
              key
              {
                granted-at: stacks-block-height,
                access-level: access-level
              }
            )
          )
        (ok true)
      )
      err-file-not-found
    )
  )
)

;; Function: Revoke file access (only file owner)
(define-public (revoke-file-access
  (file-id (string-ascii 64))
  (revoke-grantee principal))
  (begin
    ;; Check if file exists and caller is owner
    (match (map-get? file-storage {file-id: file-id})
      file-data
      (begin
        (asserts! (is-eq tx-sender (get owner file-data)) err-unauthorized-access)
        
        ;; Remove access
        (let ((key {file-id: file-id, grantee: revoke-grantee}))
          (map-delete file-access key)
        )
        (ok true)
      )
      err-file-not-found
    )
  )
)

;; Function: Deactivate a file (only owner)
(define-public (deactivate-file (file-id (string-ascii 64)))
  (match (map-get? file-storage {file-id: file-id})
    file-data
    (begin
      (asserts! (is-eq tx-sender (get owner file-data)) err-unauthorized-access)
      
      ;; Update file status
      (let ((key {file-id: file-id}))
        (map-set file-storage
          key
          (merge file-data {is-active: false})
        )
      )
      (ok true)
    )
    err-file-not-found
  )
)

;; Read-only function: Get file information (only for authorized users)
(define-read-only (get-file-info (file-id (string-ascii 64)) (user principal))
  (match (map-get? file-storage {file-id: file-id})
    file-data 
    (if (or (is-eq user (get owner file-data))
            (is-some (map-get? file-access {file-id: file-id, grantee: user})))
      (ok (some file-data))
      err-unauthorized-access)
    (ok none)
  )
)

;; Read-only function: Check user access level for a file
(define-read-only (get-user-access (file-id (string-ascii 64)) (user principal))
  (ok (map-get? file-access {file-id: file-id, grantee: user}))
)

;; Read-only function: Get total files count
(define-read-only (get-total-files)
  (ok (var-get total-files))
)

;; Read-only function: Check if file exists
(define-read-only (file-exists (file-id (string-ascii 64)))
  (ok (is-some (map-get? file-storage {file-id: file-id})))
)

;; Read-only function: Get file owner
(define-read-only (get-file-owner (file-id (string-ascii 64)))
  (match (map-get? file-storage {file-id: file-id})
    file-data (ok (some (get owner file-data)))
    (ok none)
  )
)

;; Read-only function: Check if file is active
(define-read-only (is-file-active (file-id (string-ascii 64)))
  (match (map-get? file-storage {file-id: file-id})
    file-data (ok (get is-active file-data))
    (ok false)
  )
)