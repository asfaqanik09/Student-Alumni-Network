
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

    // Only alumni can submit seminar proposals.
    requireRole($user, ["alumni"]);

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid request data."
        ]);
        exit;
    }

    $title = trim($data["title"] ?? "");
    $description = trim($data["description"] ?? "");
    $scheduledAt = trim($data["scheduled_at"] ?? "");
    $duration = (int)($data["duration_minutes"] ?? 60);
    $eventType = strtolower(trim($data["event_type"] ?? "online"));
    $location = trim($data["location"] ?? "");

    // Validate required fields.
    if (
        $title === "" ||
        $description === "" ||
        $scheduledAt === ""
    ) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Please provide the title, description, and date."
        ]);
        exit;
    }

    if (mb_strlen($title) > 200) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "The seminar title is too long."
        ]);
        exit;
    }

    // Validate event type.
    if (!in_array($eventType, ["online", "physical"], true)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Event type must be online or physical."
        ]);
        exit;
    }

    // Physical events must have a location.
    if ($eventType === "physical" && $location === "") {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Please provide the physical event location."
        ]);
        exit;
    }

    if ($eventType === "online") {
        $location = null;
    }

    // Validate duration.
    if ($duration < 15 || $duration > 1440) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Duration must be between 15 and 1440 minutes."
        ]);
        exit;
    }

    // Accept YYYY-MM-DD HH:MM:SS or YYYY-MM-DDTHH:MM:SS.
    $scheduledAt = str_replace("T", " ", $scheduledAt);

    $date = DateTime::createFromFormat(
        "!Y-m-d H:i:s",
        $scheduledAt
    );

    $dateErrors = DateTime::getLastErrors();

    if (
        !$date ||
        ($dateErrors !== false &&
        ($dateErrors["warning_count"] > 0 ||
         $dateErrors["error_count"] > 0)) ||
        $date->format("Y-m-d H:i:s") !== $scheduledAt
    ) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid date format. Use YYYY-MM-DD HH:MM:SS."
        ]);
        exit;
    }

    // Seminar must be scheduled in the future.
    if ($date->getTimestamp() <= time()) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Please select a future seminar date and time."
        ]);
        exit;
    }

    // Use the authenticated user's ID, never an ID from Flutter.
    $createdBy = $user["id"];

    $stmt = $conn->prepare(
        "INSERT INTO seminars (
            title,
            description,
            scheduled_at,
            duration_minutes,
            event_type,
            location,
            created_by,
            status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')"
    );

    $stmt->bind_param(
        "sssisss",
        $title,
        $description,
        $scheduledAt,
        $duration,
        $eventType,
        $location,
        $createdBy
    );

    $stmt->execute();

    $seminarId = $conn->insert_id;

    $stmt->close();

    http_response_code(201);

    echo json_encode([
        "success" => true,
        "message" => "Seminar proposal submitted successfully. Waiting for admin approval.",
        "seminar_id" => $seminarId,
        "status" => "pending"
    ]);

} catch (Throwable $e) {

    error_log("Submit seminar error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not submit the seminar proposal."
    ]);
}

$conn->close();

?>
