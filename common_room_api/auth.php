
<?php

require_once __DIR__ . "/db_connect.php";

/**
 * Authenticate a request using its Bearer token.
 * Returns the authenticated user's database information.
 */
function authenticateUser($conn) {

    // Get Authorization header.
    $headers = function_exists("getallheaders")
        ? getallheaders()
        : [];

    $authorization = $headers["Authorization"]
        ?? $headers["authorization"]
        ?? $_SERVER["HTTP_AUTHORIZATION"]
        ?? "";

    // Validate Bearer token format.
    if (!preg_match(
        '/^Bearer\s+([a-f0-9]{64})$/i',
        trim($authorization),
        $matches
    )) {
        http_response_code(401);

        echo json_encode([
            "success" => false,
            "message" => "Authentication token is missing or invalid."
        ]);

        exit;
    }

    // Hash the received token.
    $token = $matches[1];
    $tokenHash = hash("sha256", $token);

    try {

        // Find a valid, active session.
        $sql = "
            SELECT
                u.id,
                u.name,
                u.email,
                u.role,
                u.email_verified
            FROM user_sessions s
            INNER JOIN users u ON u.id = s.user_id
            WHERE s.token_hash = ?
              AND s.expires_at > NOW()
              AND s.revoked_at IS NULL
            LIMIT 1
        ";

        $stmt = $conn->prepare($sql);

        if (!$stmt) {
            throw new Exception("Database query preparation failed.");
        }

        $stmt->bind_param("s", $tokenHash);

        if (!$stmt->execute()) {
            throw new Exception("Database query execution failed.");
        }

        $result = $stmt->get_result();
        $user = $result->fetch_assoc();

        $stmt->close();

        // Verify session and email verification.
        if (
            !$user ||
            (int) $user["email_verified"] !== 1
        ) {
            http_response_code(401);

            echo json_encode([
                "success" => false,
                "message" => "Your session is invalid or expired. Please log in again."
            ]);

            exit;
        }

        return $user;

    } catch (Throwable $e) {

        error_log(
            "Authentication error: " . $e->getMessage()
        );

        http_response_code(500);

        echo json_encode([
            "success" => false,
            "message" => "Authentication service is temporarily unavailable."
        ]);

        exit;
    }
}

/**
 * Require a specific user role.
 */
function requireRole($user, $allowedRoles) {

    $userRole = strtolower(
        trim((string) ($user["role"] ?? ""))
    );

    $allowedRoles = array_map(
        "strtolower",
        $allowedRoles
    );

    if (!in_array($userRole, $allowedRoles, true)) {

        http_response_code(403);

        echo json_encode([
            "success" => false,
            "message" => "You are not authorized to perform this action."
        ]);

        exit;
    }
}

?>
