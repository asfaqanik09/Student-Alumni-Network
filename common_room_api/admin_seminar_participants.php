
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once "auth.php";

if ($_SERVER["REQUEST_METHOD"] !== "GET") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only GET requests are allowed."
    ]);
    exit;
}

try {
    // Authenticate the requesting user.
    $user = authenticateUser($conn);

    // Only admins can view participant information.
    requireRole($user, ["admin"]);

    $seminarId = (int)($_GET["seminar_id"] ?? 0);

    if ($seminarId <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Please provide a valid seminar ID."
        ]);
        exit;
    }

    // Check that the seminar exists.
    $check = $conn->prepare(
        "SELECT id, title, scheduled_at, event_type
         FROM seminars
         WHERE id = ?
         LIMIT 1"
    );

    $check->bind_param("i", $seminarId);
    $check->execute();

    $seminar = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$seminar) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Seminar not found."
        ]);
        exit;
    }

    // Retrieve registered participants.
    $stmt = $conn->prepare(
        "SELECT
            id AS registration_id,
            user_id,
            attendee_name,
            attendee_email,
            contact_number,
            registered_at
         FROM seminar_registrations
         WHERE seminar_id = ?
         ORDER BY registered_at DESC"
    );

    $stmt->bind_param("i", $seminarId);
    $stmt->execute();

    $result = $stmt->get_result();

    $participants = [];

    while ($row = $result->fetch_assoc()) {
        $participants[] = $row;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "seminar" => $seminar,
        "total_participants" => count($participants),
        "participants" => $participants
    ]);

} catch (Throwable $e) {

    error_log("Admin seminar participants error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not load seminar participants."
    ]);
}

$conn->close();

?>
