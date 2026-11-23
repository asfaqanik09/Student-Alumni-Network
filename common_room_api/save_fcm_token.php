
<?php

header("Content-Type: application/json");

require_once "db_connect.php";
require_once "auth.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);

    echo json_encode([
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);
    exit;
}

$user = authenticateUser($conn);

$data = json_decode(file_get_contents("php://input"), true);

$fcmToken = trim($data["fcm_token"] ?? "");
$deviceType = trim($data["device_type"] ?? "android");

if ($fcmToken === "") {
    http_response_code(400);

    echo json_encode([
        "success" => false,
        "message" => "FCM token is required."
    ]);
    exit;
}

if (strlen($fcmToken) > 4096) {
    http_response_code(400);

    echo json_encode([
        "success" => false,
        "message" => "Invalid FCM token."
    ]);
    exit;
}

if (!in_array($deviceType, ["android", "ios", "web"], true)) {
    $deviceType = "android";
}

$userId = $user["id"];

$stmt = $conn->prepare(
    "INSERT INTO fcm_tokens
        (user_id, fcm_token, device_type)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE
        user_id = VALUES(user_id),
        device_type = VALUES(device_type),
        updated_at = CURRENT_TIMESTAMP"
);

$stmt->bind_param("sss", $userId, $fcmToken, $deviceType);

if ($stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => "FCM token saved successfully."
    ]);
} else {
    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Failed to save FCM token."
    ]);
}

$stmt->close();
$conn->close();

?>
