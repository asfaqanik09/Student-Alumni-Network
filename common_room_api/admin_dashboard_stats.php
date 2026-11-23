
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

    $students = $conn->query(
        "SELECT COUNT(*) AS total FROM users WHERE role = 'student'"
    )->fetch_assoc()["total"];

    $alumni = $conn->query(
        "SELECT COUNT(*) AS total FROM users WHERE role = 'alumni'"
    )->fetch_assoc()["total"];

    $connections = $conn->query(
        "SELECT COUNT(*) AS total FROM mentorship_requests WHERE status = 'accepted'"
    )->fetch_assoc()["total"];

    $pending = $conn->query(
        "SELECT COUNT(*) AS total FROM mentorship_requests WHERE status = 'pending'"
    )->fetch_assoc()["total"];

    echo json_encode([
        "success" => true,
        "students" => (int)$students,
        "alumni" => (int)$alumni,
        "connections" => (int)$connections,
        "pending" => (int)$pending
    ]);

} catch (Throwable $e) {
    error_log("Admin dashboard stats error: " . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Could not load dashboard statistics."
    ]);
}

$conn->close();
?>
