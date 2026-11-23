
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once "auth.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);
    exit;
}

try {
    // Verify the logged-in user.
    $user = authenticateUser($conn);

    // Only admins can review proposals.
    requireRole($user, ["admin"]);

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid request data."
        ]);
        exit;
    }

    $seminarId = (int)($data["seminar_id"] ?? 0);
    $status = strtolower(trim($data["status"] ?? ""));
    $meetingLink = trim($data["meeting_link"] ?? "");

    if ($seminarId <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid seminar ID."
        ]);
        exit;
    }

    if (!in_array($status, ["approved", "rejected"], true)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Status must be approved or rejected."
        ]);
        exit;
    }

    // Check that the seminar exists and is still pending.
    $check = $conn->prepare(
        "SELECT id, event_type
         FROM seminars
         WHERE id = ? AND status = 'pending'
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
            "message" => "Pending seminar proposal not found."
        ]);
        exit;
    }

    // Validate an optional meeting link.
    if ($meetingLink !== "") {
        if (
            strlen($meetingLink) > 500 ||
            !filter_var($meetingLink, FILTER_VALIDATE_URL) ||
            !in_array(
                strtolower(parse_url($meetingLink, PHP_URL_SCHEME) ?? ""),
                ["http", "https"],
                true
            )
        ) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Please provide a valid meeting link."
            ]);
            exit;
        }
    }

    if ($status === "rejected") {
        $meetingLink = null;
    }

    // Record the admin who reviewed the proposal.
    if ($status === "approved") {
        $stmt = $conn->prepare(
            "UPDATE seminars
             SET status = 'approved',
                 approved_by = ?,
                 meeting_link = ?,
                 published_at = NOW()
             WHERE id = ? AND status = 'pending'"
        );

        $stmt->bind_param(
            "ssi",
            $user["id"],
            $meetingLink,
            $seminarId
        );
    } else {
        $stmt = $conn->prepare(
            "UPDATE seminars
             SET status = 'rejected',
                 approved_by = ?,
                 meeting_link = NULL,
                 published_at = NULL
             WHERE id = ? AND status = 'pending'"
        );

        $stmt->bind_param(
            "si",
            $user["id"],
            $seminarId
        );
    }

    $stmt->execute();

    if ($stmt->affected_rows !== 1) {
        $stmt->close();

        http_response_code(409);
        echo json_encode([
            "success" => false,
            "message" => "The proposal could not be updated. Please refresh and try again."
        ]);
        exit;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "message" => $status === "approved"
            ? "Seminar approved and published successfully."
            : "Seminar proposal rejected successfully.",
        "seminar_id" => $seminarId,
        "status" => $status
    ]);

} catch (Throwable $e) {

    error_log("Review seminar error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not review the seminar proposal."
    ]);
}

$conn->close();

?>
