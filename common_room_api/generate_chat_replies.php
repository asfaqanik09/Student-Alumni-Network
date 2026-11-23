
<?php
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . "/auth.php";

function sendResponse($status, $data) {
    http_response_code($status);
    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
    );
    exit;
}

// Only POST requests are allowed.
if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    sendResponse(405, [
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);
}

// Authenticate the logged-in user.
$user = authenticateUser($conn);
requireRole($user, ["student", "alumni"]);

$userId = (string)$user["id"];

// Read request data.
$data = json_decode(file_get_contents("php://input"), true);

if (!is_array($data)) {
    sendResponse(400, [
        "success" => false,
        "message" => "Invalid request data."
    ]);
}

$requestId = trim((string)($data["request_id"] ?? ""));

if ($requestId === "") {
    sendResponse(400, [
        "success" => false,
        "message" => "Request ID is required."
    ]);
}

try {

    // Step 1: Verify the accepted mentorship request.
    $stmt = $conn->prepare(
        "SELECT student_id, alumni_id, status
         FROM mentorship_requests
         WHERE id = ?
         LIMIT 1"
    );

    $stmt->bind_param("s", $requestId);
    $stmt->execute();

    $request = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$request) {
        sendResponse(404, [
            "success" => false,
            "message" => "Mentorship request was not found."
        ]);
    }

    if ($request["status"] !== "accepted") {
        sendResponse(403, [
            "success" => false,
            "message" => "Chat is available only after the request is accepted."
        ]);
    }

    // Confirm that the logged-in user belongs to this conversation.
    if (
        (string)$request["student_id"] !== $userId &&
        (string)$request["alumni_id"] !== $userId
    ) {
        sendResponse(403, [
            "success" => false,
            "message" => "You are not a participant in this conversation."
        ]);
    }

    // Step 2: Load the latest 15 messages.
    $stmt = $conn->prepare(
        "SELECT sender_id, message_text, created_at
         FROM messages
         WHERE request_id = ?
         ORDER BY id DESC
         LIMIT 15"
    );

    $stmt->bind_param("s", $requestId);
    $stmt->execute();

    $result = $stmt->get_result();

    $messages = [];

    while ($row = $result->fetch_assoc()) {
        $messages[] = [
            "sender" =>
                ((string)$row["sender_id"] === $userId)
                ? "current_user"
                : "other_person",
            "message" => $row["message_text"],
            "time" => $row["created_at"]
        ];
    }

    $stmt->close();

    if (count($messages) === 0) {
        sendResponse(400, [
            "success" => false,
            "message" => "There are no messages to generate replies for."
        ]);
    }

    // Reverse messages to chronological order.
    $messages = array_reverse($messages);

    // Step 3: Load the private Gemini configuration.
    $configPath = "C:/xampp/private/gemini_config.php";

    if (!is_file($configPath)) {
        throw new RuntimeException(
            "Gemini configuration file is missing."
        );
    }

    $config = require $configPath;

    $apiKey = $config["api_key"] ?? "";
    $model = $config["model"] ?? "";

    if ($apiKey === "" || $model === "") {
        throw new RuntimeException(
            "Gemini configuration is incomplete."
        );
    }

    // Step 4: Prepare the conversation prompt.
    $conversation = json_encode(
        $messages,
        JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
    );

    $prompt =
        "You are an assistant helping a user reply naturally "
        . "in a university alumni mentorship conversation. "
        . "Generate up to 3 short, useful reply suggestions "
        . "for the current user based on the conversation. "
        . "The current user's messages are marked current_user. "
        . "The other person's messages are marked other_person. "
        . "Write replies from the current user's perspective. "
        . "Make suggestions relevant to the latest messages. "
        . "Use a polite, natural and friendly tone. "
        . "Do not invent facts, promises, experiences or plans. "
        . "Avoid repeating messages already sent. "
        . "Each suggestion must be one short message. "
        . "Return ONLY a JSON object in this format: "
        . '{"suggestions":["Reply one","Reply two","Reply three"]}'
        . "\n\nConversation history:\n"
        . $conversation;

    // Step 5: Call Gemini.
    $url =
        "https://generativelanguage.googleapis.com/v1beta/models/"
        . rawurlencode($model)
        . ":generateContent";

    $requestBody = [
        "contents" => [
            [
                "role" => "user",
                "parts" => [
                    ["text" => $prompt]
                ]
            ]
        ],
        "generationConfig" => [
            "temperature" => 0.7,
            "responseMimeType" => "application/json"
        ]
    ];

    $ch = curl_init($url);

    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Content-Type: application/json",
            "x-goog-api-key: " . $apiKey
        ],
        CURLOPT_POSTFIELDS => json_encode($requestBody),
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 60
    ]);

    $rawResponse = curl_exec($ch);
    $curlError = curl_error($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    curl_close($ch);

    if ($rawResponse === false || $httpCode !== 200) {
        error_log(
            "Gemini chat replies failed. HTTP: "
            . $httpCode . " cURL: " . $curlError
        );

        sendResponse(502, [
            "success" => false,
            "message" => "AI reply suggestions are temporarily unavailable."
        ]);
    }

    // Step 6: Parse Gemini's response.
    $geminiResponse = json_decode($rawResponse, true);

    $responseText =
        $geminiResponse["candidates"][0]["content"]["parts"][0]["text"]
        ?? "";

    $aiResult = json_decode($responseText, true);

    if (
        !is_array($aiResult) ||
        !isset($aiResult["suggestions"]) ||
        !is_array($aiResult["suggestions"])
    ) {
        throw new RuntimeException(
            "Gemini returned invalid suggestions."
        );
    }

    // Step 7: Validate and limit suggestions.
    $suggestions = [];

    foreach ($aiResult["suggestions"] as $suggestion) {
        if (!is_string($suggestion)) {
            continue;
        }

        $suggestion = trim($suggestion);

        if ($suggestion === "") {
            continue;
        }

        if (mb_strlen($suggestion, "UTF-8") > 300) {
            $suggestion = mb_substr(
                $suggestion,
                0,
                300,
                "UTF-8"
            );
        }

        $suggestions[] = $suggestion;

        if (count($suggestions) >= 3) {
            break;
        }
    }

    if (count($suggestions) === 0) {
        throw new RuntimeException(
            "Gemini returned no usable suggestions."
        );
    }

    // Step 8: Return suggestions to Flutter.
    sendResponse(200, [
        "success" => true,
        "message" => "Reply suggestions generated successfully.",
        "suggestions" => $suggestions
    ]);

} catch (Throwable $e) {

    error_log(
        "Generate chat replies error: " . $e->getMessage()
    );

    sendResponse(500, [
        "success" => false,
        "message" => "Unable to generate reply suggestions right now."
    ]);
}
