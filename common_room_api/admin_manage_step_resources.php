
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once "auth.php";

$method = $_SERVER["REQUEST_METHOD"];

try {
    $user = authenticateUser($conn);
    requireRole($user, ["admin"]);

    if ($method === "GET") {

        $stepId = (int)($_GET["step_id"] ?? 0);

        if ($stepId <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Valid step ID is required."
            ]);
            exit;
        }

        $stmt = $conn->prepare(
            "SELECT id, step_id, title, resource_type,
                    url, description, created_at
             FROM step_resources
             WHERE step_id = ?
             ORDER BY id ASC"
        );

        $stmt->bind_param("i", $stepId);
        $stmt->execute();

        $result = $stmt->get_result();
        $resources = [];

        while ($row = $result->fetch_assoc()) {
            $resources[] = $row;
        }

        $stmt->close();

        echo json_encode([
            "success" => true,
            "resources" => $resources
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

        $stepId = (int)($data["step_id"] ?? 0);
        $title = trim($data["title"] ?? "");
        $resourceType = strtolower(
            trim($data["resource_type"] ?? "tutorial")
        );
        $url = trim($data["url"] ?? "");
        $description = trim($data["description"] ?? "");

        $allowedTypes = [
            "course",
            "youtube",
            "tutorial",
            "documentation",
            "project",
            "other"
        ];

        if (
            $stepId <= 0 ||
            $title === "" ||
            mb_strlen($title) > 200 ||
            $url === "" ||
            strlen($url) > 1000 ||
            !filter_var($url, FILTER_VALIDATE_URL) ||
            !in_array(
                strtolower(parse_url($url, PHP_URL_SCHEME) ?? ""),
                ["http", "https"],
                true
            ) ||
            !in_array($resourceType, $allowedTypes, true)
        ) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Please provide a valid step, title, resource type and HTTP/HTTPS URL."
            ]);
            exit;
        }

        // Confirm that the roadmap step exists.
        $check = $conn->prepare(
            "SELECT id FROM roadmap_steps WHERE id = ? LIMIT 1"
        );

        $check->bind_param("i", $stepId);
        $check->execute();

        $step = $check->get_result()->fetch_assoc();
        $check->close();

        if (!$step) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Roadmap step not found."
            ]);
            exit;
        }

        if ($method === "POST") {

            $stmt = $conn->prepare(
                "INSERT INTO step_resources
                 (step_id, title, resource_type, url, description)
                 VALUES (?, ?, ?, ?, ?)"
            );

            $stmt->bind_param(
                "issss",
                $stepId,
                $title,
                $resourceType,
                $url,
                $description
            );

            $stmt->execute();
            $resourceId = $conn->insert_id;
            $stmt->close();

            http_response_code(201);

            echo json_encode([
                "success" => true,
                "message" => "Learning resource added successfully.",
                "resource_id" => $resourceId
            ]);

        } else {

            $resourceId = (int)($data["resource_id"] ?? 0);

            if ($resourceId <= 0) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "Valid resource ID is required."
                ]);
                exit;
            }

            $stmt = $conn->prepare(
                "UPDATE step_resources
                 SET step_id = ?,
                     title = ?,
                     resource_type = ?,
                     url = ?,
                     description = ?
                 WHERE id = ?"
            );

            $stmt->bind_param(
                "issssi",
                $stepId,
                $title,
                $resourceType,
                $url,
                $description,
                $resourceId
            );

            $stmt->execute();
            $stmt->close();

            echo json_encode([
                "success" => true,
                "message" => "Learning resource update request completed.",
                "resource_id" => $resourceId
            ]);
        }

    } elseif ($method === "DELETE") {

        $data = json_decode(file_get_contents("php://input"), true);
        $resourceId = (int)($data["resource_id"] ?? 0);

        if ($resourceId <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "Valid resource ID is required."
            ]);
            exit;
        }

        $stmt = $conn->prepare(
            "DELETE FROM step_resources WHERE id = ?"
        );

        $stmt->bind_param("i", $resourceId);
        $stmt->execute();

        $deleted = $stmt->affected_rows;
        $stmt->close();

        if ($deleted === 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Learning resource not found."
            ]);
            exit;
        }

        echo json_encode([
            "success" => true,
            "message" => "Learning resource deleted successfully."
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

    error_log("Roadmap resources error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not manage learning resources."
    ]);
}

$conn->close();

?>
