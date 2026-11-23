
<?php
header("Content-Type: application/json; charset=UTF-8");

use PHPMailer\PHPMailer\PHPMailer;

require_once __DIR__ . "/vendor/autoload.php";
require_once __DIR__ . "/db_connect.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Only POST requests are allowed."]);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);
$email = strtolower(trim($data["email"] ?? ""));

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Please enter a valid email address."]);
    exit;
}

try {
    $stmt = $conn->prepare(
        "SELECT id, name, email_verified FROM users WHERE email = ? LIMIT 1"
    );
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    if (!$user) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "No account was found with this email."]);
        exit;
    }

    if ((int)$user["email_verified"] === 1) {
        echo json_encode(["success" => true, "message" => "This email is already verified. You can log in."]);
        exit;
    }

    $verificationToken = bin2hex(random_bytes(32));
    $tokenHash = hash("sha256", $verificationToken);

    $verificationLink =
        "http://192.168.0.101/common_room_api/verify_email.php?token=" .
        urlencode($verificationToken);

    $config = require __DIR__ . "/mail_config.php";

    $conn->begin_transaction();

    // Store the token and create its expiry using MySQL's clock.
    $update = $conn->prepare(
        "UPDATE users
         SET verification_token = ?,
             verification_expires = DATE_ADD(NOW(), INTERVAL 1 HOUR)
         WHERE id = ? AND email_verified = 0"
    );

    $update->bind_param("ss", $tokenHash, $user["id"]);
    $update->execute();

    if ($update->affected_rows < 0) {
        throw new Exception("Could not update verification token.");
    }

    $update->close();

    $mail = new PHPMailer(true);
    $mail->isSMTP();
    $mail->Host = $config["smtp_host"];
    $mail->SMTPAuth = true;
    $mail->Username = $config["smtp_username"];
    $mail->Password = str_replace(" ", "", $config["smtp_password"]);
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port = (int)$config["smtp_port"];

    $mail->setFrom($config["from_email"], $config["from_name"]);
    $mail->addAddress($email, $user["name"]);
    $mail->isHTML(true);
    $mail->Subject = "Verify your Common Room email";

    $safeName = htmlspecialchars($user["name"], ENT_QUOTES, "UTF-8");
    $safeLink = htmlspecialchars($verificationLink, ENT_QUOTES, "UTF-8");

    $mail->Body = "
    <!DOCTYPE html>
    <html>
    <body style='font-family:Arial,sans-serif;background:#f4f6f8;padding:25px;'>
      <div style='max-width:550px;margin:auto;background:white;padding:30px;border-radius:12px;'>
        <h2 style='color:#172B3A;'>Verify your Common Room email</h2>
        <p>Hello {$safeName},</p>
        <p>Click the button below to verify your email address:</p>
        <p style='margin:30px 0;'>
          <a href='{$safeLink}'
             style='display:inline-block;background:#172B3A;color:white;padding:15px 25px;text-decoration:none;border-radius:8px;font-weight:bold;'>
             Verify My Email
          </a>
        </p>
        <p>If the button does not work, copy this link into your browser:</p>
        <p style='word-break:break-all;'>{$safeLink}</p>
        <p>This link expires in one hour and can only be used once.</p>
        <p>Regards,<br>Common Room Team</p>
      </div>
    </body>
    </html>";

    $mail->AltBody =
        "Hello " . $user["name"] .
        ", verify your Common Room email using this link:\n\n" .
        $verificationLink .
        "\n\nThis link expires in one hour.";

    $mail->send();
    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "A new verification email has been sent. Check your inbox and spam folder."
    ]);

} catch (Throwable $e) {
    try {
        $conn->rollback();
    } catch (Throwable $ignored) {
    }

    error_log("Resend verification error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Could not send the verification email. Please try again."
    ]);
}

$conn->close();
?>
