
<?php

header("Content-Type: application/json; charset=UTF-8");

// Required backend files
require_once __DIR__ . "/db_connect.php";
require_once __DIR__ . "/auth.php";

require_once "C:/xampp/private/firebase_access_token.php";

$config = require "C:/xampp/private/firebase_config.php";

// Send JSON response
function sendJsonResponse($statusCode, $data)
{
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

// Send notification using Firebase HTTP v1 API
function sendPushNotification($fcmToken, $title, $body)
{
    global $config;

    $accessToken = getFirebaseAccessToken();
    $projectId = $config["project_id"];

    $url = "https://fcm.googleapis.com/v1/projects/"
         . $projectId
         . "/messages:send";

    $message = [
        "message" => [
            "token" => $fcmToken,
            "notification" => [
                "title" => $title,
                "body" => $body
            ],
            "android" => [
                "priority" => "high"
            ]
        ]
    ];

    $ch = curl_init($url);

    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Authorization: Bearer " . $accessToken,
            "Content-Type: application/json"
        ],
        CURLOPT_POSTFIELDS => json_encode($message),
        CURLOPT_TIMEOUT => 30
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    if ($response === false) {
        $error = curl_error($ch);
        curl_close($ch);

        throw new Exception("FCM connection failed: " . $error);
    }

    curl_close($ch);

    return [
        "http_code" => $httpCode,
        "response" => json_decode($response, true)
    ];
}

// Main endpoint
try {

    // Allow POST only
    if ($_SERVER["REQUEST_METHOD"] !== "POST") {
        sendJsonResponse(405, [
            "success" => false,
            "message" => "Only POST requests are allowed."
        ]);
    }

    // Authenticate logged-in user
    $user = authenticateUser($conn);

    // Only administrators can send notifications
    requireRole($user, ["admin"]);

    // Read request data
    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        sendJsonResponse(400, [
            "success" => false,
            "message" => "Invalid JSON request."
        ]);
    }

    $title = trim($data["title"] ?? "");
    $body = trim($data["body"] ?? "");

    // Support both new and older request formats
    $recipientType = strtolower(
        trim($data["recipient_type"] ?? "")
    );

    $targetUserId = trim($data["user_id"] ?? "");

    // Backward compatibility:
    // If recipient_type is missing but user_id exists,
    // treat the request as an individual notification.
    if ($recipientType === "" && $targetUserId !== "") {
        $recipientType = "user";
    }

    // Validate required fields
    if ($title === "" || $body === "") {
        sendJsonResponse(400, [
            "success" => false,
            "message" => "Notification title and body are required."
        ]);
    }

    // Validate recipient type
    if (!in_array($recipientType, ["all", "user"], true)) {
        sendJsonResponse(400, [
            "success" => false,
            "message" => "Recipient type must be all or user."
        ]);
    }

    // Individual notifications require a user ID
    if ($recipientType === "user" && $targetUserId === "") {
        sendJsonResponse(400, [
            "success" => false,
            "message" => "user_id is required for individual notifications."
        ]);
    }

    // Validate notification length
    if (strlen($title) > 200 || strlen($body) > 2000) {
        sendJsonResponse(400, [
            "success" => false,
            "message" => "Notification title or body is too long."
        ]);
    }

    // Get FCM tokens according to recipient type
    if ($recipientType === "all") {

        // Get every registered device token
        $sql = "
            SELECT DISTINCT fcm_token
            FROM fcm_tokens
            WHERE fcm_token IS NOT NULL
              AND fcm_token <> ''
        ";

        $result = $conn->query($sql);

        if (!$result) {
            throw new Exception("Could not retrieve registered devices.");
        }

    } else {

        // Get devices belonging to the selected user
        $stmt = $conn->prepare(
            "SELECT DISTINCT fcm_token
             FROM fcm_tokens
             WHERE user_id = ?
               AND fcm_token IS NOT NULL
               AND fcm_token <> ''"
        );

        if (!$stmt) {
            throw new Exception("Database query preparation failed.");
        }

        $stmt->bind_param("s", $targetUserId);
        $stmt->execute();

        $result = $stmt->get_result();
    }

    // Collect device tokens
    $tokens = [];

    while ($row = $result->fetch_assoc()) {
        $tokens[] = $row["fcm_token"];
    }

    // Close individual-user statement
    if (isset($stmt)) {
        $stmt->close();
    }

    // No registered devices
    if (empty($tokens)) {

        $message = $recipientType === "all"
            ? "No registered devices were found."
            : "No registered device found for this user.";

        sendJsonResponse(404, [
            "success" => false,
            "message" => $message
        ]);
    }

    // Send notifications
    $sent = 0;
    $failed = 0;
    $errors = [];

    foreach ($tokens as $fcmToken) {

        try {

            $pushResult = sendPushNotification(
                $fcmToken,
                $title,
                $body
            );

            if (
                $pushResult["http_code"] >= 200 &&
                $pushResult["http_code"] < 300
            ) {
                $sent++;
            } else {
                $failed++;

                $errors[] = [
                    "http_code" => $pushResult["http_code"],
                    "response" => $pushResult["response"]
                ];
            }

        } catch (Throwable $e) {

            $failed++;

            $errors[] = [
                "message" => $e->getMessage()
            ];
        }
    }

    // Return final result
    sendJsonResponse(200, [
        "success" => ($sent > 0 && $failed === 0),
        "message" => "Notification sending process completed.",
        "recipient_type" => $recipientType,
        "total_devices" => count($tokens),
        "sent" => $sent,
        "failed" => $failed,
        "errors" => $errors
    ]);

} catch (Throwable $e) {

    error_log("FCM notification error: " . $e->getMessage());

    sendJsonResponse(500, [
        "success" => false,
        "message" => "Notification sending failed. Check the PHP error log."
    ]);

} finally {

    if (isset($conn) && $conn instanceof mysqli) {
        $conn->close();
    }
}
