
<?php
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . "/db_connect.php";

if ($_SERVER["REQUEST_METHOD"] !== "GET") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only GET requests are allowed."
    ]);
    exit;
}

$userId = trim($_GET["user_id"] ?? "");

if ($userId === "") {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "User ID is required."
    ]);
    exit;
}

try {
    $stmt = $conn->prepare(
        "SELECT graduation_year, current_job, company,
                industry, help_text, bio, willing_to_mentor
         FROM alumni_profiles
         WHERE user_id = ?
         LIMIT 1"
    );

    $stmt->bind_param("s", $userId);
    $stmt->execute();

    $result = $stmt->get_result();
    $profile = $result->fetch_assoc();

    $stmt->close();

    if (!$profile) {
        echo json_encode([
            "success" => true,
            "exists" => false,
            "message" => "No saved alumni profile found."
        ]);
        exit;
    }

    echo json_encode([
        "success" => true,
        "exists" => true,
        "profile" => $profile
    ]);

} catch (Throwable $e) {
    error_log("Get alumni profile error: " . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Could not load alumni profile."
    ]);
}

$conn->close();
?>
