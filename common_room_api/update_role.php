
<?php

header("Content-Type: application/json; charset=UTF-8");

require_once "auth.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);

    echo json_encode([
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);

    exit;
}

try {
    // Authenticate the actual logged-in user.
    $user = authenticateUser($conn);

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        http_response_code(400);

        echo json_encode([
            "success" => false,
            "message" => "Invalid request data."
        ]);

        exit;
    }

    $role = strtolower(trim($data["role"] ?? ""));

    // Only Student and Alumni roles are allowed.
    if (!in_array($role, ["student", "alumni"], true)) {
        http_response_code(400);

        echo json_encode([
            "success" => false,
            "message" => "Invalid role. Choose Student or Alumni."
        ]);

        exit;
    }

    // Never allow an authorized admin account to downgrade itself.
    if (strtolower($user["role"]) === "admin") {
        http_response_code(403);

        echo json_encode([
            "success" => false,
            "message" => "Admin accounts cannot change their role here."
        ]);

        exit;
    }

    // Update only the authenticated user's account.
    $stmt = $conn->prepare(
        "UPDATE users
         SET role = ?
         WHERE id = ?"
    );

    $stmt->bind_param("ss", $role, $user["id"]);
    $stmt->execute();
    $stmt->close();

    echo json_encode([
        "success" => true,
        "message" => "Role saved successfully.",
        "role" => $role
    ]);

} catch (Throwable $e) {

    error_log("Update role error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Something went wrong while updating the role."
    ]);
}

$conn->close();

?>
