
<?php

header("Content-Type: application/json");

require_once __DIR__ . "/auth.php";

// Only POST requests are allowed.
if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);
    exit;
}

// Authenticate the logged-in user using the database connection.
$user = authenticateUser($conn);

// Only alumni can accept or decline mentorship requests.
requireRole($user, ["alumni"]);

// Get alumni ID from the authenticated session.
$alumniId = (string) $user["id"];

// Read JSON request data.
$data = json_decode(file_get_contents("php://input"), true);

if (!is_array($data)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid JSON request."
    ]);
    exit;
}

$requestId = (int) ($data["request_id"] ?? 0);
$status = trim($data["status"] ?? "");

// Validate request information.
if (
    $requestId <= 0 ||
    !in_array($status, ["accepted", "declined"], true)
) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid request information."
    ]);
    exit;
}

try {

    $sql = "
        UPDATE mentorship_requests
        SET status = ?
        WHERE id = ?
          AND alumni_id = ?
          AND status = 'pending'
    ";

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new Exception("Database query preparation failed.");
    }

    $stmt->bind_param("sis", $status, $requestId, $alumniId);
    $stmt->execute();

    if ($stmt->affected_rows > 0) {

        echo json_encode([
            "success" => true,
            "message" => "Request status updated successfully."
        ]);

    } else {

        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Pending request not found."
        ]);
    }

    $stmt->close();

} catch (Throwable $e) {

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Unable to update request status."
    ]);
}

?>
