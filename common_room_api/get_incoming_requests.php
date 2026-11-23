
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . "/auth.php";

function sendResponse($status, $data) {
    http_response_code($status);

    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
    );

    exit;
}

// Only GET requests are allowed.
if ($_SERVER["REQUEST_METHOD"] !== "GET") {
    sendResponse(405, [
        "success" => false,
        "message" => "Only GET requests are allowed."
    ]);
}

// Authenticate the logged-in user.
$user = authenticateUser($conn);

// Only alumni can view incoming mentorship requests.
requireRole($user, ["alumni"]);

// Use the authenticated alumni ID.
$alumniId = $user["id"];

try {

    $sql = "
        SELECT
            mr.id,
            mr.student_id,
            mr.alumni_id,
            mr.message,
            mr.status,
            mr.created_at,
            mr.ai_review_status,
            mr.ai_review_score,
            mr.ai_review_reason,
            u.name AS student_name
        FROM mentorship_requests mr
        INNER JOIN users u ON u.id = mr.student_id
        WHERE mr.alumni_id = ?
        ORDER BY mr.created_at DESC
    ";

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new Exception("Database query preparation failed.");
    }

    $stmt->bind_param("s", $alumniId);

    $stmt->execute();

    $result = $stmt->get_result();

    $requests = [];

    while ($row = $result->fetch_assoc()) {

        $requests[] = [
            "id" => (int) $row["id"],
            "student_id" => $row["student_id"],
            "alumni_id" => $row["alumni_id"],
            "student_name" => $row["student_name"],
            "message" => $row["message"],
            "status" => $row["status"],
            "created_at" => $row["created_at"],

            // AI review information.
            "ai_review_status" => $row["ai_review_status"],
            "ai_review_score" => $row["ai_review_score"] !== null
                ? (int) $row["ai_review_score"]
                : null,
            "ai_review_reason" => $row["ai_review_reason"]
        ];
    }

    $stmt->close();

    sendResponse(200, [
        "success" => true,
        "message" => "Incoming requests retrieved successfully.",
        "requests" => $requests
    ]);

} catch (Throwable $e) {

    error_log(
        "Incoming requests error: " . $e->getMessage()
    );

    sendResponse(500, [
        "success" => false,
        "message" => "Unable to retrieve incoming requests."
    ]);
}

?>
