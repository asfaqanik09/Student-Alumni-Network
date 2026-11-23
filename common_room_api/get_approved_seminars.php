
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
    // Verify the logged-in user.
    $user = authenticateUser($conn);

    // Students and alumni can browse approved seminars.
    requireRole($user, ["student", "alumni"]);

    $stmt = $conn->prepare(
        "SELECT
            s.id,
            s.title,
            s.description,
            s.scheduled_at,
            s.duration_minutes,
            s.event_type,
            s.location,
            s.created_at,
            u.name AS organizer_name
         FROM seminars s
         INNER JOIN users u ON u.id = s.created_by
         WHERE s.status = 'approved'
           AND s.scheduled_at >= NOW()
         ORDER BY s.scheduled_at ASC"
    );

    $stmt->execute();

    $result = $stmt->get_result();

    $seminars = [];

    while ($row = $result->fetch_assoc()) {
        $seminars[] = $row;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "count" => count($seminars),
        "seminars" => $seminars
    ]);

} catch (Throwable $e) {

    error_log("Get approved seminars error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not load approved seminars."
    ]);
}

$conn->close();

?>
