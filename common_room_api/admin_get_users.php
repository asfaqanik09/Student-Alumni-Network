
<?php
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . "/db_connect.php";

if ($_SERVER["REQUEST_METHOD"] !== "GET") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only GET requests are allowed."
    ]);
    exit;
}

$adminEmail = strtolower(trim($_GET["email"] ?? ""));

$adminEmails = [
    "aniksorder96@gmail.com",
    "erinafrin10@gmail.com",
    "jubayerhossain.jhj@gmail.com"
];

if (!in_array($adminEmail, $adminEmails, true)) {
    http_response_code(403);
    echo json_encode([
        "success" => false,
        "message" => "Admin access denied."
    ]);
    exit;
}

try {
    $auth = $conn->prepare(
        "SELECT id FROM users WHERE email = ? AND role = 'admin' LIMIT 1"
    );

    $auth->bind_param("s", $adminEmail);
    $auth->execute();

    $admin = $auth->get_result()->fetch_assoc();
    $auth->close();

    if (!$admin) {
        http_response_code(403);
        echo json_encode([
            "success" => false,
            "message" => "Admin account not found."
        ]);
        exit;
    }

    $sql = "
        SELECT id, name, email, role, email_verified
        FROM users
        WHERE role IN ('student', 'alumni', 'pending')
        ORDER BY name ASC
    ";

    $result = $conn->query($sql);

    $users = [];

    while ($row = $result->fetch_assoc()) {
        $users[] = [
            "id" => $row["id"],
            "name" => $row["name"],
            "email" => $row["email"],
            "role" => $row["role"],
            "email_verified" => (int)$row["email_verified"]
        ];
    }

    echo json_encode([
        "success" => true,
        "users" => $users
    ]);

} catch (Throwable $e) {
    error_log("Admin users error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not load users."
    ]);
}

$conn->close();
?>
