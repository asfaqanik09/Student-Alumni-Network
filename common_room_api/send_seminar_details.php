
<?php

header("Content-Type: application/json; charset=UTF-8");

use PHPMailer\PHPMailer\PHPMailer;

require_once __DIR__ . "/vendor/autoload.php";
require_once __DIR__ . "/auth.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Only POST requests are allowed."
    ]);
    exit;
}

try {
    // Authenticate admin.
    $user = authenticateUser($conn);
    requireRole($user, ["admin"]);

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

    if ($seminarId <= 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid seminar ID."
        ]);
        exit;
    }

    // Get approved seminar details.
    $stmt = $conn->prepare(
        "SELECT id, title, description, scheduled_at,
                duration_minutes, event_type, location, meeting_link
         FROM seminars
         WHERE id = ? AND status = 'approved'
         LIMIT 1"
    );

    $stmt->bind_param("i", $seminarId);
    $stmt->execute();

    $seminar = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$seminar) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Approved seminar not found."
        ]);
        exit;
    }

    // Validate final event details.
    if (
        $seminar["event_type"] === "online" &&
        empty($seminar["meeting_link"])
    ) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Please add a meeting link before sending emails."
        ]);
        exit;
    }

    if (
        $seminar["event_type"] === "physical" &&
        empty($seminar["location"])
    ) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Physical seminar location is missing."
        ]);
        exit;
    }

    // Retrieve registered participants.
    $stmt = $conn->prepare(
        "SELECT attendee_name, attendee_email
         FROM seminar_registrations
         WHERE seminar_id = ?
         ORDER BY registered_at ASC"
    );

    $stmt->bind_param("i", $seminarId);
    $stmt->execute();

    $result = $stmt->get_result();

    $participants = [];

    while ($row = $result->fetch_assoc()) {
        $participants[] = $row;
    }

    $stmt->close();

    if (count($participants) === 0) {
        echo json_encode([
            "success" => true,
            "message" => "There are no registered participants.",
            "total_participants" => 0,
            "emails_sent" => 0,
            "emails_failed" => 0
        ]);
        exit;
    }

    // Load existing SMTP configuration.
    $config = require __DIR__ . "/mail_config.php";

    $sent = 0;
    $failed = 0;

    // Prepare safe seminar information.
    $safeTitle = htmlspecialchars(
        $seminar["title"],
        ENT_QUOTES,
        "UTF-8"
    );

    $safeDescription = nl2br(htmlspecialchars(
        $seminar["description"],
        ENT_QUOTES,
        "UTF-8"
    ));

    $date = new DateTime($seminar["scheduled_at"]);

    $formattedDate = $date->format("F j, Y");
    $formattedTime = $date->format("g:i A");

    if ($seminar["event_type"] === "online") {
        $safeEventDetails = htmlspecialchars(
            $seminar["meeting_link"],
            ENT_QUOTES,
            "UTF-8"
        );

        $eventHeading = "Online Meeting Link";
    } else {
        $safeEventDetails = nl2br(htmlspecialchars(
            $seminar["location"],
            ENT_QUOTES,
            "UTF-8"
        ));

        $eventHeading = "Physical Event Location";
    }

    foreach ($participants as $participant) {
        try {
            $mail = new PHPMailer(true);

            $mail->isSMTP();
            $mail->Host = $config["smtp_host"];
            $mail->SMTPAuth = true;
            $mail->Username = $config["smtp_username"];
            $mail->Password = str_replace(
                " ",
                "",
                $config["smtp_password"]
            );

            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port = (int)$config["smtp_port"];

            $mail->setFrom(
                $config["from_email"],
                $config["from_name"]
            );

            $mail->addAddress(
                $participant["attendee_email"],
                $participant["attendee_name"]
            );

            $mail->isHTML(true);

            $mail->Subject = "Seminar Details: " . $seminar["title"];

            $safeName = htmlspecialchars(
                $participant["attendee_name"],
                ENT_QUOTES,
                "UTF-8"
            );

            $mail->Body = "
            <!DOCTYPE html>
            <html>
            <body style='font-family:Arial,sans-serif;background:#f4f6f8;padding:25px;'>
              <div style='max-width:600px;margin:auto;background:white;padding:30px;border-radius:12px;'>
                <h2 style='color:#172B3A;'>Common Room Seminar Update</h2>

                <p>Hello {$safeName},</p>

                <p>You are successfully registered for this seminar.</p>

                <h3>{$safeTitle}</h3>

                <p>{$safeDescription}</p>

                <p><strong>Date:</strong> {$formattedDate}</p>
                <p><strong>Time:</strong> {$formattedTime}</p>

                <p><strong>Duration:</strong>
                " . (int)$seminar["duration_minutes"] . " minutes</p>

                <h3>{$eventHeading}</h3>

                <p>{$safeEventDetails}</p>

                <p>Thank you for joining Common Room!</p>

                <p>Regards,<br>Common Room Team</p>
              </div>
            </body>
            </html>";

            $mail->AltBody =
                "Common Room Seminar Update\n\n" .
                "Hello " . $participant["attendee_name"] . ",\n\n" .
                "Seminar: " . $seminar["title"] . "\n" .
                "Date: " . $formattedDate . "\n" .
                "Time: " . $formattedTime . "\n" .
                "Duration: " . $seminar["duration_minutes"] . " minutes\n" .
                $eventHeading . ": " .
                strip_tags($safeEventDetails);

            $mail->send();

            $sent++;

        } catch (Throwable $mailError) {
            $failed++;

            error_log(
                "Seminar email failed for " .
                $participant["attendee_email"] . ": " .
                $mailError->getMessage()
            );
        }
    }

    echo json_encode([
        "success" => true,
        "message" => "Seminar email distribution completed.",
        "total_participants" => count($participants),
        "emails_sent" => $sent,
        "emails_failed" => $failed
    ]);

} catch (Throwable $e) {

    error_log("Seminar email distribution error: " . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Could not distribute seminar details."
    ]);
}

$conn->close();

?>
