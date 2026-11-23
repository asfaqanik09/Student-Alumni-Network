
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once "auth.php";

$method = $_SERVER["REQUEST_METHOD"];

try {
    $user = authenticateUser($conn);
    requireRole($user, ["admin"]);

    if ($method === "GET") {
        $stmt = $conn->prepare(
            "SELECT id, title, description, icon,
                    is_published, created_at, updated_at
             FROM career_roadmaps
             ORDER BY created_at DESC"
        );

        $stmt->execute();
        $result = $stmt->get_result();

        $roadmaps = [];

        while ($row = $result->fetch_assoc()) {
            $row["is_published"] = (bool)$row["is_published"];
            $roadmaps[] = $row;
        }

        $stmt->close();

        echo json_encode([
            "success" => true,
            "roadmaps" => $roadmaps
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

        $title = trim($data["title"] ?? "");
        $description = trim($data["description"] ?? "");
        $icon = trim($data["icon"] ?? "");
        $isPublished = !empty($data["is_published"]) ? 1 : 0;

        if ($title === "" || mb_strlen($title) > 200) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "A valid roadmap title is required."
            ]);
            exit;
        }

        if (mb_strlen($icon) > 100) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "The icon value is too long."
            ]);
            exit;
        }

        if ($method === "POST") {

            $stmt = $conn->prepare(
                "INSERT INTO career_roadmaps
                 (title, description, icon, is_published)
                 VALUES (?, ?, ?, ?)"
            );

            $stmt->bind_param(
                "sssi",
                $title,
                $description,
                $icon,
                $isPublished
            );

            $stmt->execute();
            $roadmapId = $conn->insert_id;
            $stmt->close();

            http_response_code(201);

            echo json_encode([
                "success" => true,
                "message" => "Career roadmap created successfully.",
                "roadmap_id" => $roadmapId
            ]);

        } else {

            $roadmapId = (int)($data["roadmap_id"] ?? 0);

            if ($roadmapId <= 0) {
                http_response_code(400);
                echo json_encode([
                    "success" => false,
                    "message" => "A valid roadmap ID is required."
                ]);
                exit;
            }

            $stmt = $conn->prepare(
                "UPDATE career_roadmaps
                 SET title = ?,
                     description = ?,
                     icon = ?,
                     is_published = ?
                 WHERE id = ?"
            );

            $stmt->bind_param(
                "sssii",
                $title,
                $description,
                $icon,
                $isPublished,
                $roadmapId
            );

            $stmt->execute();
            $updated = $stmt->affected_rows;
            $stmt->close();

            echo json_encode([
                "success" => true,
                "message" => "Roadmap update request completed.",
                "roadmap_id" => $roadmapId,
                "changed" => $updated > 0
            ]);
        }

    } elseif ($method === "DELETE") {

        $data = json_decode(file_get_contents("php://input"), true);
        $roadmapId = (int)($data["roadmap_id"] ?? 0);

        if ($roadmapId <= 0) {
            http_response_code(400);
            echo json_encode([
                "success" => false,
                "message" => "A valid roadmap ID is required."
            ]);
            exit;
        }

        $stmt = $conn->prepare(
            "DELETE FROM career_roadmaps WHERE id = ?"
        );

        $stmt->bind_param("i", $roadmapId);
        $stmt->execute();

        $deleted = $stmt->affected_rows;
        $stmt->close();

        if ($deleted === 0) {
            http_response_code(404);
            echo json_encode([
                "success" => false,
                "message" => "Roadmap not found."
            ]);
            exit;
        }

        echo json_encode([
            "success" => true,
            "message" => "Roadmap deleted successfully."
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

    error_log("Roadmap management error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not manage career roadmaps."
    ]);
}

$conn->close();

?>
