
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once "auth.php";

$method = $_SERVER["REQUEST_METHOD"];

try {
    $user = authenticateUser($conn);
    requireRole($user, ["admin"]);

    if ($method === "GET") {
        $roadmapId = (int)($_GET["roadmap_id"] ?? 0);

        if ($roadmapId <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Valid roadmap ID is required."
            ]);
            exit;
        }

        $stmt = $conn->prepare(
            "SELECT id, roadmap_id, title, description,
                    step_order, created_at
             FROM roadmap_steps
             WHERE roadmap_id = ?
             ORDER BY step_order ASC, id ASC"
        );

        $stmt->bind_param("i", $roadmapId);
        $stmt->execute();

        $result = $stmt->get_result();
        $steps = [];

        while ($row = $result->fetch_assoc()) {
            $steps[] = $row;
        }

        $stmt->close();

        echo json_encode([
            "success" => true,
            "steps" => $steps
        ]);

    } elseif ($method === "POST" || $method === "PUT") {

        $data = json_decode(file_get_contents("php://input"), true);

        if (!is_array($data)) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Invalid request data."
            ]);
            exit;
        }

        $roadmapId = (int)($data["roadmap_id"] ?? 0);
        $title = trim($data["title"] ?? "");
        $description = trim($data["description"] ?? "");
        $stepOrder = (int)($data["step_order"] ?? 1);

        if (
            $roadmapId <= 0 ||
            $title === "" ||
            mb_strlen($title) > 200 ||
            $stepOrder < 1
        ) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Valid roadmap, title and step order are required."
            ]);
            exit;
        }

        // Confirm the roadmap exists.
        $check = $conn->prepare(
            "SELECT id FROM career_roadmaps WHERE id = ? LIMIT 1"
        );

        $check->bind_param("i", $roadmapId);
        $check->execute();

        $roadmap = $check->get_result()->fetch_assoc();
        $check->close();

        if (!$roadmap) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Career roadmap not found."
            ]);
            exit;
        }

        if ($method === "POST") {

            $stmt = $conn->prepare(
                "INSERT INTO roadmap_steps
                 (roadmap_id, title, description, step_order)
                 VALUES (?, ?, ?, ?)"
            );

            $stmt->bind_param(
                "issi",
                $roadmapId,
                $title,
                $description,
                $stepOrder
            );

            $stmt->execute();
            $stepId = $conn->insert_id;
            $stmt->close();

            http_response_code(201);

            echo json_encode([
                "success" => true,
                "message" => "Roadmap step created successfully.",
                "step_id" => $stepId
            ]);

        } else {

            $stepId = (int)($data["step_id"] ?? 0);

            if ($stepId <= 0) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "Valid step ID is required."
                ]);
                exit;
            }

            $stmt = $conn->prepare(
                "UPDATE roadmap_steps
                 SET roadmap_id = ?,
                     title = ?,
                     description = ?,
                     step_order = ?
                 WHERE id = ?"
            );

            $stmt->bind_param(
                "issii",
                $roadmapId,
                $title,
                $description,
                $stepOrder,
                $stepId
            );

            $stmt->execute();
            $stmt->close();

            echo json_encode([
                "success" => true,
                "message" => "Roadmap step update request completed.",
                "step_id" => $stepId
            ]);
        }

    } elseif ($method === "DELETE") {

        $data = json_decode(file_get_contents("php://input"), true);
        $stepId = (int)($data["step_id"] ?? 0);

        if ($stepId <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Valid step ID is required."
            ]);
            exit;
        }

        $stmt = $conn->prepare(
            "DELETE FROM roadmap_steps WHERE id = ?"
        );

        $stmt->bind_param("i", $stepId);
        $stmt->execute();

        $deleted = $stmt->affected_rows;
        $stmt->close();

        if ($deleted === 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Roadmap step not found."
            ]);
            exit;
        }

        echo json_encode([
            "success" => true,
            "message" => "Roadmap step deleted successfully."
        ]);

    } else {

        header("Allow: GET, POST, PUT, DELETE");
        http_response_code(405);

        echo json_encode([
            "success" => false,
            "message" => "Method not allowed."
        ]);
    }

} catch (Throwable $e) {

    error_log("Roadmap steps error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not manage roadmap steps."
    ]);
}

$conn->close();

?>
