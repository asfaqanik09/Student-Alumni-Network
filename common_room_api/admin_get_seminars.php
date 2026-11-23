
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
    $user = authenticateUser($conn);
    requireRole($user, ["admin"]);

    $stmt = $conn->prepare(
        "SELECT
            s.id,
            s.title,
            s.description,
            s.scheduled_at,
            s.duration_minutes,
            s.created_by,
            s.status,
            s.approved_by,
            s.meeting_link,
            s.published_at,
            s.created_at,
            s.event_type,
            s.location,
            u.name AS alumni_name,
            u.email AS alumni_email
         FROM seminars s
         LEFT JOIN users u ON u.id = s.created_by
         ORDER BY
            CASE
                WHEN s.status = 'pending' THEN 0
                WHEN s.status = 'approved' THEN 1
                ELSE 2
            END,
            s.created_at DESC"
    );

    $stmt->execute();

    $result = $stmt->get_result();

    $seminars = [];

    while ($row = $result->fetch_assoc()) {
        $row["id"] = (int)$row["id"];
        $row["duration_minutes"] =
            (int)$row["duration_minutes"];

        $seminars[] = $row;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "seminars" => $seminars,
        "total_seminars" => count($seminars)
    ]);

} catch (Throwable $e) {

    error_log("Admin get seminars error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not load seminar proposals."
    ]);
}

$conn->close();

?>
