
<?php
header("Content-Type: application/json");

require_once __DIR__ . "/db_connect.php";
require_once __DIR__ . "/auth.php";

try {
    // Authenticate the logged-in user.
    $user = authenticateUser($conn);
    requireRole($user, ["student", "alumni"]);

    // Get the authenticated user's ID from the database session.
    $userId = (string) $user["id"];

    // Get the conversation ID.
    $requestId = filter_input(INPUT_GET, "request_id", FILTER_VALIDATE_INT);

    if (!$requestId || $requestId <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "A valid request ID is required."
        ]);
        exit;
    }

    // Check whether the conversation exists and is accepted.
    $stmt = $conn->prepare(
        "SELECT student_id, alumni_id, status
         FROM mentorship_requests
         WHERE id = ?"
    );

    $stmt->bind_param("i", $requestId);
    $stmt->execute();

    $request = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // Verify that the authenticated user is a participant.
    if (
        !$request ||
        $request["status"] !== "accepted" ||
        (
            $userId !== (string) $request["student_id"] &&
            $userId !== (string) $request["alumni_id"]
        )
    ) {
        http_response_code(403);
        echo json_encode([
            "success" => false,
            "message" => "You cannot access this conversation."
        ]);
        exit;
    }

    // Mark messages received by this user as read.
    $stmt = $conn->prepare(
        "UPDATE messages
         SET is_read = 1
         WHERE request_id = ? AND receiver_id = ?"
    );

    $stmt->bind_param("is", $requestId, $userId);
    $stmt->execute();
    $stmt->close();

    // Load messages and their AI review information.
    $stmt = $conn->prepare(
        "SELECT
            id,
            sender_id,
            receiver_id,
            message_text,
            is_read,
            created_at,
            ai_review_status,
            ai_review_score,
            ai_review_reason
         FROM messages
         WHERE request_id = ?
         ORDER BY id ASC"
    );

    $stmt->bind_param("i", $requestId);
    $stmt->execute();

    $result = $stmt->get_result();
    $messages = [];

    while ($row = $result->fetch_assoc()) {
        $messages[] = $row;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "messages" => $messages
    ]);

} catch (Throwable $e) {
    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Unable to load messages."
    ]);
}
?>
