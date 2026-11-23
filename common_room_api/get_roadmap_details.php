
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
    requireRole($user, ["student"]);

    $roadmapId = filter_input(INPUT_GET, "roadmap_id", FILTER_VALIDATE_INT);

    if (!$roadmapId || $roadmapId <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "A valid roadmap_id is required."
        ]);
        exit;
    }

    // Get the published roadmap.
    $stmt = $conn->prepare(
        "SELECT id, title, description, icon
         FROM career_roadmaps
         WHERE id = ? AND is_published = 1
         LIMIT 1"
    );

    $stmt->bind_param("i", $roadmapId);
    $stmt->execute();

    $roadmap = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$roadmap) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Roadmap not found or not published."
        ]);
        exit;
    }

    // Get all steps and the student's completion status.
    $stmt = $conn->prepare(
        "SELECT
            s.id,
            s.title,
            s.description,
            s.step_order,
            COALESCE(p.is_completed, 0) AS is_completed
         FROM roadmap_steps s
         LEFT JOIN student_roadmap_progress p
            ON p.step_id = s.id AND p.user_id = ?
         WHERE s.roadmap_id = ?
         ORDER BY s.step_order ASC, s.id ASC"
    );

    $stmt->bind_param("ii", $user["id"], $roadmapId);
    $stmt->execute();

    $result = $stmt->get_result();

    $steps = [];
    $totalSteps = 0;
    $completedSteps = 0;

    while ($step = $result->fetch_assoc()) {

        $stepId = (int)$step["id"];

        $step["id"] = $stepId;
        $step["step_order"] = (int)$step["step_order"];
        $step["is_completed"] = (bool)$step["is_completed"];

        if ($step["is_completed"]) {
            $completedSteps++;
        }

        $totalSteps++;

        // Get free resources for this step.
        $resourceStmt = $conn->prepare(
            "SELECT
                id,
                title,
                resource_type,
                url,
                description
             FROM step_resources
             WHERE step_id = ?
             ORDER BY id ASC"
        );

        $resourceStmt->bind_param("i", $stepId);
        $resourceStmt->execute();

        $resourceResult = $resourceStmt->get_result();

        $resources = [];

        while ($resource = $resourceResult->fetch_assoc()) {
            $resource["id"] = (int)$resource["id"];
            $resources[] = $resource;
        }

        $resourceStmt->close();

        $step["resources"] = $resources;

        $steps[] = $step;
    }

    $stmt->close();

    $progressPercentage = $totalSteps > 0
        ? round(($completedSteps / $totalSteps) * 100, 2)
        : 0;

    $roadmap["id"] = (int)$roadmap["id"];

    echo json_encode([
        "success" => true,
        "roadmap" => $roadmap,
        "total_steps" => $totalSteps,
        "completed_steps" => $completedSteps,
        "progress_percentage" => $progressPercentage,
        "steps" => $steps
    ]);

} catch (Throwable $e) {

    error_log("Roadmap details error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not load roadmap details."
    ]);
}

$conn->close();

?>
