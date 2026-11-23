
<?php

header("Content-Type: application/json");

require_once "db_connect.php";

// Only allow POST requests
if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);
    exit;
}

// Read JSON data
$data = json_decode(file_get_contents("php://input"), true);

$user_id = trim($data["user_id"] ?? "");
$graduation_year = $data["graduation_year"] ?? "";
$current_job = trim($data["current_job"] ?? "");
$company = trim($data["company"] ?? "");
$industry = trim($data["industry"] ?? "");
$help_text = trim($data["help_text"] ?? "");
$bio = trim($data["bio"] ?? "");

// Validate required fields
if (
    $user_id === "" ||
    $graduation_year === "" ||
    $current_job === "" ||
    $company === "" ||
    $industry === ""
) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Please complete all required fields."
    ]);
    exit;
}

// Validate graduation year
$graduation_year = filter_var(
    $graduation_year,
    FILTER_VALIDATE_INT
);

if (
    $graduation_year === false ||
    $graduation_year < 1950 ||
    $graduation_year > 2100
) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Please enter a valid graduation year."
    ]);
    exit;
}

try {

    // Check whether the user exists
    $check = $conn->prepare(
        "SELECT id FROM users WHERE id = ?"
    );

    $check->bind_param("s", $user_id);
    $check->execute();

    $result = $check->get_result();

    if ($result->num_rows === 0) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "User account not found."
        ]);
        exit;
    }

    $check->close();

    // Save or update the alumni profile
    $stmt = $conn->prepare(
        "INSERT INTO alumni_profiles
        (
            user_id,
            graduation_year,
            current_job,
            company,
            industry,
            willing_to_mentor,
            help_text,
            bio
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            graduation_year = VALUES(graduation_year),
            current_job = VALUES(current_job),
            company = VALUES(company),
            industry = VALUES(industry),
            willing_to_mentor = VALUES(willing_to_mentor),
            help_text = VALUES(help_text),
            bio = VALUES(bio)"
    );

    $willing_to_mentor = ($help_text !== "") ? 1 : 0;

    $stmt->bind_param(
        "sisssiss",
        $user_id,
        $graduation_year,
        $current_job,
        $company,
        $industry,
        $willing_to_mentor,
        $help_text,
        $bio
    );

    $stmt->execute();
    $stmt->close();

    // Update the user's role
    $roleStmt = $conn->prepare(
        "UPDATE users SET role = 'alumni' WHERE id = ?"
    );

    $roleStmt->bind_param("s", $user_id);
    $roleStmt->execute();
    $roleStmt->close();

    echo json_encode([
        "success" => true,
        "message" => "Alumni profile saved successfully."
    ]);

} catch (Throwable $e) {

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Something went wrong while saving the alumni profile."
    ]);
}

?>
