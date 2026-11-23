
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
    $user = authenticateUser($conn);
    requireRole($user, ["student", "alumni"]);

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid request data."
        ]);
        exit;
    }

    $seminarId = (int)($data["seminar_id"] ?? 0);
    $contactNumber = trim($data["contact_number"] ?? "");

    if ($seminarId <= 0 || $contactNumber === "") {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Seminar ID and contact number are required."
        ]);
        exit;
    }

    if (
        strlen($contactNumber) > 20 ||
        !preg_match('/^[0-9+\-\s()]{7,20}$/', $contactNumber)
    ) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Please enter a valid contact number."
        ]);
        exit;
    }

    // Confirm the seminar is approved and upcoming.
    $check = $conn->prepare(
        "SELECT id
         FROM seminars
         WHERE id = ?
           AND status = 'approved'
           AND scheduled_at >= NOW()
         LIMIT 1"
    );

    $check->bind_param("i", $seminarId);
    $check->execute();

    $seminar = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$seminar) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "This seminar is unavailable for registration."
        ]);
        exit;
    }

    // Get attendee details from the authenticated account.
    $userStmt = $conn->prepare(
        "SELECT name, email
         FROM users
         WHERE id = ?
         LIMIT 1"
    );

    $userStmt->bind_param("s", $user["id"]);
    $userStmt->execute();

    $attendee = $userStmt->get_result()->fetch_assoc();
    $userStmt->close();

    if (!$attendee) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "User account not found."
        ]);
        exit;
    }

    $conn->begin_transaction();

    // Save the contact number to the user's profile.
    $update = $conn->prepare(
        "UPDATE users
         SET contact_number = ?
         WHERE id = ?"
    );

    $update->bind_param(
        "ss",
        $contactNumber,
        $user["id"]
    );

    $update->execute();
    $update->close();

    // Save the registration details.
    $insert = $conn->prepare(
        "INSERT INTO seminar_registrations (
            seminar_id,
            user_id,
            attendee_name,
            attendee_email,
            contact_number
        ) VALUES (?, ?, ?, ?, ?)"
    );

    $insert->bind_param(
        "issss",
        $seminarId,
        $user["id"],
        $attendee["name"],
        $attendee["email"],
        $contactNumber
    );

    $insert->execute();
    $registrationId = $conn->insert_id;
    $insert->close();

    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "You have successfully registered for the seminar.",
        "registration_id" => $registrationId
    ]);

} catch (mysqli_sql_exception $e) {

    $conn->rollback();

    if ($e->getCode() === 1062) {
        http_response_code(409);
        echo json_encode([
            "success" => false,
            "message" => "You are already registered for this seminar."
        ]);
    } else {
        error_log("Seminar registration error: " . $e->getMessage());

        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Could not complete seminar registration."
        ]);
    }

} catch (Throwable $e) {

    $conn->rollback();

    error_log("Seminar registration error: " . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Could not complete seminar registration."
    ]);
}

$conn->close();

?>
