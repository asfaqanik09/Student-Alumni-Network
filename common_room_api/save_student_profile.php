
<?php
header("Content-Type: application/json");

require_once "db_connect.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "POST method required."
    ]);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);

$user_id = trim($data["user_id"] ?? "");
$major = trim($data["major"] ?? "");
$grad_year = $data["grad_year_expected"] ?? "";
$career_goal = trim($data["career_goal"] ?? "");

if (
    $user_id === "" ||
    $major === "" ||
    $grad_year === "" ||
    $career_goal === ""
) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Please provide all profile information."
    ]);
    exit;
}

$grad_year = filter_var($grad_year, FILTER_VALIDATE_INT);

if ($grad_year === false || $grad_year < 2000 || $grad_year > 2100) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Enter a valid expected graduation year."
    ]);
    exit;
}

try {
    // Check whether the user exists.
    $check = $conn->prepare(
        "SELECT id FROM users WHERE id = ?"
    );

    $check->bind_param("s", $user_id);
    $check->execute();
    $user = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$user) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "User account not found."
        ]);
        exit;
    }

    // Save or update the student's profile.
    $stmt = $conn->prepare(
        "INSERT INTO student_profiles
         (user_id, major, grad_year_expected, career_goal)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
         major = VALUES(major),
         grad_year_expected = VALUES(grad_year_expected),
         career_goal = VALUES(career_goal)"
    );

    $stmt->bind_param(
        "ssis",
        $user_id,
        $major,
        $grad_year,
        $career_goal
    );

    $stmt->execute();
    $stmt->close();

    // Set the account role to student.
    $roleStmt = $conn->prepare(
        "UPDATE users SET role = 'student' WHERE id = ?"
    );

    $roleStmt->bind_param("s", $user_id);
    $roleStmt->execute();
    $roleStmt->close();

    echo json_encode([
        "success" => true,
        "message" => "Student profile saved successfully."
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Could not save student profile."
    ]);
}
?>
