
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . "/auth.php";

if ($_SERVER["REQUEST_METHOD"] !== "GET") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only GET requests are allowed."
    ]);
    exit;
}

try {
    // Verify the logged-in student.
    $user = authenticateUser($conn);
    requireRole($user, ["student"]);

    // Use the authenticated user's ID, not a URL parameter.
    $currentUserId = $user["id"];

    $sql = "
        SELECT
            u.id AS user_id,
            u.name,
            ap.graduation_year,
            ap.current_job,
            ap.company,
            ap.industry,
            ap.help_text,
            ap.bio
        FROM alumni_profiles ap
        INNER JOIN users u ON u.id = ap.user_id
        WHERE u.role = 'alumni'
          AND u.id != ?
        ORDER BY u.name ASC
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $currentUserId);
    $stmt->execute();

    $result = $stmt->get_result();
    $alumni = [];

    while ($row = $result->fetch_assoc()) {
        $alumni[] = [
            "user_id" => $row["user_id"],
            "name" => $row["name"],
            "graduation_year" => (int)$row["graduation_year"],
            "current_job" => $row["current_job"],
            "company" => $row["company"],
            "industry" => $row["industry"],
            "help_text" => $row["help_text"] ?? "",
            "bio" => $row["bio"] ?? ""
        ];
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "message" => "Alumni retrieved successfully.",
        "alumni" => $alumni
    ], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);

} catch (Throwable $e) {
    error_log("Get alumni error: " . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Unable to retrieve alumni profiles."
    ]);
}
?>
