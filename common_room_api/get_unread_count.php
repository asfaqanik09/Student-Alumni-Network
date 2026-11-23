
<?php
header("Content-Type: application/json");
require_once "db_connect.php";

try {
    $userId = $_GET["user_id"] ?? "";

    if (empty($userId)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "User ID is required."
        ]);
        exit;
    }

    $stmt = $conn->prepare(
        "SELECT COUNT(*) AS unread_count
         FROM messages
         WHERE receiver_id = ? AND is_read = 0"
    );

    $stmt->bind_param("s", $userId);
    $stmt->execute();

    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    $stmt->close();

    echo json_encode([
        "success" => true,
        "unread_count" => (int) $row["unread_count"]
    ]);

} catch (Throwable $e) {
    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Unable to count unread messages."
    ]);
}
?>
