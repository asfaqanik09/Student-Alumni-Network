
<?php
require_once "db_connect.php";

function showPage($title, $message, $success = false) {
    $color = $success ? "#16803c" : "#b42318";

    echo "<!DOCTYPE html>
    <html>
    <head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <title>Common Room - Email Verification</title>
    </head>
    <body style='font-family:Arial,sans-serif;background:#f4f6f3;
        display:flex;justify-content:center;align-items:center;
        min-height:100vh;margin:0;'>
        <div style='background:white;padding:35px;border-radius:14px;
            max-width:420px;text-align:center;box-shadow:0 4px 20px #ddd;'>
            <h2 style='color:#172b3a;'>Common Room</h2>
            <h3 style='color:$color;'>$title</h3>
            <p>" . htmlspecialchars($message) . "</p>
            <p>You can now return to the Common Room app.</p>
        </div>
    </body>
    </html>";
}

$token = trim($_GET["token"] ?? "");

if ($token === "" || !preg_match('/^[a-f0-9]{64}$/', $token)) {
    http_response_code(400);
    showPage("Invalid verification link", "This verification link is invalid.");
    exit;
}

try {
    $tokenHash = hash("sha256", $token);

    $stmt = $conn->prepare(
        "SELECT id FROM users
         WHERE verification_token = ?
         AND email_verified = 0
         AND verification_expires > NOW()
         LIMIT 1"
    );

    $stmt->bind_param("s", $tokenHash);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        $stmt->close();
        http_response_code(400);
        showPage(
            "Verification failed",
            "This link has expired or has already been used."
        );
        exit;
    }

    $user = $result->fetch_assoc();
    $stmt->close();

    $update = $conn->prepare(
        "UPDATE users
         SET email_verified = 1,
             verification_token = NULL,
             verification_expires = NULL
         WHERE id = ?"
    );

    $update->bind_param("s", $user["id"]);
    $update->execute();
    $update->close();

    showPage(
        "Email verified!",
        "Your email address has been successfully verified.",
        true
    );

} catch (Throwable $e) {
    http_response_code(500);
    showPage(
        "Something went wrong",
        "Please try again later."
    );
}

$conn->close();
?>
