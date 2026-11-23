
<?php
header("Content-Type: application/json; charset=UTF-8");

require_once "db_connect.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);

$email = strtolower(trim($data["email"] ?? ""));
$password = $data["password"] ?? "";

if ($email === "" || $password === "") {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Please enter your email and password."
    ]);
    exit;
}

$adminEmails = [
    "aniksorder96@gmail.com",
    "erinafrin10@gmail.com",
    "jubayerhossain.jhj@gmail.com"
];

try {
    $stmt = $conn->prepare(
        "SELECT id, email, password_hash, role, name, email_verified
         FROM users
         WHERE email = ?
         LIMIT 1"
    );

    $stmt->bind_param("s", $email);
    $stmt->execute();

    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    if (!$user || !password_verify($password, $user["password_hash"])) {
        http_response_code(401);
        echo json_encode([
            "success" => false,
            "message" => "Incorrect email or password."
        ]);
        exit;
    }

    if ((int)$user["email_verified"] !== 1) {
        http_response_code(403);
        echo json_encode([
            "success" => false,
            "message" => "Please verify your email before logging in."
        ]);
        exit;
    }

    $userEmail = strtolower($user["email"]);

    if (in_array($userEmail, $adminEmails, true)) {
        $role = "admin";

        if ($user["role"] !== "admin") {
            $update = $conn->prepare(
                "UPDATE users SET role = 'admin' WHERE id = ?"
            );
            $update->bind_param("s", $user["id"]);
            $update->execute();
            $update->close();
        }
    } else {
        $role = strtolower($user["role"]);

        if ($role === "admin") {
            $role = "pending";

            $update = $conn->prepare(
                "UPDATE users SET role = 'pending' WHERE id = ?"
            );
            $update->bind_param("s", $user["id"]);
            $update->execute();
            $update->close();
        }
    }

    // Generate a cryptographically secure login token.
    $token = bin2hex(random_bytes(32));
    $tokenHash = hash("sha256", $token);

    // Token expires after 30 days.
    $expiresAt = date(
        "Y-m-d H:i:s",
        time() + (30 * 24 * 60 * 60)
    );

    $sessionStmt = $conn->prepare(
        "INSERT INTO user_sessions (user_id, token_hash, expires_at)
         VALUES (?, ?, ?)"
    );

    $sessionStmt->bind_param(
        "sss",
        $user["id"],
        $tokenHash,
        $expiresAt
    );

    $sessionStmt->execute();
    $sessionStmt->close();

    echo json_encode([
        "success" => true,
        "message" => "Login successful.",
        "token" => $token,
        "user" => [
            "id" => $user["id"],
            "email" => $user["email"],
            "name" => $user["name"],
            "role" => $role
        ]
    ]);

} catch (Throwable $e) {
    error_log("Login error: " . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Login failed due to a server error."
    ]);
}

$conn->close();
?>
