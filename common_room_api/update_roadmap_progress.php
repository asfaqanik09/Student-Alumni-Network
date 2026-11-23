
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
    $user = authenticateUser($conn);
    requireRole($user, ["student"]);

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid JSON data."
        ]);
        exit;
    }

    $stepId = filter_var(
        $data["step_id"] ?? null,
        FILTER_VALIDATE_INT
    );

    $isCompleted = $data["is_completed"] ?? null;

    if (!$stepId || $stepId <= 0 ||
        !in_array($isCompleted, [true, false, 0, 1, "0", "1"], true)) {

        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Valid step_id and is_completed are required."
        ]);
        exit;
    }

    $isCompleted = (int)$isCompleted;

    // Verify that this step belongs to a published roadmap.
    $checkStmt = $conn->prepare(
        "SELECT s.id
         FROM roadmap_steps s
         INNER JOIN career_roadmaps r
            ON r.id = s.roadmap_id
         WHERE s.id = ? AND r.is_published = 1
         LIMIT 1"
    );

    $checkStmt->bind_param("i", $stepId);
    $checkStmt->execute();

    $step = $checkStmt->get_result()->fetch_assoc();
    $checkStmt->close();

    if (!$step) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Learning step not found."
        ]);
        exit;
    }

    // Insert or update only this student's progress.
    if ($isCompleted === 1) {

        $stmt = $conn->prepare(
            "INSERT INTO student_roadmap_progress
                (user_id, step_id, is_completed, completed_at)
             VALUES (?, ?, 1, NOW())
             ON DUPLICATE KEY UPDATE
                is_completed = 1,
                completed_at = NOW(),
                updated_at = NOW()"
        );

    } else {

        $stmt = $conn->prepare(
            "INSERT INTO student_roadmap_progress
                (user_id, step_id, is_completed, completed_at)
             VALUES (?, ?, 0, NULL)
             ON DUPLICATE KEY UPDATE
                is_completed = 0,
                completed_at = NULL,
                updated_at = NOW()"
        );
    }

    $stmt->bind_param("ii", $user["id"], $stepId);
    $stmt->execute();
    $stmt->close();

    // Calculate progress for the roadmap containing this step.
    $progressStmt = $conn->prepare(
        "SELECT
            COUNT(s.id) AS total_steps,
            SUM(
                CASE WHEN p.is_completed = 1 THEN 1 ELSE 0 END
            ) AS completed_steps
         FROM roadmap_steps s
         INNER JOIN career_roadmaps r
            ON r.id = s.roadmap_id
         LEFT JOIN student_roadmap_progress p
            ON p.step_id = s.id AND p.user_id = ?
         WHERE r.id = (
            SELECT roadmap_id
            FROM roadmap_steps
            WHERE id = ?
         )
         AND r.is_published = 1"
    );

    $progressStmt->bind_param("ii", $user["id"], $stepId);
    $progressStmt->execute();

    $progress = $progressStmt->get_result()->fetch_assoc();
    $progressStmt->close();

    $totalSteps = (int)$progress["total_steps"];
    $completedSteps = (int)$progress["completed_steps"];

    $percentage = $totalSteps > 0
        ? round(($completedSteps / $totalSteps) * 100, 2)
        : 0;

    echo json_encode([
        "success" => true,
        "message" => $isCompleted
            ? "Step marked as completed."
            : "Step marked as incomplete.",
        "step_id" => (int)$stepId,
        "is_completed" => (bool)$isCompleted,
        "total_steps" => $totalSteps,
        "completed_steps" => $completedSteps,
        "progress_percentage" => $percentage
    ]);

} catch (Throwable $e) {

    error_log("Roadmap progress error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not update roadmap progress."
    ]);
}

$conn->close();

?>
