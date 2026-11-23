
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
    // Authenticate the logged-in user.
    $user = authenticateUser($conn);

    // Only students can access career roadmaps.
    requireRole($user, ["student"]);

    $stmt = $conn->prepare(
        "SELECT
            r.id,
            r.title,
            r.description,
            r.icon,
            r.created_at,
            COUNT(s.id) AS total_steps
         FROM career_roadmaps r
         LEFT JOIN roadmap_steps s
            ON s.roadmap_id = r.id
         WHERE r.is_published = 1
         GROUP BY
            r.id,
            r.title,
            r.description,
            r.icon,
            r.created_at
         ORDER BY r.created_at ASC"
    );

    $stmt->execute();

    $result = $stmt->get_result();
    $roadmaps = [];

    while ($row = $result->fetch_assoc()) {
        $row["id"] = (int)$row["id"];
        $row["total_steps"] = (int)$row["total_steps"];

        $roadmaps[] = $row;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "total_roadmaps" => count($roadmaps),
        "roadmaps" => $roadmaps
    ]);

} catch (Throwable $e) {

    error_log("Published roadmaps error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not load career roadmaps."
    ]);
}

$conn->close();

?>
