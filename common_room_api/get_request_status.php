
<?php
header("Content-Type: application/json");

require_once __DIR__ . "/db_connect.php";
require_once __DIR__ . "/auth.php";

try {
    // Authenticate the logged-in user.
    $user = authenticateUser($conn);
    requireRole($user, ["student", "alumni"]);

    $userId = (string) $user["id"];

    $studentId = trim($_GET["student_id"] ?? "");
    $alumniId = trim($_GET["alumni_id"] ?? "");

    if ($studentId === "" || $alumniId === "") {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Student ID and alumni ID are required."
        ]);
        exit;
    }

    // The logged-in user must be the student or alumni
    // involved in this connection.
    if ($userId !== $studentId && $userId !== $alumniId) {
        http_response_code(403);
        echo json_encode([
            "success" => false,
            "message" => "You cannot access this connection."
        ]);
        exit;
    }

    // Retrieve the latest mentorship request.
    $stmt = $conn->prepare(
        "SELECT id, status
         FROM mentorship_requests
         WHERE student_id = ? AND alumni_id = ?
         ORDER BY id DESC
         LIMIT 1"
    );

    $stmt->bind_param("ss", $studentId, $alumniId);
    $stmt->execute();

    $request = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    echo json_encode([
        "success" => true,
        "status" => $request["status"] ?? "none",
        "request_id" => $request ? (int) $request["id"] : null
    ]);

} catch (Throwable $e) {
    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Unable to retrieve request status."
    ]);
}
?>
