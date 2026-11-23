
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

if (!is_array($data)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid JSON data."]);
    exit;
}

$name = trim($data["name"] ?? "");
$email = strtolower(trim($data["email"] ?? ""));
$password = $data["password"] ?? "";

if ($name === "" || !filter_var($email, FILTER_VALIDATE_EMAIL) || $password === "") {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Enter a valid name, email and password."]);
    exit;
}

if (strlen($password) < 8) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Password must contain at least 8 characters."]);
    exit;
}

$adminEmails = [
    "aniksorder96@gmail.com",
    "erinafrin10@gmail.com",
    "jubayerhossain.jhj@gmail.com"
];

$role = in_array($email, $adminEmails, true) ? "admin" : "pending";

try {
    $check = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $check->bind_param("s", $email);
    $check->execute();
    $check->store_result();

    if ($check->num_rows > 0) {
        $check->close();
        http_response_code(409);
        echo json_encode(["success" => false, "message" => "This email is already registered."]);
        exit;
    }
    $check->close();

    $userId = sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        random_int(0, 65535),
        random_int(0, 65535),
        random_int(0, 65535),
        random_int(0, 4095) | 0x4000,
        random_int(0, 16383) | 0x8000,
        random_int(0, 65535),
        random_int(0, 65535),
        random_int(0, 65535)
    );

    $passwordHash = password_hash($password, PASSWORD_DEFAULT);
    $verificationToken = bin2hex(random_bytes(32));
    $tokenHash = hash("sha256", $verificationToken);

    $verificationLink =
        "http://192.168.0.101/common_room_api/verify_email.php?token=" .
        urlencode($verificationToken);

    $config = require __DIR__ . "/mail_config.php";

    $conn->begin_transaction();

    // MySQL creates the expiry using its own clock.
    $stmt = $conn->prepare(
        "INSERT INTO users
        (id, email, password_hash, role, name,
         email_verified, verification_token, verification_expires)
         VALUES (?, ?, ?, ?, ?, 0, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))"
    );

    $stmt->bind_param(
        "ssssss",
        $userId,
        $email,
        $passwordHash,
        $role,
        $name,
        $tokenHash
    );

    $stmt->execute();
    $stmt->close();

    $mail = new PHPMailer(true);
    $mail->isSMTP();
    $mail->Host = $config["smtp_host"];
    $mail->SMTPAuth = true;
    $mail->Username = $config["smtp_username"];
    $mail->Password = str_replace(" ", "", $config["smtp_password"]);
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port = (int)$config["smtp_port"];

    $mail->setFrom($config["from_email"], $config["from_name"]);
    $mail->addAddress($email, $name);
    $mail->isHTML(true);
    $mail->Subject = "Verify your Common Room email";

    $safeName = htmlspecialchars($name, ENT_QUOTES, "UTF-8");
    $safeLink = htmlspecialchars($verificationLink, ENT_QUOTES, "UTF-8");

    $mail->Body = "
    <!DOCTYPE html>
    <html>
    <body style='font-family:Arial,sans-serif;background:#f4f6f8;padding:25px;'>
      <div style='max-width:550px;margin:auto;background:white;padding:30px;border-radius:12px;'>
        <h2 style='color:#172B3A;'>Welcome to Common Room!</h2>
        <p>Hello {$safeName},</p>
        <p>Please verify your email address by clicking below:</p>
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
        "Welcome to Common Room. Verify your email using this link:\n\n" .
        $verificationLink .
        "\n\nThis link expires in one hour.";

    $mail->send();
    $conn->commit();

    http_response_code(201);
    echo json_encode([
        "success" => true,
        "message" => "Account created. Please check your email to verify your account.",
        "user_id" => $userId,
        "email_verification_required" => true
    ]);

} catch (Throwable $e) {
    try {
        $conn->rollback();
    } catch (Throwable $ignored) {
    }

    error_log("Registration error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Registration or email delivery failed. Please try again."
    ]);
}

$conn->close();
?>
