<?php
    mb_internal_encoding('utf-8');

    $json = file_get_contents('php://input');
    $obj = json_decode($json, true);

    $handle = fopen("post.json", "w") or die("Unable to open file!");
    fwrite($handle, json_encode($obj));
    fclose($handle);

    if (!empty($obj) && isset($obj["holder"]) && isset($obj["map"]) && isset($obj["type"]) && isset($obj["time"]) && isset($obj["webhook"])) {
        include 'discord_hook_lib.php';

        $webhook = $obj["webhook"];
        // Escape Markdown characters in everything that could go in the message
        $runner = escape_chars("*_`~", "\\", $obj["holder"]);
        $runMap = escape_chars("*_`~", "\\", $obj["map"]);
        $runType = ucfirst(escape_chars("*_`~", "\\", $obj["type"]));
        $runTime = escape_chars("*_`~", "\\", $obj["time"]);
        $top = 5;

        $botName = "HL KreedZ";
        $avatarURL = "http://212.71.238.124/hlkz/hlkz.png";
        $msg = "[HLKZ] **$runner** has now the $runType WR for **$runMap**! Finished in **$runTime**\n\n";
        $title = "**Top $top $runType [$runMap]**\n";
        $desc = "```diff\n";
        $rec = $obj["records"];

        $maxLength = 10;
        // Get the length of the widest name to pad the other names with enough whitespaces
        for ($i = 0; $i < $top; $i++) {
            $nameLength = mb_strlen(rtrim($rec[$i]["name"]));
            if ($nameLength > $maxLength) {
                $maxLength = $nameLength;
            }
        }

        // Add the records of leaderboard to the description
        for ($j = 0; $j < $top; $j++) {
            if  ($j >= 3) $desc .= "--- ";
            else if ($j == 2) $desc .= "**- ";
            else if ($j == 1) $desc .= "--+ ";
            else if ($j == 0) $desc .= "++- ";
            $desc .= ($j+1) . " ";

            foreach ($rec[$j] as $key => $value) {
                if ($key == "name") {
                    $desc .= mb_str_pad(rtrim($value), $maxLength);
                } else if ($key != "date") {
                    $desc .= $value;
                }
                $desc .=  " ";
            }
            $desc .= "\n";
        }
        $desc .= " \n```";

        $msg .= $title . $desc;

        DiscordHook::send(new Message(new User($webhook, $botName, $avatarURL), $msg));
    }

    function mb_str_pad( $input, $pad_length, $pad_string = ' ', $pad_type = STR_PAD_RIGHT, $encoding="UTF-8") {
            $diff = strlen($input) - mb_strlen($input, $encoding);
            return str_pad($input, $pad_length + $diff, $pad_string, $pad_type);
    }

    function escape_chars($charsToEscape, $escapeSeq, $string)
    {
        $charsToEscape = preg_quote($charsToEscape, '/');
        $regexSafeEscapeSeq = preg_quote($escapeSeq, '/');
        $escapeSeq = preg_replace('/([$\\\\])/', '\\\$1', $escapeSeq);
        return(preg_replace('/(?<!'.$regexSafeEscapeSeq.')(['.$charsToEscape.'])/', $escapeSeq.'$1', $string));
    }
?>
